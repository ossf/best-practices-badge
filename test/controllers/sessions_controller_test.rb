# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# rubocop:disable Metrics/ClassLength
class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:test_user_melissa)
  end

  test 'should get new' do
    get '/en/sessions/new'
    assert_response :success

    # Do quick text search to see if email input field exists
    assert_match(
      /<input [^>]+ type="email" name="session\[email\]" id="session_email" /,
      @response.body
    )
    # Do a pickier check of the results using XPath selectors
    assert_select(
      'form/input[type="email"][name="session[email]"][id="session_email"]'
    )

    # Do quick text search for the password input field
    # We use parentheses here to make it clear "/" is a regex, not a division.
    assert_match(/<input [^>]+ type="password" /, @response.body)
    # Do a pickier check using XPath selectors
    assert_select(
      'form/input[type="password"]' \
      '[name="session[password]"][id="session_password"]'
    )

    # Ensure we have the link (button) for GitHub login.
    assert_select 'a[data-method="post"][href="/auth/github?locale=en"]'
  end

  test 'should redirect if already logged in' do
    log_in_as(@user, password: 'password1')
    get '/en/sessions/new'
    assert_response :redirect
    assert_redirected_to root_url
    follow_redirect!
    assert_response :success
    assert_not flash.empty?
  end

  test 'Simple login (directly)' do
    # This is a trivial test; if this fails, more complicated tests will too.
    # We include this trivial test so we can separately see if
    # just the basics work.
    post '/en/login', params: {
      session: {
        provider: 'local', email: 'test@example.org', password: 'password'
      }
    }
    assert_response :redirect
    assert_redirected_to root_url
    follow_redirect!
    assert flash && flash[:success]
    assert flash[:success].include?('Logged in!')
  end

  test 'local login with return_to redirects to destination' do
    destination = '/en/projects/1/passing/edit'
    post '/en/login', params: {
      session: {
        provider: 'local', email: 'test@example.org', password: 'password',
        return_to: destination
      }
    }
    assert_response :redirect
    assert_redirected_to destination
  end

  test 'local login with protocol-relative return_to is rejected' do
    post '/en/login', params: {
      session: {
        provider: 'local', email: 'test@example.org', password: 'password',
        return_to: '//evil.example.org/steal'
      }
    }
    assert_response :redirect
    assert_redirected_to root_url
  end

  test 'local login with non-path return_to is rejected' do
    post '/en/login', params: {
      session: {
        provider: 'local', email: 'test@example.org', password: 'password',
        return_to: 'javascript:alert(1)'
      }
    }
    assert_response :redirect
    assert_redirected_to root_url
  end

  test 'local login with return_to of /en/login is rejected (loop prevention)' do
    post '/en/login', params: {
      session: {
        provider: 'local', email: 'test@example.org', password: 'password',
        return_to: '/en/login'
      }
    }
    assert_response :redirect
    assert_redirected_to root_url
  end

  test 'local login with return_to of /en/login/ is rejected' do
    post '/en/login', params: {
      session: {
        provider: 'local', email: 'test@example.org', password: 'password',
        return_to: '/en/login/'
      }
    }
    assert_response :redirect
    assert_redirected_to root_url
  end

  test 'local login with return_to of /en/login?x is rejected' do
    post '/en/login', params: {
      session: {
        provider: 'local', email: 'test@example.org', password: 'password',
        return_to: '/en/login?x=1'
      }
    }
    assert_response :redirect
    assert_redirected_to root_url
  end

  test 'login page with return_to includes it in github auth link and form' do
    destination = '/en/projects/1/passing/edit'
    get '/en/login', params: { return_to: destination }
    assert_response :success
    encoded = ERB::Util.url_encode(destination)
    assert_select "a[data-method='post'][href='/auth/github?locale=en&return_to=#{encoded}']"
    assert_select "input[type='hidden'][name='session[return_to]'][value='#{destination}']"
  end

  test 'github auth request phase rejects missing csrf token' do
    # WARNING: This test manipulates global OmniAuth/Rails settings.
    # Parallel testing with *processes* is fine, parallel testing with
    # *threads* would need suite-wide locking for OmniAuth config changes.
    old_forgery_protection = ActionController::Base.allow_forgery_protection
    old_omniauth_test_mode = OmniAuth.config.test_mode
    old_omniauth_logger = OmniAuth.config.logger
    ActionController::Base.allow_forgery_protection = true
    OmniAuth.config.test_mode = false
    # Suppress OmniAuth logger because this test intentionally triggers
    # an authentication failure (missing CSRF token), and we want to
    # avoid noisy "ERROR" logs for a test that is expected to pass.
    OmniAuth.config.logger = Logger.new(File::NULL)

    https!
    post '/auth/github', headers: {
      'HTTP_ORIGIN' => 'https://www.example.com'
    }

    assert_response :redirect
    failure_uri = URI.parse(response.location)
    failure_params = Rack::Utils.parse_nested_query(failure_uri.query)
    assert_equal '/auth/failure', failure_uri.path
    assert_equal 'github', failure_params['strategy']
    assert_match(/csrf|InvalidAuthenticityToken/i,
                 failure_params['message'].to_s)
  ensure
    ActionController::Base.allow_forgery_protection = old_forgery_protection
    OmniAuth.config.test_mode = old_omniauth_test_mode
    OmniAuth.config.logger = old_omniauth_logger
  end

  # OmniAuth redirects failed logins (e.g. the CSRF rejection above) to
  # '/auth/failure'. Confirm that path no longer 404s but instead sends the
  # user back to login with a friendly message, and that it logs the failure.
  test 'auth failure redirects to login with a message and logs it' do
    old_logger = Rails.logger
    log_output = StringIO.new
    Rails.logger = Logger.new(log_output)

    get '/auth/failure',
        params: { message: 'invalid_authenticity_token', strategy: 'github' }

    assert_redirected_to login_path
    assert_equal I18n.t('sessions.login_failed'), flash[:danger]
    assert_match(/OmniAuth login failed/, log_output.string)
    assert_match(/invalid_authenticity_token/, log_output.string)
    assert_match(/github/, log_output.string)

    # The friendly login page actually renders (no 404).
    follow_redirect!
    assert_response :success
  ensure
    Rails.logger = old_logger
  end

  # A public endpoint must not let attacker-supplied params forge log lines;
  # embedded newlines must be escaped (via inspect), not written literally.
  test 'auth failure escapes newlines in logged params' do
    old_logger = Rails.logger
    log_output = StringIO.new
    Rails.logger = Logger.new(log_output)

    get '/auth/failure',
        params: { message: "evil\nFORGED LOG LINE", strategy: 'x' }

    assert_redirected_to login_path
    # The literal newline+text must not appear as its own log line.
    assert_no_match(/^FORGED LOG LINE/, log_output.string)
    assert_match(/evil\\nFORGED LOG LINE/, log_output.string)
  ensure
    Rails.logger = old_logger
  end

  test 'local login fails if deny_login' do
    # WARNING: This test manipulates a global setting, namely
    # Rails.application.config.deny_login. Parallel testing with *processes*
    # is fine, parallel testing with *threads* will not work.
    old_deny = Rails.application.config.deny_login
    Rails.application.config.deny_login = true # Not thread-safe
    begin
      post '/en/login', params: {
        session: {
          provider: 'local', email: 'test@example.org', password: 'password'
        }
      }
      assert flash && flash[:danger]
      assert flash[:danger].include?('logins temporarily disabled')
      assert '403', response.code
    ensure
      Rails.application.config.deny_login = old_deny
    end
  end

  # Security/robustness: a crafted login request can send the nested `session`
  # key as a scalar, or omit it entirely. Neither must raise an unhandled
  # exception (previously TypeError/NoMethodError -> 500) on this public,
  # unauthenticated endpoint; both should be treated as a failed login.
  test 'local login with scalar session param does not error' do
    post '/en/login', params: { session: 'foo' }
    assert_response :success # re-renders 'new'
    assert flash&.now && flash.now[:danger]
  end

  test 'local login with missing session param does not error' do
    post '/en/login'
    assert_response :success # re-renders 'new'
    assert flash&.now && flash.now[:danger]
  end
end
# rubocop:enable Metrics/ClassLength
