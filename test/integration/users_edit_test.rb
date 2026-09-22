# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# rubocop:disable-next Metrics/ClassLength
class UsersEditTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:test_user)
  end

  test 'unsuccessful edit - email' do
    log_in_as(@user)
    get edit_user_path(@user)
    assert_template 'users/edit'
    patch user_path(@user), params: {
      user: {
        name:  '',
            email: 'foo@invalid',
            password:              '',
            password_confirmation: ''
      }
    }
    assert_template 'users/edit'
  end

  test 'unsuccessful edit - password' do
    log_in_as(@user)
    get edit_user_path(@user)
    assert_template 'users/edit'
    patch user_path(@user), params: {
      user: {
        name:  '',
            email: '',
            password:              'password',
            password_confirmation: 'password'
      }
    }
    assert_template 'users/edit'
  end

  test 'successful edit - name/email' do
    log_in_as(@user)
    get edit_user_path(@user)
    assert_template 'users/edit'
    ActionMailer::Base.deliveries.clear
    name  = 'Foo Bar'
    email = 'foo@bar.com'
    VCR.use_cassette('successful_edit_-_name_email') do
      patch user_path(@user), params: {
        user: {
          name:  name,
                email: email,
                password:              '',
                password_confirmation: ''
        }
      }
    end
    assert_not flash.empty?
    assert_redirected_to @user
    # Ensure that we sent one email:
    assert_equal 1, ActionMailer::Base.deliveries.size
    # Ensure that we sent the email to two destination addresses (old + new).
    # This is an important check for security.  If an attacker temporarily
    # gains control over a user account, this ensures that any change to the
    # account's email address will alert the old email address.
    # Obviously we don't want takeovers to happen in the first place, but
    # always doing this reduces the potential damage.
    assert_equal ['foo@bar.com', 'test@example.org'],
                 ActionMailer::Base.deliveries[0]['To'].unparsed_value
    # Forcibly load the data from the database, and ensure that we
    # can retrieve from the database the values we supposedly just changed.
    @user.reload
    assert_equal name,  @user.name
    assert_equal email, @user.email
  end

  test 'successful edit - password' do
    log_in_as(@user)
    original_login_session_id = session[:login_session_id]
    # Simulate a second, already-open browser tab for this same user.
    other_login_session = LoginSession.create_for(
      @user, ip_address: '127.0.0.1', user_agent: 'other-tab'
    )
    get edit_user_path(@user)
    assert_template 'users/edit'
    name  = 'Foo Bar'
    email = 'foo@bar.com'
    VCR.use_cassette('successful_edit_-_password') do
      patch user_path(@user), params: {
        user: {
          name:  name,
                email: email,
                password:              'Agoodp@$$word',
                password_confirmation: 'Agoodp@$$word'
        }
      }
    end
    assert_not flash.empty?
    assert_redirected_to @user
    @user.reload
    assert_equal name,  @user.name
    assert_equal email, @user.email

    # A self-service password change revokes every OTHER session for this
    # user (design doc section 3/10), but relogin: true means this browser
    # stays logged in as itself, with a genuinely new LoginSession (not the
    # one the original login created).
    assert_not LoginSession.exists?(other_login_session.id)
    assert user_logged_in?
    assert_equal @user.id, logged_in_user_id
    assert_not_equal original_login_session_id, session[:login_session_id]
    assert_not LoginSession.exists?(
      session_id_digest: LoginSession.digest(original_login_session_id)
    )
  end

  test 'editing an unrelated field does not revoke other sessions' do
    log_in_as(@user)
    other_login_session = LoginSession.create_for(
      @user, ip_address: '127.0.0.1', user_agent: 'other-tab'
    )
    VCR.use_cassette('successful_edit_-_name_email') do
      patch user_path(@user), params: {
        user: {
          name: 'Foo Bar', email: 'foo@bar.com',
          password: '', password_confirmation: ''
        }
      }
    end
    assert_redirected_to @user
    # No password change happened, so the saved_change_to_password_digest?
    # guard must leave every session, including the other tab's, alone.
    assert LoginSession.exists?(other_login_session.id)
    assert user_logged_in?
  end
end
