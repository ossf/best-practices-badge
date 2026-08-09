# frozen_string_literal: true

# Copyright the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'
require 'minitest/mock'

class CachedDnsResolverTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
  end

  test 'call returns array of IPAddr objects' do
    hostname = 'example.com'
    ips = ['1.2.3.4', '2001:db8::1']

    # Use a real IPs to ensure IPAddr.new doesn't fail
    CachedDnsResolver.stub :lookup, ips do
      result = CachedDnsResolver.call(hostname)

      assert_instance_of Array, result
      assert_equal 2, result.size
      assert_instance_of IPAddr, result.first
      assert_instance_of IPAddr, result[1]
      assert_equal IPAddr.new('1.2.3.4'), result.first
      assert_equal IPAddr.new('2001:db8::1'), result[1]
    end
  end

  test 'call caches DNS results' do
    hostname = 'cache.example.com'
    ips = ['9.8.7.6']

    # First call - should trigger lookup
    CachedDnsResolver.stub :lookup, ips do
      result = CachedDnsResolver.call(hostname)
      assert_equal [IPAddr.new('9.8.7.6')], result
    end

    # Second call - should NOT trigger lookup (cached)
    # We stub it to raise an error if called, to prove it's cached
    CachedDnsResolver.stub :lookup, ->(_h) { flunk 'Lookup was called on cache hit' } do
      result = CachedDnsResolver.call(hostname)
      assert_equal [IPAddr.new('9.8.7.6')], result
    end
  end

  test 'lookup calls Resolv.getaddresses' do
    hostname = 'resolv.example.com'
    ips = ['192.0.2.1']

    # This tests the lookup method itself for coverage
    Resolv.stub :getaddresses, ips do
      assert_equal ips, CachedDnsResolver.lookup(hostname)
    end
  end
end
