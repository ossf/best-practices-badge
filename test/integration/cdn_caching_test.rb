# frozen_string_literal: true

# Copyright the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# rubocop:disable Metrics/ClassLength
class CdnCachingTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @project = projects(:one)
  end

  # The CDN treats "has _BadgeApp_session" as "do not cache". Anonymous
  # read-only pages must therefore NOT set that cookie. If this fails, the
  # CDN would needlessly bypass the cache for ordinary guests.
  # The page list is deliberately broad: if someone later adds anonymous
  # UJS/AJAX (which would force the CSRF meta tag back on) to a common page,
  # this test trips. Add new anonymous read-only pages here as they appear.
  # Note: "/en/projects/:id" (project_redirect) is a redirect to the default
  # section; the rendered show page is "/en/projects/:id/:section".
  test 'anonymous read-only GETs set no session cookie' do
    with_forgery_protection do
      [
        '/en',
        '/en/projects',
        "/en/projects/#{@project.id}/passing",
        '/en/feed'
      ].each do |path|
        get path
        assert_response :success
        assert_nil cookies['_BadgeApp_session'],
                   "#{path} unexpectedly set _BadgeApp_session"
        assert_not response.headers['Set-Cookie'].to_s.include?(
          '_BadgeApp_session'
        ), "#{path} unexpectedly emitted a session Set-Cookie"
      end
    end
  end

  # Anonymous project show (HTML) is cacheable: it must advertise a
  # Surrogate-Control header to the CDN and must not emit a session cookie.
  test 'anonymous project show is CDN-cacheable' do
    with_forgery_protection do
      get "/en/projects/#{@project.id}/passing"
      assert_response :success
      assert response.headers['Surrogate-Control'].present?,
             'show should send Surrogate-Control for the CDN'
      assert_equal 'no-store', response.headers['Cache-Control']
      assert_nil cookies['_BadgeApp_session']
    end
  end

  # CORE CORRECTNESS INVARIANT (Sections 4.1 and 9.4): the CDN serves one
  # cached object to every anonymous visitor, so two anonymous show responses
  # must be byte-identical. All show-page personalization is login-derived
  # (can_edit?, can_control?, the @session_user_id header gate) or carried in
  # the URL (locale, section); an anonymous request has nothing left to vary.
  # If a future change adds anonymous-only variance (an IP-, Accept-Language-,
  # A/B-, or time-dependent fragment in the body or header), this test fails.
  test 'anonymous project show is identical across requests' do
    with_forgery_protection do
      # Cover sections with different view-only rendering paths: the criteria
      # sections render a bootstrap_form_for (whose authenticity_token must be
      # suppressed in view_only mode) and "permissions" renders a non-form
      # branch. Both must be byte-identical across anonymous requests.
      %w[passing silver gold baseline-1 permissions].each do |section|
        get "/en/projects/#{@project.id}/#{section}"
        assert_response :success
        first_body = response.body
        get "/en/projects/#{@project.id}/#{section}"
        assert_response :success
        assert_equal first_body, response.body,
                     "anonymous show (#{section}) responses must be " \
                     'byte-identical so the CDN can safely share one cached ' \
                     'object among all guests'
      end
    end
  end

  # Logged-in users must bypass the cache: a private, non-cacheable response.
  test 'logged-in project show is not CDN-cacheable' do
    log_in_as(users(:test_user)) # POSTs login; do this before enabling CSRF
    with_forgery_protection do
      get "/en/projects/#{@project.id}/passing"
      assert_response :success
      assert_equal 'private, no-store', response.headers['Cache-Control']
    end
  end

  # The CSRF meta tag must be absent for anonymous users (so no session
  # cookie is written) and present for logged-in users (UJS links need it).
  test 'csrf meta tag is gated on login' do
    with_forgery_protection do
      get "/en/projects/#{@project.id}/passing"
      assert_select 'meta[name="csrf-token"]', count: 0
    end

    log_in_as(users(:test_user))
    with_forgery_protection do
      get "/en/projects/#{@project.id}/passing"
      assert_select 'meta[name="csrf-token"]', count: 1
    end
  end

  # The login page initiates GitHub OAuth with a rails-ujs "method: post"
  # link, which reads the CSRF token from the meta tag. Change 1 removes that
  # tag for anonymous users, so the login page must opt back in via
  # content_for(:needs_csrf_meta). Without the tag the POST to /auth/github
  # fails CSRF (ActionController::InvalidAuthenticityToken) and login 404s.
  # This must be tested with forgery protection ON: it is off by default in
  # the test env, so the bug is invisible otherwise (see Section 6 caveat).
  test 'anonymous login page emits the CSRF meta tag for GitHub OAuth' do
    with_forgery_protection do
      get login_path(locale: :en)
      assert_response :success
      assert_select 'meta[name="csrf-token"]', count: 1
    end
  end

  # An obsolete-section 301 from inside show must NOT be cached: the
  # "return if performed?" guard keeps cache_on_cdn from attaching to it.
  test 'obsolete-section redirect is not CDN-cacheable' do
    get "/en/projects/#{@project.id}/0" # "0" -> "passing"
    assert_response :moved_permanently
    assert_equal 'private, no-store', response.headers['Cache-Control']
    assert_nil response.headers['Surrogate-Control']
  end

  # A locale redirect varies by Accept-Language and must never be cached.
  test 'locale redirect is not cacheable' do
    get "/projects/#{@project.id}/passing" # no locale in URL
    assert_response :found # 302, not 301
    assert_equal 'private, no-store', response.headers['Cache-Control']
  end

  # A show page that renders a carried-over flash is per-user content and must
  # not be CDN-cached. (No forgery protection here: test env disables it, and
  # this exercises the flash guard, not CSRF.)
  test 'project show rendering a carried-over flash is not CDN-cacheable' do
    # Sets a persistent flash[:info] in the session, then redirects.
    post '/en/password_resets',
         params: { password_reset: { email: 'nobody@example.org' } }
    assert response.redirect?
    # The next rendered page displays that flash, so show must skip caching.
    get "/en/projects/#{@project.id}/passing"
    assert_response :success
    assert_equal 'private, no-store', response.headers['Cache-Control'],
                 'show rendering a carried-over flash must not be cached'
  end

  # Lock in the purge path: the cached HTML show response must carry the
  # project's surrogate key, so the existing edit-time purge (which purges
  # that exact key) also evicts the cached show page (Section 9.3).
  test 'show advertises the project surrogate key for purging' do
    get "/en/projects/#{@project.id}/passing"
    assert_equal "projects/#{@project.id}",
                 response.headers['Surrogate-Key']
  end

  # A permissions-only edit changes the AdditionalRight table -- which the
  # anonymous /permissions page renders via additional_rights_to_s -- without
  # necessarily changing the projects row. The cached page must still be
  # purged. projects#update schedules the delayed re-purge UNCONDITIONALLY on
  # entry (not gated on @project.save), so even a rights-only change (and the
  # save-fails-after-rights-changed path) enqueues a purge of the project's
  # surrogate key. This guards against a future refactor that re-gates the
  # purge on @project.saved_changes? and would silently serve stale rights.
  test 'permissions-only update enqueues a CDN purge of the project key' do
    log_in_as(@project.user)
    assert_enqueued_with(
      job: PurgeCdnProjectJob, args: [@project.record_key]
    ) do
      patch "/en/projects/#{@project.id}", params: {
        # Leave the project row unchanged; exercise the rights-only path.
        project: { name: @project.name },
        additional_rights_changes: "+ #{users(:test_user_mark).id}"
      }
    end
  end

  def with_forgery_protection
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = original
  end
end
# rubocop:enable Metrics/ClassLength
