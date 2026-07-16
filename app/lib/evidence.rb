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
    # Two independent caches keyed by URL: response headers (get) and decoded
    # bodies (get_body). A body is fetched only when get_body is called, so a
    # headers-only consumer never buffers the body. A nil in either cache
    # records a tried-and-failed fetch, so we neither retry nor re-enter the
    # network, and a failed body fetch never invalidates good headers.
    @cached_data = {}
    @cached_bodies = {}
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

  # Request identity (no compression) so the HTTP stack never *transparently*
  # inflates an attacker-supplied response. This is the first layer of our
  # anti-"decompression bomb" defense and it is applied on every fetch path:
  # here, and on the GitHub content path (see GithubContentAccess), so the
  # whole system is uniform and easy to reason about.
  #
  # Net::HTTP only turns on transparent gzip/deflate inflation when *it*
  # auto-adds the Accept-Encoding header; by setting it ourselves we leave
  # decode_content off, so no inflation happens regardless of what the peer
  # sends. Both outcomes are bounded:
  #   - A peer that honours identity sends uncompressed bytes, so MAXREAD
  #     bounds the actual content directly.
  #   - A peer that ignores it and sends gzip anyway has its body stored as-is
  #     (still compressed) and never inflated, so a small response can never
  #     expand into gigabytes in memory. MAXREAD bounds the *stored* bytes in
  #     every case.
  #
  # get reads only headers; the body is pulled into memory solely by get_body,
  # the moment a caller needs it. If the peer ignored identity and sent gzip,
  # get_body inflates through SafeInflate (output-capped), so we never hand
  # attacker data to an auto-decoding HTTP client or an unbounded inflate.
  # Frozen so we allocate it once, not per request.
  REQUEST_HEADERS = {
    'User-Agent' => USER_AGENT,
    'Accept-Encoding' => 'identity'
  }.freeze

  # Fetch `url` and return its response metadata (HTTP headers), cached.
  #
  # This reads only the response *headers*. It deliberately does NOT pull the
  # body into memory; call get_body when the body is actually needed, so a
  # headers-only consumer (the common case, e.g. HardenedSitesDetective) never
  # buffers up to MAXREAD bytes it will not use.
  #
  # @param url [String] The URL to fetch data from.
  # @return [Hash, nil] { meta: {headers} }, or nil if the URL is invalid or
  #   the fetch failed.
  def get(url)
    return if url.blank?

    fetch_into(@cached_data, url, want_body: false)
  end

  # Fetch `url` and return its (decoded) response body, cached.
  #
  # The body is pulled from the network and decompressed only here, the moment
  # a caller asks for it. We request identity encoding, so the body is normally
  # plaintext; if the peer ignored that and sent gzip, it is inflated through
  # SafeInflate (output-capped at MAXREAD) so a decompression bomb cannot
  # exhaust memory. get and get_body fetch independently; no consumer needs
  # both today, so we do not complicate the caches to share one round trip.
  #
  # @param url [String] The URL to fetch data from.
  # @return [String, nil] the response body (binary), or nil if the URL is
  #   invalid or the fetch failed.
  def get_body(url)
    return if url.blank?

    fetch_into(@cached_bodies, url, want_body: true)
  end

  private

  # Return the cached value for `url` in `cache`, fetching it once if absent.
  # A failed fetch caches nil, so we neither retry nor re-enter the network for
  # a URL already tried. Header and body fetches use separate caches, so a
  # failed body fetch never invalidates good headers (or vice versa).
  # @return [Object, nil] the cached fetch result.
  def fetch_into(cache, url, want_body:)
    unless cache.key?(url)
      cache[url] = guarded_fetch(url, want_body: want_body)
    end
    cache[url]
  end

  # Fetch `url` over the network subject to our two entry guards (dubious-URL
  # rejection and the per-instance fetch budget), returning the fetch result
  # (a { meta: } hash, a body String, or nil). Both guards return nil, which
  # fetch_into caches. The URL is logged as-is; repo/homepage URLs are
  # validated upstream (UrlValidator forbids control characters).
  # @return [Object, nil] the fetch result, or nil if refused or failed.
  def guarded_fetch(url, want_body:)
    # Security: Ignore dubious URLs (SSRF protection & possible attack). They
    # *should* already have been rejected during input validation, but
    # re-checking here is cheap and *ensures* we never fetch something like
    # `https://127.0.0.1` regardless of how we were called.
    if SecurityUtils.dubious_url?(url)
      Rails.logger.warn "Ignoring dubious URL for evidence: #{url}"
      nil
    elsif @fetch_count >= MAX_FETCHES
      # Provable amplification bound: refuse once this instance has already
      # fetched MAX_FETCHES distinct URLs.
      Rails.logger.warn(
        "Evidence fetch budget (#{MAX_FETCHES}) exhausted: #{url}"
      )
      nil
    else
      # Count only real network attempts: cached URLs short-circuit in
      # fetch_into, and dubious/over-budget URLs never reach here.
      @fetch_count += 1
      fetch_url_with_timeout(url, want_body: want_body)
    end
  end

  # Fetch data from the URL with a global timeout.
  #
  # @param url [String] The URL to fetch data from.
  # @param want_body [Boolean] Whether to read/decode the body (get_body) or
  #   only the headers (get).
  # @return [Object, nil] the fetch result, or nil on error.
  def fetch_url_with_timeout(url, want_body:)
    Timeout.timeout(MAX_TOTAL_TIME) do
      if @allow_private_ips
        get_insecure(url, want_body: want_body)
      else
        get_secure(url, want_body: want_body)
      end
    end
  rescue StandardError => e
    handle_fetch_error(url, e)
  end

  # Log a fetch error and return nil (fetch_into caches it).
  #
  # @param url [String] The URL that failed.
  # @param error [StandardError] The error that occurred.
  # @return [nil]
  def handle_fetch_error(url, error)
    msg =
      if error.is_a?(Timeout::Error)
        "Timeout (> #{MAX_TOTAL_TIME}s)"
      else
        "Error: #{error.message}"
      end
    Rails.logger.warn "#{msg} fetching URL #{url}"
    nil
  end

  # Build the cached value from a successful response: headers only, or the
  # decoded body, per the caller's request. Only here, on a body request, do we
  # pull the body into memory (and decompress it if the peer compressed it).
  #
  # @param res [Net::HTTPResponse] The successful response object.
  # @param want_body [Boolean] Whether the caller asked for the body.
  # @return [Hash, String] a frozen { meta: } hash, or the frozen body.
  def build_result(res, want_body)
    return { meta: extract_meta(res) }.freeze unless want_body

    decode_body(read_raw_body(res), res['content-encoding'])
  end

  # Read the response body into memory, never exceeding MAXREAD bytes. This is
  # the point at which body bytes are pulled off the socket; a headers-only
  # get never reaches here.
  #
  # @param res [Net::HTTPResponse] The response object.
  # @return [String] The (binary) body, at most MAXREAD bytes. Not frozen;
  #   decode_body produces the frozen result.
  def read_raw_body(res)
    body = (+'').force_encoding('BINARY')
    res.read_body do |chunk|
      body << chunk
      break if body.bytesize >= MAXREAD
    end
    # Truncate if we went over in the last chunk
    body.byteslice(0, MAXREAD)
  end

  # Return the usable body. We requested identity, so the normal case is
  # plaintext and we just freeze it. A peer that ignored identity and sent
  # gzip is inflated through SafeInflate, which caps output at MAXREAD so a
  # compressed bomb cannot exhaust memory. Any other Content-Encoding is left
  # as raw bytes (we do not attempt to decode it).
  #
  # @param raw [String] The raw body bytes.
  # @param encoding [String, nil] The response Content-Encoding, if any.
  # @return [String] The frozen, usable body.
  def decode_body(raw, encoding)
    if %w[gzip x-gzip].include?(encoding.to_s.strip.downcase)
      SafeInflate.gunzip(raw, max_bytes: MAXREAD).freeze
    else
      raw.freeze
    end
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
  def get_secure(url, want_body:)
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
    result = nil
    SsrfFilter.get(url, options) do |res|
      # ssrf_filter yields every hop; only the final success carries evidence.
      result = build_result(res, want_body) if res.is_a?(Net::HTTPSuccess)
    end
    result
  rescue SsrfFilter::Error => e
    Rails.logger.warn "SSRF Filter error fetching URL #{url}: #{e.message}"
    nil
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
  def get_insecure(url, want_body:)
    require 'open-uri'
    result = nil
    URI.parse(url).open(
      'rb',
      'User-Agent' => USER_AGENT,
      'Accept-Encoding' => 'identity',
      open_timeout: 5,
      read_timeout: 5
    ) do |file|
      result =
        if want_body
          raw = file.read(MAXREAD) || (+'').force_encoding('BINARY')
          decode_body(raw, file.meta['content-encoding'])
        else
          { meta: extract_open_uri_meta(file) }.freeze
        end
    end
    result
  rescue StandardError => e
    Rails.logger.warn "Error fetching URL #{url} (insecure): #{e.message}"
    nil
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
