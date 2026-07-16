# frozen_string_literal: true

# Copyright the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'ssrf_filter'
require 'security_utils'
require 'timeout'

# This class collects and caches all evidence gathered so far on a project.
# This class is security-sensitive; here we gather evidence by doing a GET
# of untrusted data via URLs derived from data from untrusted users.
#
# This is one of the more unusual security aspects of this program.
# All web applications must protect themselves from untrusted data being
# *directly* sent to the program. However, to gather evidence, we must *also*
# go out and *retrieve* data, based on references (URLs) provided by
# untrusted users. Going out to *other* sites like this *is* unusual,
# but it's necessary for our functionality.
#
# As a result, this class must defend itself, e.g., from domain URLs that
# map to reserved IP addresses, slowloris attacks, no/slow response, and
# excessive data or header size. We cache data so we don't need to keep
# getting it.
#
# We use CachedDnsResolver to cache DNS queries. Our production
# system doesn't have a built-in DNS query cache, we have to control
# the resolver anyway for testing, and we already have a general cache, so
# it makes sense to cache them. This ensures that we don't go keep making
# DNS queries for *every* query to the same site, even if that external
# site's DNS timeout is absurdly short. We have to wait for each DNS query
# result before we can send the real request, so DNS resolver caching
# is important to reduce overall latency.
#
# rubocop:disable Metrics/ClassLength
class Evidence
  # Initialize an Evidence collector for a project.
  #
  # @param project [Project] The ActiveRecord project instance.
  # @param resolver [Proc, #resolve] Optional DNS resolver for ssrf_filter,
  #   primarily for testing.
  # @param allow_private_ips [Boolean] If true, allow fetching from private
  #   IP addresses (e.g., for internal use). Defaults to the value of the
  #   ALLOW_PRIVATE_IPS environment variable. Option for testing.
  def initialize(
    project,
    resolver: CachedDnsResolver,
    allow_private_ips: ENV['ALLOW_PRIVATE_IPS'] == 'true'
  )
    @project = project # ActiveRecord. Detectives should NOT change this.
    @cached_data = {}
    @resolver = resolver
    # Defense in depth: the insecure path (get_insecure uses open-uri with NO
    # SSRF filtering) is a test/development convenience only. Force it off on
    # the real production site even if ALLOW_PRIVATE_IPS is set, so production
    # can never be tricked into an unfiltered fetch by a misconfiguration.
    @allow_private_ips =
      allow_private_ips && ENV['BADGEAPP_REAL_PRODUCTION'] != 'true'
    # Number of distinct URLs actually fetched over the network by this
    # instance, bounded by MAX_FETCHES (see get).
    @fetch_count = 0
  end

  attr_reader :project

  # == Outbound fetch policy (all limits are explicit on purpose) ==
  # Every value below is a hard bound on what a single project analysis can do
  # to the outside world, so the whole policy can be read in one place. The
  # inputs are attacker-controlled (project repo_url / homepage_url), so we
  # keep these deliberately tight rather than trusting library defaults.

  # Don't download more than this number of bytes per file;
  # this helps counter easy DoS attacks.
  MAXREAD = 1 * (2**20)

  # Don't wait more than this many seconds for a response (connection + body).
  MAX_TOTAL_TIME = 10

  # Don't store more than this many bytes of HTTP headers.
  MAX_HEADER_SIZE = 64 * 1024

  # Follow at most this many redirects for a single fetch. ssrf_filter
  # re-validates the resolved IP at every hop, but each hop is still an
  # attacker-chosen outbound request, so we pin this explicitly rather than
  # trusting the library default. We keep generous headroom (legitimate chains
  # such as http->https, apex->www, and trailing-slash redirects are usually
  # short, but some real sites chain a few more) so tightening never causes a
  # mysterious fetch failure; the cap only stops an absurd redirect loop.
  MAX_REDIRECTS = 8

  # The only URL schemes we will ever request. Passed to ssrf_filter
  # explicitly so our policy does not silently change if a library default
  # changes underneath us.
  ALLOWED_SCHEMES = %w[http https].freeze

  # Hard cap on the number of distinct external URLs a single Evidence instance
  # (one project analysis) will fetch. This is deliberately far above what any
  # real analysis needs (today detectives fetch only the homepage and repo
  # URLs) so it never interferes with legitimate current or future data
  # gathering; its sole job is to stop an *absurd* storm, making it provably
  # impossible to turn one analysis into an unbounded outbound-request
  # amplifier no matter what any detective does. Combined with MAX_REDIRECTS
  # this bounds total outbound HTTP requests per analysis at
  # MAX_FETCHES * (MAX_REDIRECTS + 1).
  MAX_FETCHES = 100

  # Request identity (no compression) so we never decompress attacker-supplied
  # data. This is a deliberate anti-"zip bomb" measure: Net::HTTP only turns on
  # transparent gzip/deflate inflation when *it* auto-adds the Accept-Encoding
  # header, so by setting it ourselves we disable that inflation entirely.
  # Consequences, both good and easy to reason about:
  #   - A server that honours it sends uncompressed bytes, so MAXREAD bounds
  #     the actual content.
  #   - A server that ignores it and sends gzip anyway has its body stored
  #     as-is (still compressed) and never inflated, so a small response can
  #     never expand into gigabytes in memory. MAXREAD bounds the *stored*
  #     bytes in every case.
  # No detective reads the body (only headers), so declining decompression
  # costs us nothing. Frozen so we allocate it once, not per request.
  REQUEST_HEADERS = {
    'User-Agent' => USER_AGENT,
    'Accept-Encoding' => 'identity'
  }.freeze

  # Get contents of given URL and return it (cached).
  # Returns a hash with :meta (headers) and :body (content) if successful.
  #
  # @param url [String] The URL to fetch data from.
  # @return [Hash, nil] The fetched data or nil if the URL is invalid or the
  #   fetch fails.
  def get(url)
    return if url.blank?

    fetch_if_needed(url) unless @cached_data.key?(url)
    @cached_data[url]
  end

  private

  # Decide whether to fetch `url` over the network and do so, subject to our
  # two entry guards (dubious-URL rejection and the per-instance fetch budget).
  # Every path here records a result in @cached_data so `get` can return it.
  # @param url [String] The (uncached) URL to consider fetching.
  # @return [void]
  def fetch_if_needed(url)
    # Security: Ignore dubious URLs (SSRF protection & possible attack).
    # They *should* already have been rejected earlier during input
    # validation, but re-checking here is cheap and *ensures* we never fetch
    # something like `https://127.0.0.1` regardless of how we were called.
    if SecurityUtils.dubious_url?(url)
      reject_fetch(url, 'Ignoring dubious URL for evidence')
    elsif @fetch_count >= MAX_FETCHES
      # Provable amplification bound: refuse once this instance has already
      # fetched MAX_FETCHES distinct URLs.
      reject_fetch(url, "Evidence fetch budget (#{MAX_FETCHES}) exhausted")
    else
      # Count only real network attempts: cached URLs short-circuit in `get`,
      # and dubious/over-budget URLs never reach here.
      @fetch_count += 1
      fetch_url_with_timeout(url)
    end
  end

  # Record a refusal to fetch `url`: log why and cache nil so a repeat get of
  # the same URL is a no-op rather than a fresh refusal (and never a re-fetch).
  # The URL is logged as-is, like the rest of this class; repo/homepage URLs
  # are validated upstream (UrlValidator forbids control characters), so there
  # is nothing to escape for log safety.
  # @param url [String] The rejected URL.
  # @param reason [String] Human-readable reason for the refusal.
  # @return [void]
  def reject_fetch(url, reason)
    Rails.logger.warn "#{reason}: #{url}"
    @cached_data[url] = nil
  end

  # Fetch data from the URL with a global timeout.
  #
  # @param url [String] The URL to fetch data from.
  # @return [void]
  def fetch_url_with_timeout(url)
    Timeout.timeout(MAX_TOTAL_TIME) do
      if @allow_private_ips
        get_insecure(url)
      else
        get_secure(url)
      end
    end
  rescue StandardError => e
    handle_fetch_error(url, e)
  end

  # Log error and mark the URL as failed in the cache.
  #
  # @param url [String] The URL that failed.
  # @param error [StandardError] The error that occurred.
  # @return [void]
  def handle_fetch_error(url, error)
    msg =
      if error.is_a?(Timeout::Error)
        "Timeout (> #{MAX_TOTAL_TIME}s)"
      else
        "Error: #{error.message}"
      end
    Rails.logger.warn "#{msg} fetching URL #{url}"
    @cached_data[url] = nil
  end

  # Extract the body from the response, respecting MAXREAD.
  #
  # @param res [Net::HTTPResponse] The response object.
  # @return [String] The frozen body string.
  def extract_body(res)
    body = (+'').force_encoding('BINARY')
    res.read_body do |chunk|
      body << chunk
      break if body.bytesize >= MAXREAD
    end
    # Truncate if we went over in the last chunk
    body.byteslice(0, MAXREAD).freeze
  end

  # Extract and limit headers from the response to prevent resource exhaustion.
  #
  # @param res [Net::HTTPResponse] The response object.
  # @return [Hash<String, String>] The frozen metadata hash.
  def extract_meta(res)
    limit_headers(res.to_hash.transform_values { |v| v.join(', ') })
  end

  # Perform a secure GET request using ssrf_filter, to prevent
  # reserved (private) IP address use.
  #
  # @param url [String] The URL to fetch data from.
  # @return [void]
  # rubocop:disable Metrics/MethodLength
  def get_secure(url)
    # Use ssrf_filter to ensure GET requests are not performed if the
    # domain dynamically resolves (possibly via redirects) to a
    # reserved IP address (either IPv4 or IPv6) such as 127.0.0.1.
    options = {
      open_timeout: 5,
      read_timeout: 5,
      max_redirects: MAX_REDIRECTS,
      scheme_whitelist: ALLOWED_SCHEMES,
      headers: REQUEST_HEADERS
    }
    options[:resolver] = @resolver if @resolver
    SsrfFilter.get(url, options) do |res|
      # Only process successful responses
      @cached_data[url] =
        if res.is_a?(Net::HTTPSuccess)
          {
            meta: extract_meta(res), body: extract_body(res)
          }.freeze
        end
    end
  rescue SsrfFilter::Error => e
    Rails.logger.warn "SSRF Filter error fetching URL #{url}: #{e.message}"
    @cached_data[url] ||= nil
  end
  # rubocop:enable Metrics/MethodLength

  # Perform an insecure GET request (allows private IPs) using open-uri.
  # This is only used if ALLOW_PRIVATE_IPS is set (never on real production).
  # We still request identity encoding so open-uri does not transparently
  # decompress a response; see REQUEST_HEADERS for the anti-zip-bomb rationale.
  #
  # @param url [String] The URL to fetch data from.
  # @return [void]
  # rubocop:disable Metrics/MethodLength
  def get_insecure(url)
    require 'open-uri'
    URI.parse(url).open(
      'rb',
      'User-Agent' => USER_AGENT,
      'Accept-Encoding' => 'identity',
      open_timeout: 5,
      read_timeout: 5
    ) do |file|
      meta = extract_open_uri_meta(file)
      @cached_data[url] = {
        meta: meta, body: file.read(MAXREAD).freeze
      }.freeze
    end
  rescue StandardError => e
    Rails.logger.warn "Error fetching URL #{url} (insecure): #{e.message}"
    @cached_data[url] ||= nil
  end
  # rubocop:enable Metrics/MethodLength

  # Extract headers from open-uri file result.
  #
  # @param file [StringIO, Tempfile] The file object from open-uri.
  # @return [Hash<String, String>] The frozen metadata hash.
  def extract_open_uri_meta(file)
    limit_headers(file.meta)
  end

  # Limit headers by size and freeze them.
  #
  # This provides defense-in-depth against header-based DoS.
  # While Net::HTTP must parse headers into memory before we can limit them,
  # modern Ruby versions (3.2.1+) have internal limits of 1024 bytes for
  # individual header keys and values. Combined with our MAX_HEADER_SIZE
  # (which limits total saved memory) and our global MAX_TOTAL_TIME timeout
  # (which cuts off "infinite" header streams), this is sufficient to
  # prevent resource exhaustion.
  #
  # @param headers [Hash<String, String>] The raw headers.
  # @return [Hash<String, String>] The frozen metadata hash.
  def limit_headers(headers)
    current_size = 0
    headers.each_with_object({}) do |(k, v), hash|
      val = v.freeze
      item_size = k.bytesize + val.bytesize
      if current_size + item_size > MAX_HEADER_SIZE
        Rails.logger.warn 'Evidence: Headers > MAX_HEADER_SIZE; truncated.'
        break hash.freeze
      end
      hash[k] = val
      current_size += item_size
    end.freeze
  end
end
# rubocop:enable Metrics/ClassLength
