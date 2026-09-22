# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'
require 'ipaddr'

# rubocop:disable-next Metrics/ClassLength
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

  test 'update_session_timestamp updates both login_session and cache when old' do
    controller = ApplicationController.new
    login_session = LoginSession.create_for(
      users(:test_user), ip_address: '127.0.0.1', user_agent: 'test-agent'
    )

    # Setup: user logged in with old timestamp
    old_time = 2.hours.ago.utc
    login_session.update_column(:last_used_at, old_time)
    controller.instance_variable_set(:@login_session, login_session)
    controller.instance_variable_set(:@session_timestamp, old_time)

    # Call the method
    controller.send(:update_session_timestamp)

    # Verify both login_session.last_used_at and @session_timestamp were
    # updated
    assert login_session.reload.last_used_at > old_time
    new_timestamp = controller.instance_variable_get(:@session_timestamp)
    assert_equal login_session.last_used_at, new_timestamp
  end

  test 'update_session_timestamp skips update when timestamp is recent' do
    controller = ApplicationController.new
    login_session = LoginSession.create_for(
      users(:test_user), ip_address: '127.0.0.1', user_agent: 'test-agent'
    )

    # Setup: user logged in with recent timestamp (30 minutes ago)
    recent_time = 30.minutes.ago.utc
    login_session.update_column(:last_used_at, recent_time)
    controller.instance_variable_set(:@login_session, login_session)
    controller.instance_variable_set(:@session_timestamp, recent_time)

    # Call the method
    controller.send(:update_session_timestamp)

    # Verify login_session was NOT updated. assert_in_delta (not
    # assert_equal) because the DB column truncates sub-microsecond
    # precision, so a round-tripped Time is never bit-for-bit equal to
    # the in-memory Ruby Time even when nothing changed.
    assert_in_delta recent_time, login_session.reload.last_used_at, 1
  end

  test 'update_session_timestamp skips when no user logged in' do
    controller = ApplicationController.new

    # Setup: no user logged in
    controller.instance_variable_set(:@login_session, nil)

    # Call the method: must not raise even without a mocked session
    assert_nothing_raised { controller.send(:update_session_timestamp) }
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

  # try_remember_token_login runs whenever the Rails session cookie is
  # gone (e.g. a browser restart with a session-only cookie) but a
  # remember-me cookie is still valid. Deleting just the session cookie,
  # not the remember cookies, reproduces that: unlike log_in_as, no other
  # existing test drives this path over real HTTP.
  test 'try_remember_token_login re-establishes a session after the ' \
       'session cookie is lost' do
    log_in_as(users(:test_user_melissa), password: 'password1', remember_me: '1')
    cookies.delete('_BadgeApp_session')

    assert_difference('LoginSession.count', 1) do
      get root_path
    end
    assert user_logged_in?
  end

  # A session that dies for any reason (idle timeout here; setup_authentication_state
  # treats a revoked/purged session the same way) used to bounce the user
  # to a bare login page with no explanation and no way back to what they
  # were doing.
  test 'idle-expired session shows the auto_logged_out flash and a return_to' do
    user = users(:test_user_melissa)
    log_in_as(user, password: 'password1', remember_me: '0')
    login_session = user.login_sessions.last
    login_session.update_columns(last_used_at: SessionsHelper::SESSION_TTL.ago.utc - 1.minute)

    get edit_user_path(user)
    assert_redirected_to login_path(return_to: edit_user_path(user))
    follow_redirect!
    assert_includes @response.body,
                    'You were automatically logged out, please log in to continue.'
  end

  # Regression test for a real gap found while validating the pending-
  # resubmission fix on staging (2026-09-13): SessionsHelper#log_out calls
  # reset_session, which clears session[:_csrf_token], the secret behind
  # every CSRF token already embedded in any *other* tab's rendered forms.
  # Submitting one of those now-stale tabs used to hit Rails' generic 422
  # "The change you wanted was rejected" page instead of a friendly
  # explanation. See docs/login-session-simplify.md Part 1.
  #
  # allow_forgery_protection is off by default in the test env
  # (config/environments/test.rb), so this must opt back in via
  # with_forgery_protection to exercise the real check; a plain PATCH with
  # no authenticity_token at all raises the identical
  # ActionController::InvalidAuthenticityToken a genuinely stale token
  # would, which is all this handler cares about.
  #
  # destroy_all on the LoginSession, not log_out or a second log_in_as:
  # this needs to reproduce "genuinely logged out, but this tab's own
  # session cookie and CSRF secret are untouched," the same distinction
  # the staging investigation that found this bug had to work out (see
  # docs/login-session-simplify.md's background section). Actually logging
  # out in this same test session would reset_session, which would also
  # invalidate the very CSRF token this test needs to remain stale-but-
  # present for the PATCH below to reach the check at all in a realistic
  # way.
  test 'a failed CSRF check while genuinely logged out shows the auto_logged_out flash' do
    user = users(:test_user_melissa)
    log_in_as(user, password: 'password1', remember_me: '0')
    user.login_sessions.destroy_all

    with_forgery_protection do
      patch user_path(user), params: { user: { name: user.name } }
    end
    assert_redirected_to login_path(return_to: user_path(user))
    follow_redirect!
    assert_includes @response.body,
                    'You were automatically logged out, please log in to continue.'
  end

  # The other real case this handler must get right: a sibling tab's token
  # can also go stale because the user logged BACK IN elsewhere (that also
  # calls reset_session, via counter_fixation), leaving them still fully
  # logged in, just under a different LoginSession than this stale tab
  # remembers. Redirecting to the login page here would be actively wrong:
  # SessionsController#new redirects an already-logged-in visitor straight
  # back out with its own "already logged in" flash, so the user would see
  # two contradictory messages instead of one accurate one.
  test 'a failed CSRF check while still logged in redirects to root without claiming logout' do
    user = users(:test_user_melissa)
    log_in_as(user, password: 'password1', remember_me: '0')

    with_forgery_protection do
      patch user_path(user), params: { user: { name: user.name } }
    end
    assert_redirected_to root_url
    follow_redirect!
    # Not "didn't": t() output is HTML-escaped by ERB, so the rendered
    # apostrophe is "&#39;", not "'". Assert on a stretch without one.
    assert_includes @response.body, 'because your session changed'
    assert_not_includes @response.body, 'You were automatically logged out'
  end

  # docs/login-session-evaluation.md finding #3: a client that resends remember-me cookies on
  # every request while discarding Set-Cookie re-triggers a fresh
  # LoginSession INSERT each time; this bounds that per user_id, the same
  # protection successful_login gets (see
  # test/controllers/sessions_controller_test.rb), but reached here via a
  # passive relogin instead of a submitted login form.
  test 'try_remember_token_login is blocked once the per-user limit is hit' do
    user = users(:test_user_melissa)
    saved_limit = ENV.fetch('RATE_LOGINS_USER_LIMIT', nil)
    saved_env = Rails.env

    # Log in (and lose the session cookie) BEFORE flipping to
    # production/limit 0 below: otherwise the initial login itself,
    # which also goes through login_rate_limited?, would be blocked too.
    log_in_as(user, password: 'password1', remember_me: '1')
    cookies.delete('_BadgeApp_session')

    ENV['RATE_LOGINS_USER_LIMIT'] = '0'
    Rack::Attack.cache.reset_count("logins/user:#{user.id}", 60)
    Rails.env = 'production' # login_rate_limited? only enforces in production

    assert_no_difference('LoginSession.count') do
      get root_path
    end
    assert_not user_logged_in?
    assert_equal I18n.t('sessions.login_rate_limited'), flash[:warning]
  ensure
    ENV['RATE_LOGINS_USER_LIMIT'] = saved_limit
    Rails.env = saved_env
  end
end
