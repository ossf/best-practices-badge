# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# rubocop:disable-next Metrics/ClassLength
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

  test 'local login with pending_resubmission_token sets session for resume' do
    # docs/login-session-18.md "Step 21": pending_resubmission_token rides
    # this login's own request params, not session, so this checks
    # successful_login actually writes it to session once this specific
    # login succeeds. Value doesn't need to be a real PendingResubmission
    # row for this: that check happens later, in
    # ApplicationController#overlay_pending_resubmission!, when the edit
    # page it belongs to is actually visited. This login carries no
    # return_to of its own, so it falls through to the ordinary
    # redirect_back_or root_url fallback (docs/login-session-simplify.md
    # Part 2 step 3 removed the special-cased redirect this used to need).
    token = 'a-test-token-value'
    post '/en/login', params: {
      session: {
        provider: 'local', email: 'test@example.org', password: 'password',
        pending_resubmission_token: token
      }
    }
    assert_response :redirect
    assert_redirected_to root_url
    assert_equal token, session[:pending_resubmission_token]
  end

  test 'local login without pending_resubmission_token does not set one' do
    post '/en/login', params: {
      session: {
        provider: 'local', email: 'test@example.org', password: 'password'
      }
    }
    assert_response :redirect
    assert_nil session[:pending_resubmission_token]
  end

  test 'login page with return_to includes it in github auth link and form' do
    destination = '/en/projects/1/passing/edit'
    get '/en/login', params: { return_to: destination }
    assert_response :success
    encoded = ERB::Util.url_encode(destination)
    assert_select "a[data-method='post'][href='/auth/github?locale=en&return_to=#{encoded}']"
    assert_select "input[type='hidden'][name='session[return_to]'][value='#{destination}']"
  end

  test 'login page with pending_resubmission_token includes it in github auth link and form' do
    # docs/login-session-18.md "Step 21": the token rides this request's own
    # params, mirroring return_to above, not session, so a login page load
    # that never carried it must never echo one back either.
    token = 'a-test-token-value'
    get '/en/login', params: { pending_resubmission_token: token }
    assert_response :success
    assert_select "a[data-method='post'][href='/auth/github?locale=en&pending_resubmission_token=#{token}']"
    assert_select "input[type='hidden'][name='session[pending_resubmission_token]'][value='#{token}']"
  end

  test 'login page without pending_resubmission_token omits it from github auth link and form' do
    get '/en/login'
    assert_response :success
    assert_select "a[href*='pending_resubmission_token']", count: 0
    assert_select "input[name='session[pending_resubmission_token]']", count: 0
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

  test 'login creates exactly one LoginSession row with ip_address and user_agent' do
    assert_difference('LoginSession.count', 1) do
      post '/en/login', params: {
        session: {
          provider: 'local', email: @user.email, password: 'password1'
        }
      }, headers: { 'User-Agent' => 'BadgeAppTestAgent/1.0' }
    end
    login_session = LoginSession.last
    assert_equal @user.id, login_session.user_id
    assert_not_nil login_session.ip_address
    assert_equal 'BadgeAppTestAgent/1.0', login_session.user_agent
  end

  # docs/login-session-evaluation.md finding #3: bound login attempts per user_id, not just
  # per IP (config/initializers/rack_attack.rb's throttles), since a
  # distributed attacker spread across many IPs but targeting one account
  # sails right past IP-based limits. The check itself
  # (SessionsHelper#login_rate_limited?) is unit-tested directly in
  # test/helpers/sessions_helper_test.rb; this confirms the controller
  # actually wires it in and responds correctly when tripped.
  test 'successful_login blocks further logins once the per-user limit is hit' do
    saved_limit = ENV.fetch('RATE_LOGINS_USER_LIMIT', nil)
    saved_env = Rails.env
    ENV['RATE_LOGINS_USER_LIMIT'] = '1'
    Rack::Attack.cache.reset_count("logins/user:#{@user.id}", 60)
    login_params = {
      session: { provider: 'local', email: @user.email, password: 'password1' }
    }
    Rails.env = 'production' # login_rate_limited? only enforces in production

    post '/en/login', params: login_params
    assert_response :redirect
    assert user_logged_in?

    assert_no_difference('LoginSession.count') do
      post '/en/login', params: login_params
    end
    assert_response :too_many_requests
    assert_equal I18n.t('sessions.login_rate_limited'), flash.now[:danger]
  ensure
    ENV['RATE_LOGINS_USER_LIMIT'] = saved_limit
    Rails.env = saved_env
  end

  test 'logout deletes only the current LoginSession row' do
    # Log in once, simulating a first browser/session for this user.
    log_in_as(@user, password: 'password1')
    first_login_session_id = session[:login_session_id]
    assert LoginSession.exists?(
      session_id_digest: LoginSession.digest(first_login_session_id)
    )

    # Log in again as the same user, simulating a second, independent
    # session (e.g. another browser); this creates a second LoginSession
    # row without touching the first one.
    log_in_as(@user, password: 'password1')
    second_login_session_id = session[:login_session_id]
    assert_not_equal first_login_session_id, second_login_session_id
    assert_equal 2, @user.login_sessions.count

    # Logging out (of the second session, the one this cookie jar now
    # holds) must delete only that row, leaving the first session's row
    # untouched -- this is design doc section 3's "ordinary logout only
    # revokes the current session" property.
    assert_difference('LoginSession.count', -1) do
      delete logout_path, params: { locale: 'en' }
    end
    assert_not LoginSession.exists?(
      session_id_digest: LoginSession.digest(second_login_session_id)
    )
    assert LoginSession.exists?(
      session_id_digest: LoginSession.digest(first_login_session_id)
    )
  end

  test 'logout does not crash when the session is older than RESET_SESSION_TIMER' do
    # Regression test: log_out used to destroy @login_session without
    # clearing the ivar, so the after_action update_session_timestamp
    # (which only bumps last_used_at when it is already stale) called
    # update_column on the now-destroyed record and raised
    # ActiveRecord::ActiveRecordError. Backdating last_used_at reproduces
    # the "idle for over an hour, then log out" state that ordinary
    # same-test login/logout timing never exercises.
    log_in_as(@user, password: 'password1')
    login_session = LoginSession.find_by_session_id(session[:login_session_id])
    login_session.update_column(
      :last_used_at, (SessionsHelper::RESET_SESSION_TIMER + 1.minute).ago.utc
    )

    assert_nothing_raised do
      delete logout_path, params: { locale: 'en' }
    end
    assert_response :redirect
    assert_not LoginSession.exists?(login_session.id)
  end

  # docs/login-session-18.md step 19: SessionsController#update_github_nickname
  # keeps User#nickname in sync with GitHub, since
  # SessionsHelper#current_user_is_github_owner? now authorizes off that DB
  # column rather than a forgeable session value.
  #
  # Both github-provider fixtures (github_user and blocked_github_user)
  # leave :uid unset, i.e. NULL for both. That's fine for tests that
  # don't care which one omniauth_login's User.find_by(provider:, uid:)
  # resolves to, but these tests specifically need it to land on
  # github_user, so give it a real, unique uid first rather than relying
  # on nil to disambiguate two rows that share it.
  test 'omniauth login with pending_resubmission_token sets session for resume' do
    # docs/login-session-18.md "Step 21": go through the real request
    # phase (with the token as a query param, matching how the login
    # page's own GitHub link builds it), rather than jumping straight to
    # the callback, so OmniAuth's real session['omniauth.params'] round
    # trip is what actually carries it across the redirect to GitHub and
    # back, not something this test fakes directly.
    github_user = users(:github_user)
    github_user.update!(uid: 'github-test-uid')
    token = 'a-test-token-value'
    OmniAuth.config.test_mode = true
    OmniAuth.config.add_mock(:github, github_omniauth_hash(github_user))
    # POST, not GET (OmniAuth 2.x's default allowed_request_methods is
    # [:post] only; a GET here 404s), and the token rides the URL's own
    # query string, not params:, which Rails would put in the request
    # body instead; OmniAuth reads request.GET (query string only).
    post "/auth/github?pending_resubmission_token=#{token}"
    assert_response :redirect
    follow_redirect!
    assert_redirected_to root_url
    assert_equal token, session[:pending_resubmission_token]
  ensure
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:github] = nil
  end

  test 'omniauth login without pending_resubmission_token does not set one' do
    github_user = users(:github_user)
    github_user.update!(uid: 'github-test-uid')
    OmniAuth.config.test_mode = true
    OmniAuth.config.add_mock(:github, github_omniauth_hash(github_user))
    post '/auth/github'
    assert_response :redirect
    follow_redirect!
    assert_nil session[:pending_resubmission_token]
  ensure
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:github] = nil
  end

  test 'omniauth login with an unchanged github nickname sets no flash' do
    github_user = users(:github_user)
    github_user.update!(uid: 'github-test-uid')
    OmniAuth.config.test_mode = true
    OmniAuth.config.add_mock(:github, github_omniauth_hash(github_user))
    get '/auth/github/callback'
    assert_nil flash[:info]
    assert_equal github_user.nickname, github_user.reload.nickname
  ensure
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:github] = nil
  end

  test 'omniauth login with a changed github nickname updates it and flashes' do
    github_user = users(:github_user)
    github_user.update!(uid: 'github-test-uid')
    old_nickname = github_user.nickname
    new_nickname = "#{old_nickname}-renamed"
    OmniAuth.config.test_mode = true
    OmniAuth.config.add_mock(
      :github, github_omniauth_hash(github_user, nickname: new_nickname)
    )
    get '/auth/github/callback'
    assert_equal new_nickname, github_user.reload.nickname
    assert_equal(
      "Your GitHub username changed from #{old_nickname} to #{new_nickname}.",
      flash[:info]
    )
  ensure
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:github] = nil
  end

  test 'omniauth login with a changed github nickname does not flash if the save fails' do
    # docs/login-session-evaluation.md finding #5: `user.update` validates
    # the whole record, not just :nickname, so give it an unrelated
    # invalid column (update_column bypasses validations to get there)
    # rather than trying to make the nickname itself invalid.
    github_user = users(:github_user)
    github_user.update!(uid: 'github-test-uid')
    github_user.update_column(:name, '')
    old_nickname = github_user.nickname
    new_nickname = "#{old_nickname}-renamed"
    OmniAuth.config.test_mode = true
    OmniAuth.config.add_mock(
      :github, github_omniauth_hash(github_user, nickname: new_nickname)
    )
    get '/auth/github/callback'
    assert_response :redirect # login itself still succeeds
    assert_equal old_nickname, github_user.reload.nickname
    assert_nil flash[:info]
  ensure
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:github] = nil
  end

  # A brand-new user's nickname is already set by User.create_with_omniauth
  # from this same login's auth payload, so update_github_nickname's own
  # comparison finds nothing changed: there's no prior value to have
  # changed from, and no flash.
  test 'omniauth login for a brand-new user sets no flash' do
    OmniAuth.config.test_mode = true
    OmniAuth.config.add_mock(
      :github,
      'provider' => 'github', 'uid' => 'brand-new-uid',
      'credentials' => { 'token' => 'test_token' },
      'info' => {
        'name' => 'Brand New User', 'nickname' => 'brand-new-nickname',
        'email' => 'brand-new@example.com'
      }
    )
    assert_difference 'User.count', 1 do
      get '/auth/github/callback'
    end
    assert_nil flash[:info]
    assert_equal 'brand-new-nickname', User.find_by(uid: 'brand-new-uid').nickname
  ensure
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:github] = nil
  end

  private

  # Build an OmniAuth hash for a GitHub user fixture.
  # @param user [User] GitHub user fixture
  # @param nickname [String] GitHub nickname to report (default: the
  #   user's current one, i.e. no change)
  # @param token [String] OAuth token
  # @return [Hash] OmniAuth-compatible auth hash
  def github_omniauth_hash(user, nickname: user.nickname, token: 'test_token')
    {
      'provider' => 'github',
      'uid' => user.uid || '12345',
      'credentials' => { 'token' => token },
      'info' => {
        'name' => user.name,
        'nickname' => nickname,
        'email' => user.email
      }
    }
  end
end
