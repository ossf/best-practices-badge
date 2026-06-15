# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'ipaddr'
require 'uri'

# Security utility methods
module SecurityUtils
  # The trusted proxies' IP addresses are *not* being used for user
  # authentication; they're being used to counter CDN piercing and to
  # ensure that our rate limits apply to the correct IP addresses.

  class SecurityAssertionError < StandardError; end

  # This method is used to enforce security invariants at load time.
  # It is a "fail-fast" mechanism to prevent the application from
  # booting if a security check fails.
  # It has a special name to ensure it is *always* called in production
  # at startup.
  # By using a method for this, we can test the error-raising branch
  # in unit tests to satisfy 100% statement coverage requirements.
  def self.security_assertion(condition, message)
    raise SecurityAssertionError, "SECURITY CRITICAL: #{message}" unless condition
  end

  # Orchestrates loading of trusted proxies from dynamic and static sources.
  def self.load_trusted_proxies(url: nil, static: nil, fail_fast: false,
                                disabled: false)
    return [].freeze if disabled

    ips_dynamic = fetch_dynamic_proxies(url)
    ips_static = parse_static_proxies(static)

    warn_if_mismatched(ips_dynamic, ips_static, url)

    ips = ips_dynamic.empty? ? ips_static : ips_dynamic
    ensure_proxies_present(ips, fail_fast)

    ips.map { |ip| IPAddr.new(ip) }.freeze
  end

  # Attempts to fetch and parse JSON from a dynamic URL (e.g., Fastly API).
  # rubocop:disable Metrics/MethodLength
  def self.fetch_dynamic_proxies(url)
    return [] if url.blank?

    begin
      response = HTTParty.get(url, timeout: 5)
      return [] unless response.success?

      # Expected format: { 'addresses' => [...], 'ipv6_addresses' => [...] }
      json = response.parsed_response
      (json['addresses'] || []) + (json['ipv6_addresses'] || [])
    rescue StandardError => e
      Rails.logger.warn "Dynamic proxy load failed: #{e.message}. " \
                        'Falling back to static list.'
      []
    end
  end
  # rubocop:enable Metrics/MethodLength

  # Parses a comma-separated list of CIDR strings into an array.
  def self.parse_static_proxies(static)
    return [] if static.blank?

    static.split(',').map(&:strip)
  end

  # Logs a warning if dynamic and static data differ (ignores order).
  def self.warn_if_mismatched(dynamic, static, url)
    return unless dynamic.present? && static.present?
    return if dynamic.sort == static.sort

    Rails.logger.warn 'SECURITY WARNING: TRUSTED_PROXIES (static) is ' \
                      "OUT OF DATE. Dynamic data from #{url} differs " \
                      'from the static fallback.'
  end

  # Ensures at least one proxy is present if fail_fast is enabled.
  def self.ensure_proxies_present(ips, fail_fast)
    return unless ips.empty? && fail_fast

    security_assertion(false, 'No trusted proxies configured via URL ' \
                              'or static list.')
  end

  # Store the list of edge proxies for fast runtime shielding checks.
  @edge_proxies = [].freeze

  # Sets the edge proxies. This should be called once at startup.
  def self.edge_proxies=(ips)
    @edge_proxies = ips.freeze
  end

  # Checks if an IP address (String or IPAddr) is in the edge proxy list.
  # Optimized for runtime performance.
  def self.edge_proxy?(ip_val)
    return false if ip_val.blank?

    # Convert to IPAddr only once if it's a string
    ip = ip_val.is_a?(IPAddr) ? ip_val : IPAddr.new(ip_val)
    @edge_proxies.any? { |proxy| proxy.include?(ip) }
  rescue IPAddr::InvalidAddressError
    false
  end

  # Returns true if the URL is dubious (potentially dangerous or malformed).
  # This enforces a "Domain Only" policy for public project URLs:
  # 1. Rejects all IP addresses (IPv4, IPv6, hex, integer formats).
  # 2. Requires at least one dot in the hostname (rejects localhost, internal
  #    network hostnames, and malformed entries like 'containrrr').
  # 3. Only allows http and https protocols.
  # rubocop:disable Metrics/MethodLength
  def self.dubious_url?(url)
    # Empty/nil URLs are not "dubious" themselves; the caller should
    # decide if empty values are acceptable.
    return false if url.nil? || url.to_s.strip.empty?

    begin
      uri = URI.parse(url.to_s.strip)
      return true unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

      host = uri.host
      return true if host.nil? || host.strip.empty?

      # Requirement: At least one dot in hostname (blocks localhost, containrrr, etc.)
      return true if host.exclude?('.')

      # Requirement: No IP addresses (IPv4 or IPv6)
      # Normal public OSS projects use domain names.
      # This provides robust SSRF protection.
      begin
        IPAddr.new(host)
        return true # It's a valid IP address
      rescue IPAddr::InvalidAddressError
        # Check for numeric-only or hex-like hosts (e.g. 0x7f000001, 127.1, 2130706433)
        # These are often used for SSRF bypasses.
        return true if host.match?(/\A(0x[0-9a-f]+|[0-9.]+)\z/i)
      end
    rescue URI::InvalidURIError
      return true
    end
    false
  end
  # rubocop:enable Metrics/MethodLength
end
