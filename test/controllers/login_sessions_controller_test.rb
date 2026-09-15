# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

class LoginSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:test_user)
    @admin = users(:admin_user)
  end

  test 'anonymous visitor is redirected away, not shown the list' do
    get '/en/login_sessions'
    assert_redirected_to root_url(locale: :en)
    follow_redirect!
    assert_includes @response.body, 'Admin only.'
  end

  test 'non-admin user is redirected away, not shown the list' do
    log_in_as(@user)
    get '/en/login_sessions'
    assert_redirected_to root_url(locale: :en)
    follow_redirect!
    assert_includes @response.body, 'Admin only.'
  end

  test 'admin sees the list of active login sessions' do
    log_in_as(@admin)
    get '/en/login_sessions'
    assert_response :success
    # log_in_as itself created a LoginSession row for @admin; it should
    # be listed, linked to the admin's own name and ID.
    assert_includes @response.body, @admin.name
    assert_select "a[href='#{user_path(@admin)}']", text: @admin.name
    assert_select "a[href='#{user_path(@admin)}']", text: @admin.id.to_s
  end

  test 'shows the role column, blank for a normal user, admin for an admin' do
    log_in_as(@admin) # creates a LoginSession row for the admin
    LoginSession.create_for(@user, ip_address: '127.0.0.1', user_agent: 'a')
    get '/en/login_sessions'
    assert_response :success
    doc = Nokogiri::HTML5(@response.body)
    admin_row = doc.css('tr').find { |tr| tr.text.include?(@admin.name) }
    user_row = doc.css('tr').find { |tr| tr.text.include?(@user.name) }
    assert_includes admin_row.text, @admin.role
    assert_not_includes user_row.text, 'admin'
  end

  test 'user_agent renders escaped, not as raw HTML (stored XSS)' do
    log_in_as(@admin)
    LoginSession.create_for(
      @user, ip_address: '127.0.0.1',
             user_agent: '<script>alert(1)</script>'
    )
    get '/en/login_sessions'
    assert_response :success
    assert_not_includes @response.body, '<script>alert(1)</script>'
    assert_includes @response.body, '&lt;script&gt;alert(1)&lt;/script&gt;'
  end
end
