# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

class UsersLoginTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:test_user)
    @user2 = users(:test_user_not_active)
  end

  test 'login with invalid username and password' do
    get login_path, params: { locale: 'en' }
    assert_template 'sessions/new'
    post login_path, params: {
      session: {
        email: 'unknown@example.org', password: 'bad_password',
        provider: 'local'
      }
    }
    assert_template 'sessions/new'
    assert_not flash.empty?
    get root_path
    assert flash.empty?
  end

  test 'login with no provider' do
    get login_path, params: { locale: 'en' }
    assert_template 'sessions/new'
    post login_path, params: {
      session: { email: 'unknown@example.org', password: 'bad_password' }
    }
    assert_template 'sessions/new'
    assert_not flash.empty?
    get root_path
    assert flash.empty?
  end

  # See the comments on test_helper.rb method log_in_as()
  test 'login with valid information and then logout' do
    # To skip: skip('message')
    get login_path, params: { locale: 'en' }
    assert_template 'sessions/new'

    log_in_as @user

    assert user_logged_in?
    # If we redirect users to @user on login:
    # assert_redirected_to @user
    # follow_redirect!
    # assert_template 'users/show'
    # assert_select 'a[href=?]', login_path, count: 0
    # assert_select 'a[href=?]', logout_path
    # assert_select 'a[href=?]', user_path(@user)

    delete logout_path, params: { locale: 'en' }
    assert_not user_logged_in?
    assert_redirected_to root_url(locale: :en)
    follow_redirect!
    # Parentheses necessary to avoid Rubocop Lint/AmbiguousOperator error
    assert_select(+'a[href=?]', login_path(locale: :en))
    assert_select(+'a[href=?]', logout_path(locale: :en), count: 0)
    assert_select(+'a[href=?]', user_path(@user, locale: :en), count: 0)
  end

  test 'login with valid information but not activated' do
    log_in_as @user2
    assert_not user_logged_in?
    assert_redirected_to root_url(locale: :en)
    assert_not flash.empty?
  end

  test 'login with remembering' do
    log_in_as(@user, remember_me: '1')
    assert_not_nil cookies['remember_token']
    # Make sure this cookie is encrypted!
    assert_equal 22, cookies['remember_token'].length
    assert_not_includes cookies['remember_token'], 'password'
  end

  test 'login without remembering' do
    log_in_as(@user, remember_me: '0')
    assert_nil cookies['remember_token']
  end

  # Regression guard: the login page's Referrer-Policy must be same-origin,
  # not no-referrer.  Changing it back to no-referrer silently breaks GitHub
  # login for every user.  Here is the full story.
  #
  # --- Why no-referrer breaks GitHub OAuth ---
  #
  # Step 1. User visits the login page.  The page carries
  #         <meta name="referrer" content="no-referrer">, which sets the
  #         Referrer-Policy for every request originated from that page.
  #
  # Step 2. User clicks "Login with GitHub".  Rails UJS converts the
  #         method: :post link into a same-origin form POST to /auth/github.
  #
  # Step 3. Per the Fetch specification, when Referrer-Policy is no-referrer
  #         the browser suppresses origin information along with referrer
  #         information and sends "Origin: null" on the POST instead of the
  #         real origin.  (Rails' own error message for this failure says:
  #         "This usually means you have the 'no-referrer' Referrer-Policy
  #         header enabled.")
  #
  # Step 4. Rails' forgery-protection origin check sees "Origin: null", which
  #         never matches the application host, and raises
  #         InvalidAuthenticityToken.
  #
  # Step 5. OmniAuth catches the error and redirects to
  #         /auth/failure?strategy=github, which has no matching route,
  #         producing a 404 "page not found".
  #
  # --- Why same-origin fixes it ---
  #
  # Step 1. same-origin sends a real Origin header on same-origin requests,
  #         so the POST to /auth/github carries "Origin: <app-host>".
  #
  # Step 2. Rails' origin check passes; OmniAuth processes the request and
  #         issues a 302 redirect to github.com for the OAuth handshake.
  #
  # Step 3. That redirect to github.com is cross-origin.  With same-origin
  #         policy the browser sends NO Referer header on cross-origin
  #         requests, so the redirect chain to GitHub carries no Referer.
  #
  # --- Why same-origin is adequately secure ---
  #
  # The attack same-origin counters: when a user goes to GitHub for OAuth,
  # the browser would normally send the full Referer URL of the login page
  # to GitHub.  That URL can include the return_to query parameter, which
  # may contain a sensitive automation-proposal URL with project criteria
  # and justifications (e.g. /en/projects/123/edit?criterion_A=Met&...).
  # The site's global policy (no-referrer-when-downgrade) sends the full
  # Referer on HTTPS-to-HTTPS cross-origin requests, so GitHub would see
  # that sensitive data in its server logs and OAuth analytics.
  #
  # With same-origin, any cross-origin request in the chain — including the
  # redirect to github.com — carries no Referer header at all.  GitHub sees
  # only the OAuth parameters it needs; return_to is never revealed.
  test 'login page referrer policy is same-origin not no-referrer' do
    get login_path, params: { locale: 'en' }
    assert_select 'meta[name="referrer"][content="same-origin"]', count: 1
    assert_select 'meta[name="referrer"][content="no-referrer"]', count: 0
  end
end
