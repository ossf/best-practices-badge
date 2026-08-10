# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

class PasswordResetsTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
    @user = users(:test_user)
    @ghuser = users(:github_user)
  end

  # rubocop:disable Metrics/BlockLength
  test 'password resets' do
    get new_password_reset_path(locale: :en)
    assert_template 'password_resets/new'
    # Invalid email
    post password_resets_path,
         params: { password_reset: { email: '' }, locale: :en }
    assert_not flash.empty?
    assert_redirected_to root_url(locale: :en)
    # Valid email, github user
    post password_resets_path,
         params: { password_reset: { email: @ghuser.email }, locale: :en }
    assert_equal 0, ActionMailer::Base.deliveries.size
    assert_not flash.empty?
    assert_redirected_to root_url(locale: :en)
    # Unactivated account - no email should be sent
    unactivated = users(:test_user_not_active)
    post password_resets_path,
         params: { password_reset: { email: unactivated.email }, locale: :en }
    assert_equal 0, ActionMailer::Base.deliveries.size
    assert_redirected_to root_url(locale: :en)
    # Valid email
    post password_resets_path,
         params: { password_reset: { email: @user.email }, locale: :en }
    assert_not_equal @user.reset_digest, @user.reload.reset_digest
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_not flash.empty?
    assert_redirected_to root_url(locale: :en)
    # Password reset form
    user = assigns(:user)
    # Wrong email
    get edit_password_reset_path(user.reset_token, email: '', locale: :en)
    assert_redirected_to root_url
    # Inactive user
    user.toggle!(:activated)
    get edit_password_reset_path(
      user.reset_token,
      email: user.email, locale: :en
    )
    assert_redirected_to root_url(locale: :en)
    user.toggle!(:activated)
    # Right email, wrong token
    get edit_password_reset_path('wrong token', email: user.email, locale: :en)
    assert_redirected_to root_url(locale: :en)
    # Right email, right token
    get edit_password_reset_path(
      user.reset_token, email: user.email, locale: :en
    )
    assert_template 'password_resets/edit'
    assert_select(+'input[name=email][type=hidden][value=?]', user.email)
    # Invalid password & confirmation
    patch password_reset_path(user.reset_token), params: {
      email: user.email,
      user: {
        password:              '1235foo',
        password_confirmation: 'bar4567'
      },
      locale: :en
    }
    assert_select 'div#error_explanation'
    # Empty password
    patch password_reset_path(user.reset_token), params: {
      email: user.email,
      user: {
        password:              '',
        password_confirmation: ''
      },
      locale: :en
    }
    assert_select 'div#error_explanation'
    # Valid password & confirmation
    patch password_reset_path(user.reset_token), params: {
      email: user.email,
      user: {
        password:              'foo1234!',
        password_confirmation: 'foo1234!'
      },
      locale: :en
    }
    assert_not user_logged_in?
    assert_not flash.empty?
    assert_redirected_to login_url(locale: :en)
  end

  test 'expired token' do
    get new_password_reset_path(locale: :en)
    post password_resets_path(locale: :en),
         params: {
           password_reset: {
             email: @user.email
           },
           locale: 'en'
         }

    @user = assigns(:user)
    @user.update_attribute(:reset_sent_at, 3.hours.ago)
    patch password_reset_path(@user.reset_token, locale: :en), params: {
      email: @user.email,
      user: {
        password:              'foo1234',
        password_confirmation: 'bar5678'
      },
      locale: :en
    }
    assert_response :redirect
    follow_redirect!
    assert_match 'expired', response.body
  end
  # rubocop:enable Metrics/BlockLength
end
