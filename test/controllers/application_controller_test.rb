# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'
require 'ipaddr'

# rubocop:disable Metrics/ClassLength
class ApplicationControllerTest < ActionDispatch::IntegrationTest
  # These are special tests for how the ApplicationController works,
  # in particular for handling IP addresses.

  test 'fail_if_invalid_client_ip works correctly' do
    a = ApplicationController.new
    client_ip = '43.249.72.2'
    range1 = IPAddr.new('23.235.32.0/20')
    range2 = IPAddr.new('43.249.72.0/22')

    assert_nothing_raised { a.send(:fail_if_invalid_client_ip, '', []) }
    assert_raises { a.send(:fail_if_invalid_client_ip, client_ip, []) }
    assert_nothing_raised do
      a.send(:fail_if_invalid_client_ip, client_ip, [range1, range2])
    end
    assert_raises do
      a.send(:fail_if_invalid_client_ip, client_ip, [range1, range1])
    end
  end

  test 'check if validate_client_ip_address runs when valid_client_ips' do
    Rails.configuration.valid_client_ips = [IPAddr.new('23.235.32.0/24')]
    a = ApplicationController.new
    a.request = ActionDispatch::Request.new({})
    a.request.env['REMOTE_ADDR'] = '1.2.3.4' # Not valid!
    assert_raises { a.send(:validate_client_ip_address) }

    a.request = ActionDispatch::Request.new({})
    a.request.env['REMOTE_ADDR'] = '23.235.32.1' # Valid!
    assert_nothing_raised { a.send(:validate_client_ip_address) }
    Rails.configuration.valid_client_ips = nil # Clean up.
  end

  test 'normalize_criteria_level handles all valid inputs' do
    a = ApplicationController.new
    # Numeric to named conversions
    assert_equal 'passing', a.normalize_criteria_level('0')
    assert_equal 'silver', a.normalize_criteria_level('1')
    assert_equal 'gold', a.normalize_criteria_level('2')
    # Synonym
    assert_equal 'passing', a.normalize_criteria_level('bronze')
    # Pass-through values
    assert_equal 'passing', a.normalize_criteria_level('passing')
    assert_equal 'permissions', a.normalize_criteria_level('permissions')
    assert_equal 'baseline-1', a.normalize_criteria_level('baseline-1')
    assert_equal 'baseline-2', a.normalize_criteria_level('baseline-2')
    assert_equal 'baseline-3', a.normalize_criteria_level('baseline-3')
  end

  test 'criteria_level_to_internal handles all valid inputs' do
    a = ApplicationController.new
    # Named to numeric conversions
    assert_equal '0', a.criteria_level_to_internal('passing')
    assert_equal '0', a.criteria_level_to_internal('bronze')
    assert_equal '1', a.criteria_level_to_internal('silver')
    assert_equal '2', a.criteria_level_to_internal('gold')
    # Pass-through values
    assert_equal '0', a.criteria_level_to_internal('0')
    assert_equal 'permissions', a.criteria_level_to_internal('permissions')
    assert_equal 'baseline-1', a.criteria_level_to_internal('baseline-1')
    assert_equal 'baseline-2', a.criteria_level_to_internal('baseline-2')
    assert_equal 'baseline-3', a.criteria_level_to_internal('baseline-3')
    # Default
    assert_equal '0', a.criteria_level_to_internal('unknown_level')
  end

  test 'default_url_options returns locale with empty options' do
    a = ApplicationController.new
    I18n.with_locale(:en) do
      result = a.send(:default_url_options, {})
      assert_equal({ locale: :en }, result)
    end
  end

  test 'default_url_options merges locale with additional options' do
    a = ApplicationController.new
    I18n.with_locale(:fr) do
      result = a.send(:default_url_options, { foo: 'bar', baz: 123 })
      assert_equal({ locale: :fr, foo: 'bar', baz: 123 }, result)
    end
  end

  test 'update_session_timestamp updates both session and cache when old' do
    controller = ApplicationController.new

    # Mock the session
    mock_session = {}
    controller.define_singleton_method(:session) { mock_session }

    # Setup: user logged in with old timestamp
    old_time = 2.hours.ago.utc
    controller.instance_variable_set(:@session_user_id, 123)
    controller.instance_variable_set(:@session_timestamp, old_time)

    # Call the method
    controller.send(:update_session_timestamp)

    # Verify both session[:time_last_used] and @session_timestamp were updated
    assert_not_nil mock_session[:time_last_used]
    assert mock_session[:time_last_used] > old_time
    new_timestamp = controller.instance_variable_get(:@session_timestamp)
    assert_equal mock_session[:time_last_used], new_timestamp
  end

  test 'update_session_timestamp skips update when timestamp is recent' do
    controller = ApplicationController.new

    # Mock the session
    mock_session = {}
    controller.define_singleton_method(:session) { mock_session }

    # Setup: user logged in with recent timestamp (30 minutes ago)
    recent_time = 30.minutes.ago.utc
    controller.instance_variable_set(:@session_user_id, 123)
    controller.instance_variable_set(:@session_timestamp, recent_time)

    # Call the method
    controller.send(:update_session_timestamp)

    # Verify session was NOT updated
    assert_nil mock_session[:time_last_used]
  end

  test 'update_session_timestamp skips when no user logged in' do
    controller = ApplicationController.new

    # Mock the session
    mock_session = {}
    controller.define_singleton_method(:session) { mock_session }

    # Setup: no user logged in
    controller.instance_variable_set(:@session_user_id, nil)

    # Call the method
    controller.send(:update_session_timestamp)

    # Verify session was NOT updated
    assert_nil mock_session[:time_last_used]
  end

  test 'verify_origin_shielding blocks untrusted proxies' do
    # Temporarily enable shielding
    old_enforce = ApplicationController::ENFORCE_ORIGIN_SHIELDING
    ApplicationController.send(:remove_const, :ENFORCE_ORIGIN_SHIELDING)
    ApplicationController.const_set(:ENFORCE_ORIGIN_SHIELDING, true)

    begin
      controller = ApplicationController.new
      mock_request = Minitest::Mock.new
      # Mock request.forwarded_for returning an untrusted IP
      mock_request.expect :forwarded_for, ['1.2.3.4']
      controller.instance_variable_set(:@_request, mock_request)

      # Mock render to verify it was called with 403
      controller.define_singleton_method(:render) do |options|
        @rendered_status = options[:status]
        @rendered_plain = options[:plain]
      end

      # Should be blocked
      controller.send(:verify_origin_shielding)
      assert_equal :forbidden, controller.instance_variable_get(:@rendered_status)
      assert_match(/Direct origin access not allowed/, controller.instance_variable_get(:@rendered_plain))

      # Now mock a trusted IP
      mock_request = Minitest::Mock.new
      edge_ip = '23.235.32.1'
      SecurityUtils.edge_proxies = [IPAddr.new('23.235.32.0/20')]
      mock_request.expect :forwarded_for, [edge_ip]
      controller.instance_variable_set(:@_request, mock_request)
      controller.instance_variable_set(:@rendered_status, nil)

      # Should NOT be blocked
      controller.send(:verify_origin_shielding)
      assert_nil controller.instance_variable_get(:@rendered_status)
    ensure
      # Restore original value
      ApplicationController.send(:remove_const, :ENFORCE_ORIGIN_SHIELDING)
      ApplicationController.const_set(:ENFORCE_ORIGIN_SHIELDING, old_enforce)
    end
  end
end
# rubocop:enable Metrics/ClassLength
