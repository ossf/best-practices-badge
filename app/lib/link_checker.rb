# frozen_string_literal: true

# Copyright 2015-2026, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'ipaddr'
require 'net/http'
require 'timeout'
require 'uri'
require 'ssrf_filter'

# Check URLs in project fields and criteria justifications to determine if
# they are reachable, with retry support for transient failures.
# rubocop:disable-next Metrics/ClassLength
class LinkChecker
  # Match http:// or https:// URLs with at least 5 non-space characters
  # (consistent with Project#contains_url?). Closing parentheses are trimmed
  # in trim_url_delimiters so balanced parentheses inside URLs are preserved.
  URL_SCAN_REGEX = %r{https?://[^\s<>"']{5,}}

  # Trailing punctuation commonly adjacent to URLs in prose or markdown.
  TRAILING_PUNCTUATION = /[.,;:!?]+\z/

  # Prefix added when a criterion is marked Unmet due to a broken link.
  BROKEN_LINK_PREFIX_REGEX =
    %r{\A// Broken link: <(https?://[^>]+)>\.\s*}

  # Suffix appended during the grace period when a broken link is first seen.
  BROKEN_LINK_GRACE_REGEX =
    %r{\s*\(// Broken link <(https?://[^>]+)> detected on (\d{4}-\d{2}-\d{2})\)\z}

  # Characters not permitted in a valid URI string.
  INVALID_URI_CHARS = %r{[^-A-Za-z0-9_.~!*'\(\);:@&=+$,/?#\[\]%]}

  DEFAULT_REDIRECT_LIMIT = 10
  DEFAULT_RETRIES = 2
  DEFAULT_TIMEOUT = 10
  USER_AGENT = 'OpenSSF-Best-Practices-Badge-LinkChecker/1.0'

  PRIVATE_IP_RANGES = [
    IPAddr.new('0.0.0.0/8'),
    IPAddr.new('10.0.0.0/8'),
    IPAddr.new('100.64.0.0/10'),
    IPAddr.new('127.0.0.0/8'),
    IPAddr.new('169.254.0.0/16'),
    IPAddr.new('172.16.0.0/12'),
    IPAddr.new('192.168.0.0/16'),
    IPAddr.new('::1/128'),
    IPAddr.new('fc00::/7'),
    IPAddr.new('fe80::/10')
  ].freeze

  class << self
    # Extract all active HTTP/HTTPS URLs from justification text.
    # Returns [] if text is blank or starts with '// ' (a comment).
    def extract_urls(text)
      return [] if text.blank? || text.start_with?('// ')

      cleaned_text = text.sub(BROKEN_LINK_GRACE_REGEX, '')
      scan_urls(cleaned_text)
    end

    # Extract URLs even if the text starts with a '// Broken link:' prefix.
    def extract_urls_including_flagged(text)
      return [] if text.blank?

      unflagged = strip_broken_link_markers(text)
      return [] if unflagged.blank? || unflagged.start_with?('// ')

      scan_urls(unflagged)
    end

    # Remove any automated broken-link prefix or grace-period suffix.
    def strip_broken_link_markers(text)
      return '' if text.blank?

      text.sub(BROKEN_LINK_PREFIX_REGEX, '')
          .sub(BROKEN_LINK_GRACE_REGEX, '')
          .strip
    end

    # Return the Date when a broken link was first detected on this text,
    # or nil if no grace-period marker is present.
    def grace_detected_date(text)
      return if text.blank?

      match = BROKEN_LINK_GRACE_REGEX.match(text)
      return unless match

      Date.iso8601(match[2])
    rescue ArgumentError
      nil
    end

    # Return the URL stored in a failing '// Broken link:' prefix.
    def broken_prefix_url(text)
      match = BROKEN_LINK_PREFIX_REGEX.match(text.to_s)
      match && match[1]
    end

    # Return the URL stored in an active grace-period marker.
    def grace_warning_url(text)
      match = BROKEN_LINK_GRACE_REGEX.match(text.to_s)
      match && match[1]
    end

    # Format a justification with the grace-period warning suffix.
    def format_grace_warning(text, broken_url, date_str)
      base = strip_broken_link_markers(text)
      "#{base} (// Broken link <#{broken_url}> detected on #{date_str})".strip
    end

    # Format a justification with the failing '// Broken link:' prefix.
    def format_broken_prefix(text, broken_url)
      base = strip_broken_link_markers(text)
      if base.present?
        "// Broken link: <#{broken_url}>. #{base}"
      else
        "// Broken link: <#{broken_url}>."
      end
    end

    private

    def scan_urls(text)
      candidates = text.scan(URL_SCAN_REGEX).map { |u| trim_url_delimiters(u) }
      candidates.grep(%r{\Ahttps?://[^ ]{5}}).uniq
    end

    def trim_url_delimiters(url)
      cleaned = url.dup
      loop do
        if cleaned.match?(TRAILING_PUNCTUATION)
          cleaned.sub!(TRAILING_PUNCTUATION, '')
        elsif (cleaned.end_with?(')') && cleaned.count(')') > cleaned.count('(')) ||
              (cleaned.end_with?(']') && cleaned.count(']') > cleaned.count('['))
          cleaned.chop!
        else
          break
        end
      end
      cleaned
    end
  end

  # rubocop:disable-next Metrics/ParameterLists
  def initialize(
    retries: DEFAULT_RETRIES,
    timeout: DEFAULT_TIMEOUT,
    redirect_limit: DEFAULT_REDIRECT_LIMIT,
    max_total_duration: nil,
    cache: {},
    resolver: CachedDnsResolver
  )
    @retries = retries
    @timeout = timeout
    @redirect_limit = redirect_limit
    @max_total_duration = max_total_duration
    @deadline = nil
    @cache = cache
    @resolver = resolver
  end

  attr_reader :cache

  # Return :ok, :broken, or :skipped depending on the check result.
  def url_status(url)
    return :broken if url.blank?
    return @cache[url] if @cache.key?(url)

    @cache[url] = check_with_retries(url)
  end

  # Return true only if the URL was verified as reachable.
  def url_ok?(url)
    url_status(url) == :ok
  end

  private

  # rubocop:disable-next Metrics/MethodLength
  def check_with_retries(url)
    return :broken unless valid_http_url?(url)

    attempts = 0
    while attempts <= @retries
      status = perform_request(url, @redirect_limit)
      return :ok if status == :ok
      return :skipped if status == :skipped
      return :broken if status == :permanent_failure

      attempts += 1
    end
    :broken
  end

  def valid_http_url?(url)
    return false unless url.start_with?('https://', 'http://')
    return false if INVALID_URI_CHARS.match?(url)

    uri = URI.parse(url)
    return false unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    return false if uri.host.blank? || uri.user.present? || uri.password.present?

    !private_or_local_host?(uri.host)
  rescue URI::InvalidURIError
    false
  end

  def private_or_local_host?(host)
    normalized = host.downcase(:ascii).delete_prefix('[').delete_suffix(']')
    return true if normalized == 'localhost' || normalized.end_with?('.localhost', '.local')

    ip = IPAddr.new(normalized)
    PRIVATE_IP_RANGES.any? { |range| range.include?(ip) }
  rescue IPAddr::InvalidAddressError
    false
  end

  # rubocop:disable-next Metrics/MethodLength, Metrics/AbcSize
  def perform_request(url, limit)
    return :skipped if deadline_exceeded?
    return :permanent_failure if limit <= 0

    uri = URI.parse(url)
    return :permanent_failure unless valid_http_url?(url)

    response = http_get(uri)
    classify_response(uri, response, limit)
  rescue SsrfFilter::Error
    :permanent_failure
  rescue *webmock_blocked_request_errors
    :skipped
  rescue StandardError => e
    return :skipped if test_harness_blocked?(e) || deadline_exceeded?

    :transient_failure
  end

  def http_get(uri)
    req_timeout = request_timeout_budget
    # Pin a public DNS result for each hop; checking the hostname alone
    # permits DNS rebinding and redirects into internal services.
    Timeout.timeout(req_timeout) do
      SsrfFilter.get(
        uri.to_s,
        resolver: @resolver,
        scheme_whitelist: %w[http https],
        max_redirects: 0,
        allow_unfollowed_redirects: true,
        http_options: { open_timeout: req_timeout, read_timeout: req_timeout },
        headers: { 'User-Agent' => USER_AGENT }
      ) { |response| response }
    end
  end

  def deadline_exceeded?
    return false unless @max_total_duration

    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    @deadline ||= now + @max_total_duration
    now >= @deadline
  end

  def request_timeout_budget
    return @timeout unless @max_total_duration

    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    @deadline ||= now + @max_total_duration
    [@timeout.to_f, @deadline - now].min.clamp(0.001, @timeout.to_f)
  end

  def classify_response(uri, response, limit)
    case response
    when Net::HTTPSuccess
      :ok
    when Net::HTTPRedirection
      follow_redirect(uri, response['location'], limit)
    when Net::HTTPTooManyRequests, Net::HTTPServerError
      :transient_failure
    else
      :permanent_failure
    end
  end

  def follow_redirect(base_uri, location, limit)
    return :permanent_failure if location.blank?

    target_url = URI.join(base_uri.to_s, location).to_s
    perform_request(target_url, limit - 1)
  rescue URI::InvalidURIError
    :permanent_failure
  end

  # When running in the test suite with WebMock/VCR, unstubbed URLs in
  # unrelated tests raise NetConnectNotAllowedError or UnhandledHTTPRequestError.
  # Treat those as skipped so unrelated controller/detective tests are unaffected.
  def test_harness_blocked?(exception)
    name = exception.class.name
    name.include?('NetConnectNotAllowedError') ||
      name.include?('UnhandledHTTPRequestError')
  end

  def webmock_blocked_request_errors
    return [] unless defined?(WebMock::NetConnectNotAllowedError)

    [WebMock::NetConnectNotAllowedError]
  end
end
