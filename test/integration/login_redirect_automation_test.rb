# frozen_string_literal: true

# Copyright the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# Tests that unauthenticated users visiting project edit URLs with
# automation query params are redirected to login with a return_to param,
# and after successful login are sent back to the original URL with params
# preserved.
# rubocop:disable Metrics/ClassLength
class LoginRedirectAutomationTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:one)
    @user = users(:test_user) # local user, owns project :one
  end

  test 'unauthenticated edit redirects to login with return_to param' do
    get "/en/projects/#{@project.id}/passing/edit"
    assert_response :redirect
    assert_match %r{/en/login\?return_to=}, response.location
  end

  test 'unauthenticated edit encodes full path with query in return_to' do
    edit_url = "/en/projects/#{@project.id}/passing/edit?description=New+desc"
    get edit_url
    assert_response :redirect
    redirect_location = response.location
    assert_match %r{/en/login\?return_to=}, redirect_location
    decoded = CGI.unescape(URI.parse(redirect_location).query.split('return_to=').last)
    assert_includes decoded, "projects/#{@project.id}/passing/edit"
    assert_includes decoded, 'description'
  end

  test 'local user login redirects back to edit URL with automation params' do
    edit_path = "/en/projects/#{@project.id}/passing/edit" \
                '?description=Automated+description'
    # Step 1: Visit edit page - extract return_to from redirect
    get edit_path
    assert_response :redirect
    return_to = CGI.unescape(URI.parse(response.location).query.split('return_to=').last)

    # Step 2: Log in including the return_to param
    post login_path, params: {
      session: {
        email: @user.email, password: 'password',
        provider: 'local', remember_me: '0',
        return_to: return_to
      }
    }
    assert_response :redirect

    # Step 3: Verify redirect goes back to edit URL with automation params
    assert user_logged_in?
    redirect_location = response.location
    assert_includes redirect_location, "projects/#{@project.id}/passing/edit"
    assert_includes redirect_location, 'description=Automated+description'

    # Step 4: Follow redirect and confirm we get the edit form
    follow_redirect!
    assert_response :success
  end

  test 'local user login redirects to edit with multiple automation params' do
    edit_path = "/en/projects/#{@project.id}/passing/edit" \
                '?description=Auto+desc&name=Auto+name'
    get edit_path
    return_to = CGI.unescape(URI.parse(response.location).query.split('return_to=').last)

    post login_path, params: {
      session: {
        email: @user.email, password: 'password',
        provider: 'local', remember_me: '0',
        return_to: return_to
      }
    }

    redirect_location = response.location
    assert_includes redirect_location, 'description=Auto+desc'
    assert_includes redirect_location, 'name=Auto+name'
  end

  test 'unauthorized user gets redirected to project show after login' do
    other_user = users(:test_user_melissa) # password is 'password1'
    edit_path = "/en/projects/#{@project.id}/passing/edit" \
                '?description=Automated+description'

    # Step 1: Visit edit page - extract return_to from redirect
    get edit_path
    return_to = CGI.unescape(URI.parse(response.location).query.split('return_to=').last)

    # Step 2: Log in as a different user who does NOT own this project
    post login_path, params: {
      session: {
        email: other_user.email, password: 'password1',
        provider: 'local', remember_me: '0',
        return_to: return_to
      }
    }
    assert_response :redirect

    # Step 3: Follow the redirect to the edit URL
    follow_redirect!

    # Step 4: can_edit_else_redirect should redirect to project show page
    # because user is logged in but not authorized, with flash message
    assert_response :redirect
    assert_redirected_to project_section_path(@project, 'passing')
    assert_equal 'You are not authorized to edit this project.',
                 flash[:danger]
  end

  test 'unauthenticated edit with baseline section encodes correct return_to' do
    edit_url = "/en/projects/#{@project.id}/baseline-1/edit" \
               '?description=Baseline+desc'
    get edit_url
    assert_response :redirect
    redirect_location = response.location
    assert_match %r{/en/login\?return_to=}, redirect_location
    decoded = CGI.unescape(URI.parse(redirect_location).query.split('return_to=').last)
    assert_includes decoded, 'baseline-1/edit'
    assert_includes decoded, 'description'
  end

  # Regression test: return_to must survive the full browser redirect chain.
  # When sessions#new is reached via a locale redirect (/login -> /en/login),
  # the return_to query param must be preserved and appear in the login form.
  test 'return_to param survives redirect to login page' do
    edit_path = "/en/projects/#{@project.id}/passing/edit" \
                '?description=Survives+visit'
    # Step 1: Access protected edit URL -> redirects to login with return_to
    get edit_path
    assert_match %r{/en/login\?return_to=}, response.location

    # Step 2: Follow the redirect(s) to actually render the login page.
    # The return_to must appear as a hidden field in the login form.
    follow_redirect!
    follow_redirect! if response.redirect? # handle /login -> /en/login hop
    assert_response :success

    assert_select "input[type='hidden'][name='session[return_to]']"
  end

  test 'login after visiting login page redirects back with params' do
    edit_path = "/en/projects/#{@project.id}/passing/edit" \
                '?description=Full+flow+desc'
    # Step 1: Access protected page - extract return_to from redirect
    get edit_path
    assert_match %r{/en/login\?return_to=}, response.location
    return_to = CGI.unescape(URI.parse(response.location).query.split('return_to=').last)

    # Step 2: Follow redirect(s) to reach login page (exercises sessions#new)
    follow_redirect!
    follow_redirect! if response.redirect?
    assert_response :success

    # Step 3: Log in with return_to param (mirrors what the form hidden field sends)
    post login_path, params: {
      session: {
        email: @user.email, password: 'password',
        provider: 'local', remember_me: '0',
        return_to: return_to
      }
    }
    assert_response :redirect

    # Step 4: Verify redirect contains the original query params
    redirect_location = response.location
    assert_includes redirect_location, "projects/#{@project.id}/passing/edit",
                    'must redirect back to edit page, not root'
    assert_includes redirect_location, 'description=Full+flow+desc',
                    'query params must be preserved through full login flow'
  end

  # Regression test: the original bug was a CookieOverflow 500 error when a
  # non-logged-in user visited an automation-proposal URL long enough (~2000+
  # chars) to overflow the 4KB cookie-based session after encryption. The
  # return_to query-parameter approach avoids the session entirely, so there
  # is no size limit on the destination URL.
  test 'very long automation proposal URL survives login redirect without error' do
    # Build a URL representative of a real automation proposal: many
    # criteria status + justification params, totalling well over 2000 chars.
    many_params = (1..30).map do |i|
      "criterion_#{i}_status=Met&criterion_#{i}_justification=#{'x' * 40}"
    end.join('&')
    long_edit_path = "/en/projects/#{@project.id}/passing/edit?#{many_params}"
    assert long_edit_path.length > 2000, 'test URL must be > 2000 chars to be meaningful'

    # Step 1: Unauthenticated visit must redirect to login (not 500) and
    #         preserve the full path+query in the return_to param.
    get long_edit_path
    assert_response :redirect
    assert_match %r{/en/login\?return_to=}, response.location,
                 'must redirect to login with return_to, not crash'
    return_to = CGI.unescape(URI.parse(response.location).query.split('return_to=').last)
    assert return_to.length > 2000, 'full long path must be preserved in return_to'

    # Step 2: Log in with the return_to param (as the hidden form field would send).
    post login_path, params: {
      session: {
        email: @user.email, password: 'password',
        provider: 'local', remember_me: '0',
        return_to: return_to
      }
    }
    assert_response :redirect

    # Step 3: Redirect must go back to the original long URL, not root.
    redirect_location = response.location
    assert_includes redirect_location, "projects/#{@project.id}/passing/edit",
                    'must redirect back to edit page, not root'
    assert_includes redirect_location, 'criterion_1_status=Met',
                    'automation params must be preserved through login'
  end
end
# rubocop:enable Metrics/ClassLength
