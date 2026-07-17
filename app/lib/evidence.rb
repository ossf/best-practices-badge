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
    # @cached_data: per-URL fetch bundle { meta:, body_raw:, encoding: } (or nil
    # for a tried-and-failed fetch), keyed by URL. body_raw is the raw, possibly
    # still-compressed body, present only when a fetch was asked to store it
    # (get_headers store_body: true, or get_body); it is nil for a headers-only
    # fetch, so a headers-only consumer never buffers a body.
    # @decoded_bodies: memoized decoded body per URL, so get_body decompresses
    # at most once. A nil in either records a settled result we never retry.
    @cached_data = {}
    @decoded_bodies = {}
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

  # We accept gzip (and only gzip) but never let the HTTP stack *transparently*
  # inflate an attacker-supplied response. Accepting compression saves network
  # (smaller transfer, less egress from the sites we probe) and storage (a
  # stashed body is held in its compressed form); the anti-"decompression bomb"
  # safety comes from controlling decompression ourselves, not from refusing
  # compression.
  #
  # The mechanism: Net::HTTP only turns on transparent gzip inflation when *it*
  # auto-adds the Accept-Encoding header. By setting the header ourselves we
  # leave decode_content off, so no matter what the peer sends we receive the
  # bytes as-is (verified: any explicit Accept-Encoding keeps decode_content
  # false). Consequences, all bounded:
  #   - A peer that sends gzip gives us compressed bytes; MAXREAD bounds the
  #     *stored/transferred* bytes, and get_body inflates them only on demand
  #     through SafeInflate, which caps the *decompressed* output at MAXREAD so
  #     a bomb is refused, never expanded into memory.
  #   - A peer that can't compress sends identity; decode_body returns it raw.
  #
  # We advertise only gzip because SafeInflate handles only gzip framing, so
  # what we accept always matches what we can safely decode. The GitHub content
  # path (GithubContentAccess) still requests identity: Octokit parses the body
  # immediately, so there is nothing to defer and no place to insert a bounded
  # decode. Frozen so we allocate it once, not per request.
  REQUEST_HEADERS = {
    'User-Agent' => USER_AGENT,
    'Accept-Encoding' => 'gzip'
  }.freeze

  # Fetch `url` and return its response metadata (HTTP headers), cached.
  #
  # By default this reads only the response *headers* and does NOT pull the body
  # into memory, so a headers-only consumer (the common case, e.g.
  # HardenedSitesDetective) never buffers bytes it will not use.
  #
  # Pass store_body: true when you know you will also want the body, so this one
  # request stashes the raw body too and a following get_body needs no second
  # request. This flag is also how tests exercise the body/SafeInflate path.
  #
  # @param url [String] The URL to fetch data from.
  # @param store_body [Boolean] Also read and stash the raw body.
  # @return [Hash, nil] the frozen headers hash, or nil if the URL is invalid
  #   or the fetch failed.
  def get_headers(url, store_body: false)
    return if url.blank?

    bundle = fetch_bundle(url, store_body: store_body)
    bundle && bundle[:meta]
  end

  # Fetch `url` and return its (decoded) response body, cached.
  #
  # The body is decompressed only here, the moment a caller asks for it, and the
  # decoded result is memoized. We accept gzip (see REQUEST_HEADERS) but never
  # let the stack auto-inflate; if the peer sent gzip, the stored raw body is
  # inflated through SafeInflate (output-capped at MAXREAD) so a decompression
  # bomb cannot exhaust memory. If the body was not already stashed (no prior
  # store_body fetch), this performs its own store_body fetch, so callers can
  # use get_body on its own.
  #
  # NOTE: get_body has no production caller yet. It is implemented (and tested)
  # now on purpose. Reading evidence bodies from external sites is expected
  # near-term behavior, and the risky part is the untrusted-decompression path;
  # we want that safe path (SafeInflate, output caps, graceful failure) built
  # and proven before a feature depends on it, rather than bolted on under
  # pressure later. See the decompression policy test and SafeInflate.
  #
  # @param url [String] The URL to fetch data from.
  # @return [String, nil] the decoded body (binary), or nil if the URL is
  #   invalid, the fetch failed, or the body could not be decoded.
  def get_body(url)
    return if url.blank?
    return @decoded_bodies[url] if @decoded_bodies.key?(url)

    @decoded_bodies[url] = decode_fetched_body(url)
  end

  private

  # Fetch (if needed) and decode `url`'s body, returning nil when it is missing
  # or cannot be safely decoded. SafeInflate raises on an oversized ("bomb") or
  # malformed gzip stream; we treat that as an unusable body (nil) rather than
  # letting it escape, so a hostile response degrades gracefully.
  # @return [String, nil] the decoded body, or nil.
  def decode_fetched_body(url)
    bundle = fetch_bundle(url, store_body: true)
    raw = bundle && bundle[:body_raw]
    return unless raw

    decode_body(raw, bundle[:encoding])
  rescue SafeInflate::Error => e
    Rails.logger.warn "Undecodable evidence body for #{url}: #{e.class}"
    nil
  end

  # Fetch `url` and cache its bundle { meta:, body_raw:, encoding: }, reusing a
  # cached bundle when it already carries what we need. We fetch when the URL is
  # uncached, or when we now need the body (store_body) but the cached bundle
  # was fetched without one. A tried-and-failed fetch (cached nil) is never
  # retried, and a failed body upgrade never overwrites previously good headers.
  # @return [Hash, nil] the cached bundle, or nil.
  def fetch_bundle(url, store_body:)
    cached = @cached_data[url]
    if @cached_data.key?(url)
      return cached if cached.nil? # tried and failed: never retry
      return cached unless store_body && cached[:body_raw].nil? # have enough
    end
    fetched = guarded_fetch(url, store_body: store_body)
    # Cache a fresh success; also cache a first-time failure (cached is nil so
    # !cached is true). A failed body upgrade (cached headers exist) is NOT
    # cached, so the good headers survive.
    @cached_data[url] = fetched if fetched || !cached
    fetched || cached
  end

  # Fetch `url` over the network subject to our two entry guards (dubious-URL
  # rejection and the per-instance fetch budget), returning the fetch bundle or
  # nil. Both guards return nil. The URL is logged as-is; repo/homepage URLs are
  # validated upstream (UrlValidator forbids control characters).
  # @return [Hash, nil] the fetch bundle, or nil if refused or failed.
  def guarded_fetch(url, store_body:)
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
      # fetch_bundle, and dubious/over-budget URLs never reach here.
      @fetch_count += 1
      fetch_url_with_timeout(url, store_body: store_body)
    end
  end

  # Fetch data from the URL with a global timeout.
  #
  # @param url [String] The URL to fetch data from.
  # @param store_body [Boolean] Whether to also read and stash the raw body.
  # @return [Hash, nil] the fetch bundle, or nil on error.
  def fetch_url_with_timeout(url, store_body:)
    Timeout.timeout(MAX_TOTAL_TIME) do
      if @allow_private_ips
        get_insecure(url, store_body: store_body)
      else
        get_secure(url, store_body: store_body)
      end
    end
  rescue StandardError => e
    handle_fetch_error(url, e)
  end

  # Log a fetch error and return nil (fetch_bundle caches it).
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

  # Build the bundle { meta:, body_raw:, encoding: } from a successful response.
  # The raw body is pulled into memory only when store_body is true; body_raw
  # stays nil otherwise, so a headers-only fetch buffers nothing. The body is
  # kept raw (still compressed if the peer sent gzip) and decoded lazily by
  # get_body; encoding records how, captured from this same response.
  #
  # @param res [Net::HTTPResponse] The successful response object.
  # @param store_body [Boolean] Whether to read and stash the raw body.
  # @return [Hash] the frozen bundle.
  def build_result(res, store_body)
    {
      meta: extract_meta(res),
      body_raw: store_body ? read_raw_body(res).freeze : nil,
      encoding: res['content-encoding']
    }.freeze
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

  # Return the usable body from the raw (possibly compressed) bytes. A gzip
  # body is inflated through SafeInflate, which caps output at MAXREAD so a
  # compressed bomb cannot exhaust memory (a body that would decode past MAXREAD
  # is refused, surfacing as nil in get_body). A peer that could not compress
  # sent identity, so any other/absent Content-Encoding is returned raw.
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
  def get_secure(url, store_body:)
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
      result = build_result(res, store_body) if res.is_a?(Net::HTTPSuccess)
    end
    result
  rescue SsrfFilter::Error => e
    Rails.logger.warn "SSRF Filter error fetching URL #{url}: #{e.message}"
    nil
  end
  # rubocop:enable Metrics/MethodLength

  # Perform an insecure GET request (allows private IPs) using open-uri.
  # This is only used if ALLOW_PRIVATE_IPS is set (never on real production).
  # Unlike the secure path, this one requests identity: open-uri has its own
  # transparent-decompression behavior, and this dev/test-only path is not worth
  # the network saving, so we keep it simple and never receive gzip here.
  #
  # @param url [String] The URL to fetch data from.
  # @param store_body [Boolean] Whether to also read and stash the raw body.
  # @return [Hash, nil] the fetch bundle, or nil on error.
  # rubocop:disable Metrics/MethodLength
  def get_insecure(url, store_body:)
    require 'open-uri'
    result = nil
    URI.parse(url).open(
      'rb',
      'User-Agent' => USER_AGENT,
      'Accept-Encoding' => 'identity',
      open_timeout: 5,
      read_timeout: 5
    ) do |file|
      raw = store_body ? (file.read(MAXREAD) || +'').b : nil
      result = {
        meta: extract_open_uri_meta(file),
        body_raw: raw&.freeze,
        encoding: file.meta['content-encoding']
      }.freeze
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
