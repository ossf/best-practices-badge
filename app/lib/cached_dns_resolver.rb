# frozen_string_literal: true

# Copyright the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'resolv'
require 'ipaddr'

# CachedDnsResolver implements a DNS cache for ssrf_filter.
# It uses Rails.cache to store DNS lookups for 5 minutes.
module CachedDnsResolver
  module_function

  # Entry point for ssrf_filter.
  #
  # @param hostname [String] The hostname to resolve.
  # @return [Array<IPAddr>] An array of IPAddr objects.
  def call(hostname)
    # Fetch the IP strings from Rails cache (or run the block if missing/expired)
    # We cache for 5 minutes to balance performance and freshness.
    ip_strings =
      Rails.cache.fetch("dns:#{hostname}", expires_in: 5.minutes) do
        lookup(hostname)
      end

    # ssrf_filter strictly requires an array of IPAddr objects
    ip_strings.map { |ip| IPAddr.new(ip) }
  end

  # This method performs the actual DNS lookup. It is separated for testability.
  #
  # @param hostname [String] The hostname to resolve.
  # @return [Array<String>] An array of IP address strings.
  def lookup(hostname)
    Resolv.getaddresses(hostname)
  end
end
