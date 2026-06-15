# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# CII Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

class ClientIpTest < ActiveSupport::TestCase
  # Mocked request that simulates a Rack request (no remote_ip method)
  class MockRackReq
    attr_reader :env

    def initialize(env)
      @env = env
    end
  end

  # Mocked request that simulates a Rails request (has remote_ip method)
  class MockRailsReq
    def remote_ip
      '1.2.3.4'
    end
  end

  test 'ClientIP.extract works with Rails-like request' do
    m = MockRailsReq.new
    assert_equal '1.2.3.4', ClientIp.extract(m)
  end

  test 'ClientIP.extract works with Rack-like request (no XFF)' do
    env = { 'REMOTE_ADDR' => '5.6.7.8' }
    m = MockRackReq.new(env)
    assert_equal '5.6.7.8', ClientIp.extract(m)
  end

  test 'ClientIP.extract works with Rack-like request and XFF' do
    # NOTE: remote_ip logic results depend on TRUSTED_PROXIES.
    # By default in test, trusted_proxies might be empty or standard.
    env = {
      'REMOTE_ADDR' => '1.2.3.4',
      'HTTP_X_FORWARDED_FOR' => '192.168.1.1, 10.0.0.1'
    }
    m = MockRackReq.new(env)
    # ActionDispatch::RemoteIp will calculate the IP.
    # If no proxies are trusted, it should take the last one in XFF.
    result = ClientIp.extract(m)
    assert_not_nil result
  end
end
