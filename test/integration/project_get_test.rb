# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# rubocop:disable Metrics/ClassLength
class ProjectGetTest < ActionDispatch::IntegrationTest
  setup do
    # @user = users(:test_user)
    @project_one = projects(:one)
  end

  # rubocop:disable Metrics/BlockLength
  test 'ensure getting project has expected values (esp. security headers)' do
    # Check project page values, primarily the various hardening headers
    # (in particular the Content Security Policy (CSP) header).
    # We want to make sure these headers maximally limit what browsers will
    # do as an important hardening measure.
    # The "projects" page is the page most at risk of malicious data
    # from untrusted users, so we specifically test
    # the headers for this most-at-risk page.
    # We have to do this as an integration test, not as a controller test,
    # because the secure_headers gem integrates at the Rack level
    # (thus a controller test does not invoke it).

    get project_section_path(@project_one, 'passing', locale: 'en')
    assert_response :success

    # Check some normal headers
    assert_equal('text/html; charset=utf-8', @response.headers['Content-Type'])
    assert_equal(
      # This request is anonymous, so the anonymous project show page is now
      # CDN-cacheable (see docs/cdn-cache-not-logged-in.md): cache_on_cdn sets
      # Cache-Control to 'no-store' (plus a private Surrogate-Control for the
      # CDN). Note that this test *is* seeing the rack middleware result!
      'no-store',
      @response.headers['Cache-Control']
    )

    # Check hardening headers
    assert_equal(
      "default-src 'self'; base-uri 'self'; " \
      "form-action 'self'; frame-ancestors 'none'; " \
      "img-src 'self' secure.gravatar.com avatars.githubusercontent.com; " \
      "object-src 'none'; script-src 'self'; style-src 'self'",
      @response.headers['Content-Security-Policy']
    )
    assert_equal(
      'no-referrer-when-downgrade',
      @response.headers['Referrer-Policy']
    )
    assert_equal('nosniff', @response.headers['X-Content-Type-Options'])
    assert_equal('DENY', @response.headers['X-Frame-Options'])
    assert_equal(
      'none',
      @response.headers['X-Permitted-Cross-Domain-Policies']
    )
    assert_equal('1; mode=block', @response.headers['X-XSS-Protection'])
    # Check warning on development system
    assert_match 'This is not the production system', response.body

    # We did NOT send an origin, so we don't send CORS headers
    # such as 'Access-Control-Allow-Origin'; check that.
    # If we send CORS headers "no matter what", change this, but be sure
    # that the CORS header values are secure.
    assert_nil(@response.headers['Access-Control-Allow-Origin'])
    assert_nil(@response.headers['Access-Control-Allow-Methods'])
    assert_nil(@response.headers['Access-Control-Allow-Credentials'])
  end
  # rubocop:enable Metrics/BlockLength

  test 'ensure CORS set when origin set' do
    get project_section_path(@project_one, 'passing', locale: :en),
        headers: { 'Origin' => 'https://en/example.com' }
    assert_response :success

    # When there's an origin, we allow just GET from anywhere.
    assert_equal('*', @response.headers['Access-Control-Allow-Origin'])
    assert_equal(
      'GET, OPTIONS',
      @response.headers['Access-Control-Allow-Methods']
    )

    # It would be a security disaster if this was true, so let's make
    # sure it isn't true.  This test just ensures it's blank.
    # It would also be okay if this was false, but our code doesn't do that.
    assert_nil(@response.headers['Access-Control-Allow-Credentials'])

    # It could be a security disaster if caches always served the same data
    # to different CORS origins, because private information (e.g., to system
    # admins) might leak in a cache.  The "rack-cors" gem already handles
    # this by inserting "Vary: Origin", as is standard recommended behavior
    # when using CORS.  However, it's important for security, so let's
    # verify that caching varies depending on the Origin.
    assert_equal('Accept-Encoding, Origin', @response.headers['Vary'])
  end

  test 'Redirect malformed query string criteria_level,2' do
    get "/en/projects/#{@project_one.id}?criteria_level,2"
    assert_response :moved_permanently
    assert_redirected_to "/en/projects/#{@project_one.id}/gold"
  end

  test 'Redirect malformed query string criteria_level,1' do
    get "/de/projects/#{@project_one.id}?criteria_level,1"
    assert_response :moved_permanently
    assert_redirected_to "/de/projects/#{@project_one.id}/silver"
  end

  test 'Redirect malformed query string criteria_level,0' do
    get "/fr/projects/#{@project_one.id}?criteria_level,0"
    assert_response :moved_permanently
    assert_redirected_to "/fr/projects/#{@project_one.id}/passing"
  end

  test 'Redirect well-formed query string criteria_level=1 to silver' do
    get "/en/projects/#{@project_one.id}?criteria_level=1"
    assert_response :moved_permanently
    assert_redirected_to "/en/projects/#{@project_one.id}/silver"
  end

  test 'Redirect no-locale malformed query string criteria_level,1' do
    get "/projects/#{@project_one.id}?criteria_level,1"
    assert_response :found
    # We do a 2-step redirect because the *locale* causes :found
    assert_redirected_to "/en/projects/#{@project_one.id}?criteria_level,1"
  end

  test 'Redirect well-formed query string criteria_level=2 to gold' do
    get "/de/projects/#{@project_one.id}?criteria_level=2"
    assert_response :moved_permanently
    assert_redirected_to "/de/projects/#{@project_one.id}/gold"
  end

  test 'Redirect well-formed query string criteria_level=0 to passing' do
    get "/fr/projects/#{@project_one.id}?criteria_level=0"
    assert_response :moved_permanently
    assert_redirected_to "/fr/projects/#{@project_one.id}/passing"
  end

  test 'Redirect well-formed query string criteria_level=silver to silver' do
    get "/en/projects/#{@project_one.id}?criteria_level=silver"
    assert_response :moved_permanently
    assert_redirected_to "/en/projects/#{@project_one.id}/silver"
  end

  test 'Redirect well-formed query string criteria_level=gold to gold' do
    get "/de/projects/#{@project_one.id}?criteria_level=gold"
    assert_response :moved_permanently
    assert_redirected_to "/de/projects/#{@project_one.id}/gold"
  end

  test 'Redirect well-formed query string criteria_level=passing to passing' do
    get "/fr/projects/#{@project_one.id}?criteria_level=passing"
    assert_response :moved_permanently
    assert_redirected_to "/fr/projects/#{@project_one.id}/passing"
  end

  test 'Redirect no-locale well-formed query criteria_level=1 to silver' do
    get "/projects/#{@project_one.id}?criteria_level=1"
    assert_response :found
    assert_redirected_to "/en/projects/#{@project_one.id}?criteria_level=1"
  end

  test 'Permissions show page has edit link to permissions edit page' do
    # Log in as project owner to see edit links
    log_in_as(users(:test_user))
    # View the permissions show page
    get project_section_path(@project_one, 'permissions', locale: 'en')
    assert_response :success
    # Verify edit link points to permissions edit page, not passing (0) edit page
    # 'permissions' stays as 'permissions' (not normalized to a number)
    assert_select 'a[href=?]', "/en/projects/#{@project_one.id}/permissions/edit"
  end

  test 'Silver show page has edit link to silver edit page' do
    # Log in as project owner to see edit links
    log_in_as(users(:test_user))
    # View the silver show page
    get project_section_path(@project_one, 'silver', locale: 'en')
    assert_response :success
    # Verify edit link uses human-readable 'silver', not numeric '1'
    # URLs should always use human-readable forms (passing, silver, gold)
    assert_select 'a[href=?]', "/en/projects/#{@project_one.id}/silver/edit"
  end

  test 'Section dropdown includes links to other levels' do
    # View the passing show page
    get project_section_path(@project_one, 'passing', locale: 'en')
    assert_response :success
    # Verify section dropdown contains link to silver level
    assert_select 'a[href=?]', "/en/projects/#{@project_one.id}/silver"
    # Verify section dropdown contains link to gold level
    assert_select 'a[href=?]', "/en/projects/#{@project_one.id}/gold"
    # Verify section dropdown contains link to permissions
    assert_select 'a[href=?]', "/en/projects/#{@project_one.id}/permissions"
  end

  test 'project text fields display with correct lang attribute' do
    @project_one.update!(entry_locale: 'fr')
    @project_one.update!(description_good_status: 3,
                         description_good_justification: 'Test justification')

    # Test show page has correct lang attributes
    get project_section_path(@project_one, 'passing', locale: 'en')
    assert_response :success

    # Check description has correct lang
    assert_select 'div.discussion-markdown[lang="fr"]',
                  minimum: 1, text: /#{@project_one.description}/

    # Check justification has correct lang
    assert_select 'div.justification-markdown[lang="fr"]',
                  minimum: 1

    # Test project listing page
    get '/en/projects'
    assert_response :success
    assert_select 'td span[lang="fr"]', minimum: 1

    # Test Atom feed
    get '/en/feed'
    assert_response :success
    assert_match(/lang="fr"/, @response.body,
                 'Feed should contain lang="fr" for descriptions')
  end
end
# rubocop:enable Metrics/ClassLength
