# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'
require 'security_utils'

class SecurityUtilsTest < ActiveSupport::TestCase
  test 'dubious_url? allows valid FQDNs' do
    assert_not SecurityUtils.dubious_url?('https://github.com/linuxfoundation/cii-best-practices-badge')
    assert_not SecurityUtils.dubious_url?('http://kernel.org')
    assert_not SecurityUtils.dubious_url?('https://www.google.com')
  end

  test 'dubious_url? rejects all IP addresses' do
    assert SecurityUtils.dubious_url?('http://127.0.0.1')
    assert SecurityUtils.dubious_url?('http://10.0.0.1')
    assert SecurityUtils.dubious_url?('http://192.168.1.1')
    assert SecurityUtils.dubious_url?('http://8.8.8.8')
    assert SecurityUtils.dubious_url?('http://3.6.47.234')
    assert SecurityUtils.dubious_url?('http://[::1]')
    assert SecurityUtils.dubious_url?('http://[2001:db8::1]')
  end

  test 'dubious_url? rejects shorthand and bypass formats' do
    assert SecurityUtils.dubious_url?('http://127.1')
    assert SecurityUtils.dubious_url?('http://0x7f000001')
    assert SecurityUtils.dubious_url?('http://2130706433')
  end

  test 'dubious_url? rejects hostnames without dots' do
    assert SecurityUtils.dubious_url?('http://localhost')
    assert SecurityUtils.dubious_url?('http://database')
    assert SecurityUtils.dubious_url?('https://containrrr/watchtower')
  end

  test 'dubious_url? rejects non-http/https protocols' do
    assert SecurityUtils.dubious_url?('ftp://example.org')
    assert SecurityUtils.dubious_url?('mailto:user@example.org')
    assert SecurityUtils.dubious_url?('javascript:alert(1)')
  end

  test 'dubious_url? returns false for nil or empty' do
    assert_not SecurityUtils.dubious_url?(nil)
    assert_not SecurityUtils.dubious_url?('')
    assert_not SecurityUtils.dubious_url?('   ')
  end

  test 'dubious_url? handles invalid URIs gracefully' do
    assert SecurityUtils.dubious_url?('http://[::1') # Invalid bracket
    assert SecurityUtils.dubious_url?('http:// ') # Blank host
  end
end
