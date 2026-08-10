# frozen_string_literal: true

# Copyright the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# Verifies ApplicationController#drop_unneeded_session_cookie: a browser
# holding a session cookie that no longer carries anything useful gets it
# actively deleted, so it falls back onto the CDN-cached anonymous pages
# instead of bypassing the cache until the browser closes.
#
# These tests assert the FINAL cookie outcome (what the response does to the
# cookie, or the browser's end state) rather than any Rails/middleware
# internal -- the flash-in-session handling and empty-session cookie behavior
# have varied across framework versions, so we pin to the observable result.
class DropSessionCookieTest < ActionDispatch::IntegrationTest
  # Read the name from the same constant the controller uses, so a cookie
  # rename can't silently make these tests pass against the wrong cookie.
  SESSION_KEY = ApplicationController::SESSION_COOKIE_NAME

  setup do
    @project = projects(:one)
    # An anonymous, read-only page that writes nothing into the session.
    @anon_path = "/en/projects/#{@project.id}/passing"
  end

  # --- helpers: what the response did to the session cookie ---

  def set_cookie_lines
    Array(response.headers['Set-Cookie']).flat_map { |h| h.to_s.split("\n") }
  end

  def session_cookie_lines
    set_cookie_lines.select { |line| line.start_with?("#{SESSION_KEY}=") }
  end

  # A deletion has an empty value and/or a past expiry / max-age 0.
  def deletion_line?(line)
    line.start_with?("#{SESSION_KEY}=;") ||
      line.match?(/expires=thu, 01[ -]jan[ -]1970/i) ||
      line.match?(/max-age=0\b/i)
  end

  def session_cookie_deleted?
    session_cookie_lines.any? { |line| deletion_line?(line) }
  end

  def with_forgery_protection
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  # --- tests ---

  # Anonymous, carrying a spent/empty session cookie: it is deleted, so the
  # next request is cookie-free and can be served straight from the CDN cache.
  test 'anonymous request carrying a spent session cookie deletes it' do
    cookies[SESSION_KEY] = 'stale'
    get @anon_path
    assert_response :success
    assert session_cookie_deleted?,
           'a spent anonymous session cookie should be actively deleted'
  end

  # No cookie sent: the response must NOT emit any session Set-Cookie. This is
  # the load-bearing guard -- such a header would be cached and shipped to
  # every visitor, deleting their cookies and polluting the cached object.
  test 'anonymous request with no cookie emits no session Set-Cookie' do
    get @anon_path
    assert_response :success
    assert_empty session_cookie_lines,
                 'must not touch the session cookie when none was sent'
  end

  # Logged in: never delete -- the cookie is doing its job.
  test 'logged-in request never deletes the session cookie' do
    log_in_as(users(:test_user))
    get @anon_path
    assert_response :success
    assert_not session_cookie_deleted?,
               'a logged-in session cookie must not be deleted'
  end

  # A request that stores a CSRF token (a rendered anonymous form) must KEEP
  # the cookie, or the form's embedded authenticity_token would be orphaned
  # and the POST would fail CSRF. Needs forgery protection ON (off in test).
  test 'request that stores a CSRF token keeps the session cookie' do
    with_forgery_protection do
      cookies[SESSION_KEY] = 'stale'
      # The login page renders forms -> writes session[:_csrf_token].
      get login_path(locale: :en)
      assert_response :success
      assert_not session_cookie_deleted?,
                 'a session holding a CSRF token must keep its cookie'
    end
  end

  # A persistent flash being displayed must KEEP the cookie on the request
  # that shows it (flash.empty? is false there).
  test 'request displaying a carried-over flash keeps the session cookie' do
    post '/en/password_resets',
         params: { password_reset: { email: 'nobody@example.org' } }
    assert response.redirect?
    get @anon_path # displays the flash
    assert_response :success
    assert_not session_cookie_deleted?,
               'cookie carrying a flash must survive the request showing it'
  end

  # ...and once that flash is spent, the browser ends up WITHOUT the cookie.
  # Asserts the browser end state (cookie jar), so it holds whether the cookie
  # was cleared by our after_action or by the framework.
  test 'a spent-flash cookie is gone from the browser next request' do
    post '/en/password_resets',
         params: { password_reset: { email: 'nobody@example.org' } }
    get @anon_path # show + sweep the flash; cookie kept here
    assert_not session_cookie_deleted?
    get @anon_path # clean request: empty session -> cookie dropped
    assert cookies[SESSION_KEY].blank?,
           'after the flash is spent the browser should not carry the cookie'
  end
end
