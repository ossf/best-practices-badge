# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# rubocop: disable-next Metrics/BlockLength, Metrics/ClassLength
class SessionsHelperTest < ActionView::TestCase
  setup do
    @user = users(:test_user)
    remember(@user)
  end

  test 'current_user returns right user when session is nil' do
    # Simulate what setup_authentication_state does with remember cookies
    @session_user_id = @user.id
    session[:login_session_id] = LoginSession.create_for(
      @user, ip_address: '127.0.0.1', user_agent: 'test-agent'
    ).raw_session_id
    assert_equal @user, current_user
    assert_not session[:login_session_id].nil?
    assert user_logged_in?
  end

  test 'current_user returns nil when remember digest is wrong' do
    @user.update_attribute(:remember_digest, User.digest(User.new_token))
    assert_nil current_user
  end

  # Someday re-add a test for deny_login. This older test modifies global variables
  # and thus does not parallelize well.
  # test 'current_user returns nil when deny_login' do
  #   # First, log in as user
  #   # log_in_as(@user)
  #   # assert current_user == @user
  #   # # Previous login irrelevant once deny_login is true
  #   # deny_login_old = Rails.application.config.deny_login
  #   # Rails.application.config.deny_login = true
  #   # assert current_user.nil?
  #   # # Restore normal setting
  #   # Rails.application.config.deny_login = deny_login_old
  # end

  # Unit test.  There are tricky cases, so try various forms
  test 'check safe_localized_internal_url' do
    assert_equal 'https://a.b.c/', safe_localized_internal_url('https://a.b.c/', nil)
    assert_equal 'https://a.b.c/', safe_localized_internal_url('https://a.b.c', nil)
    assert_equal 'https://a.b.c/fr', safe_localized_internal_url('https://a.b.c/', :fr)
    assert_equal 'https://a.b.c/fr', safe_localized_internal_url('https://a.b.c', :fr)
    assert_equal 'https://a.b.c/en',
                 safe_localized_internal_url('https://a.b.c?locale=fr', :en)
    assert_equal 'https://a.b.c/en',
                 safe_localized_internal_url('https://a.b.c?locale=en', :en)
    assert_equal 'https://a.b/en', safe_localized_internal_url('https://a.b', :en)
    assert_equal 'https://a.b/fr/projects',
                 safe_localized_internal_url('https://a.b/zh-CN/projects', :fr)
    assert_equal 'https://a.b/zh-CN/projects',
                 safe_localized_internal_url('https://a.b/fr/projects', :'zh-CN')
    assert_equal 'https://a.b/zh-CN/projects',
                 safe_localized_internal_url('https://a.b/projects', :'zh-CN')
    assert_equal 'https://a.b/en/projects',
                 safe_localized_internal_url('https://a.b/zh-CN/projects', :en)
    assert_equal 'https://a.b/fr/projects/1?criteria_level=2',
                 safe_localized_internal_url(
                   'https://a.b/projects/1?locale=ja&criteria_level=2', :fr
                 )
    assert_equal 'https://a.b/fr/projects/1?criteria_level=2',
                 safe_localized_internal_url(
                   'https://a.b/projects/1?criteria_level=2&locale=ja', :fr
                 )
  end
  class StubOctokitResult
    attr_accessor :permissions, :html_url

    def initialize(admin, push, pull, url = 'https://github.com/test/repo')
      self.permissions = { admin: admin, push: push, pull: pull }
      self.html_url = url
    end
  end

  class StubOctokitClient
    def initialize(**params); end

    def repo(path, **_opts)
      if path == 'ciitest/asdf'
        StubOctokitResult.new(true, true, true)
      elsif path == 'ciitest2/asdf'
        StubOctokitResult.new(false, true, true)
      elsif path == 'ciitest3/asdf'
        StubOctokitResult.new(false, false, true)
      else
        raise Octokit::NotFound
      end
    end

    def repos(**_opts)
      [
        StubOctokitResult.new(true, true, true)
      ]
    end
  end

  class StubOctokitErrorClient
    def initialize(**_params); end

    def repos(**_opts)
      raise Octokit::Unauthorized.new(
        method: :get,
        url: 'https://api.github.com/user/repos',
        status: 401,
        body: 'Bad credentials'
      )
    end
  end

  # Unit test 'github_user_projects_include?'.
  # Doing integration tests with "real" data is a little dangerous
  # because that requires a user with a *lot* of repos; our test user
  # doesn't have that many, and we don't want to use real users for testing.
  # So we'll stub things out just enough to do a unit test.
  test 'unit test of github_user_projects_include?' do
    @session_user_token = 'fake_token'
    assert github_user_can_push?(
      'https://github.com/ciitest/asdf', StubOctokitClient
    )
    assert github_user_can_push?(
      'https://github.com/ciitest2/asdf', StubOctokitClient
    )
    assert_not github_user_can_push?(
      'https://github.com/ciitest3/asdf', StubOctokitClient
    )
    assert_not github_user_can_push?(
      'https://github.com/not-here/not-found',
      StubOctokitClient
    )
  end

  test 'unit test of get_gethub_owner' do
    assert_equal 'ciitest', get_github_owner('https://github.com/ciitest/1234')
    assert_equal 'asdf-123',
                 get_github_owner('https://github.com/asdf-123/456')
    assert_equal 'ciitest2',
                 get_github_owner('https://github.com/ciitest2/1234')
    assert_nil get_github_owner('http://githubs.com/asdf/1234')
  end

  test 'unit test of get_github_path' do
    assert_equal 'ciitest/1234',
                 get_github_path('https://github.com/ciitest/1234')
    assert_equal 'asdf-123/456',
                 get_github_path('https://github.com/asdf-123/456')
    assert_equal 'ciitest2/1234',
                 get_github_path('https://github.com/ciitest2/1234')
    assert_nil get_github_path('http://githubs.com/asdf/1234')
  end

  test 'valid_return_path? rejects invalid inputs' do
    assert_not valid_return_path?(nil)
    assert_not valid_return_path?('')
    assert_not valid_return_path?({})              # non-string: would crash without is_a? check
    assert_not valid_return_path?(['/good'])       # non-string array
    assert_not valid_return_path?('http://evil.com/steal')   # absolute URL
    assert_not valid_return_path?('javascript:alert(1)')     # JS scheme
    assert_not valid_return_path?('//evil.com/steal')        # protocol-relative
    assert_not valid_return_path?('/login')                  # bare login
    assert_not valid_return_path?('/signup')                 # bare signup
    assert_not valid_return_path?('/signout')                # bare signout (GET destroys session)
    assert_not valid_return_path?('/en/login')               # locale + login
    assert_not valid_return_path?('/fr/login')
    assert_not valid_return_path?('/zh-CN/login')            # BCP 47 region variant
    assert_not valid_return_path?('/en/signup')
    assert_not valid_return_path?('/en/signout')
    assert_not valid_return_path?('/en/login/')              # trailing slash
    assert_not valid_return_path?('/en/login?x=1')           # with query string
  end

  test 'valid_return_path? accepts valid paths' do
    assert valid_return_path?('/')
    assert valid_return_path?('/en/projects/1/passing/edit')
    assert valid_return_path?('/en/projects/1/passing/edit?description=foo')
    assert valid_return_path?('/loginpage')    # login not at path boundary
    assert valid_return_path?('/en/loginpage') # same with locale
  end

  test 'unit test of valid_github_url' do
    assert valid_github_url? 'https://github.com/asdf/1234/'
    assert valid_github_url? 'https://github.com/asdf-123_/1234as-/'
    assert_not valid_github_url? 'https://github.com/asdf123_/1234%20as-/'
    assert_not valid_github_url? 'https://github.com/asdf%20123_/1234as-/'
    assert_not valid_github_url? 'https://github.com/asdf123_/1234 as-/'
    assert_not valid_github_url? 'https://github.com/asdf 123_/1234as-/'
    assert_not valid_github_url? 'https://github.com.more/asdf-123_/1234as-/'
    assert_not valid_github_url? 'https://my.github.com/asdf-123_/1234as-/'
    assert_not valid_github_url? 'http://github.com/asdf/1234/'
    assert_not valid_github_url? 'https://github.com/asdf/1234-/s'
    assert_not valid_github_url? 'https://github.com/asdf/1234/?'
    assert_not valid_github_url? 'https://githubs.com/asdf/1234/'
  end

  test 'github_user_projects returns list' do
    @session_user_token = 'fake_token'
    result = github_user_projects(StubOctokitClient)
    assert_equal 1, result.length
    assert_equal 'https://github.com/test/repo', result.first
  end

  test 'github_user_projects handles errors' do
    @session_user_token = 'fake_token'
    result = github_user_projects(StubOctokitErrorClient)
    assert_equal [], result
  end

  # docs/login-session-18.md step 19: current_user_is_github_owner? must
  # depend only on current_user.nickname (a DB column, gated behind
  # login_session_id), never a session value someone could forge.
  test 'current_user_is_github_owner? checks current_user.nickname' do
    github_user = users(:github_user)
    @session_user_id = github_user.id
    session[:login_session_id] = LoginSession.create_for(
      github_user, ip_address: '127.0.0.1', user_agent: 'test-agent'
    ).raw_session_id

    assert current_user_is_github_owner?(
      "https://github.com/#{github_user.nickname}/repo"
    )
    assert_not current_user_is_github_owner?('https://github.com/someone-else/repo')

    # There is nothing left to forge here (step 19 removed
    # session[:github_name] entirely): setting a same-named session key
    # has no effect on the decision above.
    session[:github_name] = 'someone-else'
    assert current_user_is_github_owner?(
      "https://github.com/#{github_user.nickname}/repo"
    )
  end

  # docs/login-session-evaluation.md finding #3: a distributed attacker (many source IPs, one
  # target user_id) bypasses every IP-based throttle in rack_attack.rb, so
  # this needs its own, IP-independent limit.
  test 'login_rate_limited? is always false outside production' do
    saved_limit = ENV.fetch('RATE_LOGINS_USER_LIMIT', nil)
    ENV['RATE_LOGINS_USER_LIMIT'] = '1'
    3.times { assert_not login_rate_limited?(@user) }
  ensure
    ENV['RATE_LOGINS_USER_LIMIT'] = saved_limit
  end

  test 'login_rate_limited? becomes true once the per-user limit is exceeded' do
    saved_limit = ENV.fetch('RATE_LOGINS_USER_LIMIT', nil)
    saved_period = ENV.fetch('RATE_LOGINS_USER_PERIOD', nil)
    ENV['RATE_LOGINS_USER_LIMIT'] = '2'
    ENV['RATE_LOGINS_USER_PERIOD'] = '60'
    # The counter is a real, process-wide cache keyed by user_id and time
    # bucket (Rack::Attack::Cache#count), so it survives between tests that
    # share this fixture's user within the same 60-second window. Reset it
    # first so this test starts from zero regardless of run order.
    Rack::Attack.cache.reset_count("logins/user:#{@user.id}", 60)

    assert_not login_rate_limited?(@user, production: true)
    assert_not login_rate_limited?(@user, production: true)
    assert login_rate_limited?(@user, production: true)
  ensure
    ENV['RATE_LOGINS_USER_LIMIT'] = saved_limit
    ENV['RATE_LOGINS_USER_PERIOD'] = saved_period
  end

  test 'login_rate_limited? counts each user_id separately' do
    saved_limit = ENV.fetch('RATE_LOGINS_USER_LIMIT', nil)
    saved_period = ENV.fetch('RATE_LOGINS_USER_PERIOD', nil)
    ENV['RATE_LOGINS_USER_LIMIT'] = '1'
    ENV['RATE_LOGINS_USER_PERIOD'] = '60'
    other_user = users(:test_user_not_active)
    Rack::Attack.cache.reset_count("logins/user:#{@user.id}", 60)
    Rack::Attack.cache.reset_count("logins/user:#{other_user.id}", 60)

    assert_not login_rate_limited?(@user, production: true)
    assert login_rate_limited?(@user, production: true)
    # A different user_id has its own, still-fresh count.
    assert_not login_rate_limited?(other_user, production: true)
  ensure
    ENV['RATE_LOGINS_USER_LIMIT'] = saved_limit
    ENV['RATE_LOGINS_USER_PERIOD'] = saved_period
  end
end
