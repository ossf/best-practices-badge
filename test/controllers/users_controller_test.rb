# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'
require 'minitest/mock'

# rubocop:disable Metrics/ClassLength
class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:test_user_melissa)
    @other_user = users(:test_user_mark)
    @admin = users(:admin_user)
  end

  test 'should get index' do
    log_in_as(@admin)
    get '/en/users'
    assert_response :success
    assert_includes @response.body, 'Users'
  end

  test 'should get new' do
    get '/en/users/new'
    assert_response :success
    assert_includes @response.body, 'Sign up'
    assert_includes @response.body,
                    'sign up here instead (this creates a custom account'
  end

  test 'should show additional rights on user page when present' do
    project = projects(:one)

    # Ensure the additional rights aren't shown when not there.
    get "/en/users/#{@other_user.id}"
    assert_response :success
    assert_not_includes @response.body, project.name
    assert_not_includes @response.body,
                        I18n.t('users.show.projects_additional_rights')

    # Create additional rights during test, not as a fixture.
    # The fixture would require correct references to *other* fixture ids.
    new_right = AdditionalRight.new(
      user_id: @other_user.id,
      project_id: project.id
    )
    new_right.save!

    # Now that there are additional rights, we should see them
    get "/en/users/#{@other_user.id}"
    assert_response :success
    assert_includes @response.body, project.name
    assert_includes @response.body,
                    I18n.t('users.show.projects_additional_rights')
  end

  test 'Admin can search by name, case-insensitive' do
    log_in_as(@admin)
    get '/en/users?search_names=test'
    assert_response :success
    assert_includes @response.body, 'French Test'
    assert_not_includes @response.body, 'Mark Watney'
  end

  test 'Admin can search by email, case-insensitive' do
    log_in_as(@admin)
    # Stored email address is 'CaseSensitive@example.org'
    get '/en/users?search_emails=casesensitive@example.org'
    assert_response :success
    assert_includes @response.body, 'Case Sensitive'
    assert_not_includes @response.body, 'French Test'
    assert_not_includes @response.body, 'Mark Watney'
  end

  test 'Admin can search by name ORed with email, case-insensitive' do
    log_in_as(@admin)
    # Stored email address is 'CaseSensitive@example.org'
    get '/en/users?search_names=Test&search_emails=github-user@example.com'
    assert_response :success
    assert_includes @response.body, 'French Test'
    assert_includes @response.body, 'GitHub The User'
    assert_not_includes @response.body, 'Mark Watney'
  end

  test 'Admin can search with multiple names and emails' do
    log_in_as(@admin)
    # Test with multiple names and emails (one per line)
    # This should return: French Test (name match), Mark Watney (name match),
    # GitHub The User (email match), and test_user_melissa (email match)
    # We use CGI.escape to properly encode newlines in the URL
    search_names = "Test\nMark\nNonexistent"
    search_emails = "github-user@example.com\nmelissa@example.com\nnonexistent@example.com"
    get "/en/users?search_names=#{CGI.escape(search_names)}&" \
        "search_emails=#{CGI.escape(search_emails)}"
    assert_response :success
    # Verify all matching users are returned
    assert_includes @response.body, 'French Test'
    assert_includes @response.body, 'Mark Watney'
    assert_includes @response.body, 'GitHub The User'
    assert_includes @response.body, @user.name # Melissa via email match
    # Verify at least one user is NOT matched (prevents bug returning all users)
    assert_not_includes @response.body, 'Case Sensitive'
  end

  test 'Non-admin will be UNABLE to search by name' do
    log_in_as(@other_user)
    get '/en/users?search_names=test'
    assert_response :success
    # The search is ignored, so we'll just see unrelated entries
    assert_includes @response.body, 'Mark Watney'
  end

  test 'Non-admin will be UNABLE search by email, case-insensitive' do
    log_in_as(@other_user)
    # Stored email address is 'CaseSensitive@example.org'
    get '/en/users?search_emails=casesensitive@example.org'
    assert_response :success
    # The search is ignored, so we'll just see unrelated entries
    assert_includes @response.body, 'Mark Watney'
  end

  test 'indicate admin is admin to admin' do
    log_in_as(@admin)
    get "/en/users/#{@admin.id}"
    assert_response :success
    assert I18n.t('users.show.is_admin').present?
    assert_includes @response.body, I18n.t('users.show.is_admin')
  end

  test 'do NOT indicate non-admin is admin to admin' do
    # This is purely a functional check - ensure we don't give false info
    log_in_as(@admin)
    get "/en/users/#{@user.id}"
    assert_response :success
    assert_not_includes @response.body, I18n.t('users.show.is_admin')
  end

  test 'do NOT indicate admin is admin to non-admin' do
    log_in_as(@user, password: 'password1')
    get "/en/users/#{@user.id}"
    assert_response :success
    assert_not_includes @response.body, I18n.t('users.show.is_admin')
  end

  test 'do NOT indicate admin is admin if not logged in' do
    # No log_in_as
    get "/en/users/#{@user.id}"
    assert_response :success
    assert_not_includes @response.body, I18n.t('users.show.is_admin')
  end

  test 'should NOT show email address when not logged in' do
    get "/en/users/#{@user.id}"
    assert_response :success
    assert_not_includes @response.body, '%40example.com'
    assert_not_includes @response.body, '@example.com'
    # We also want to make sure we don't cache this
    assert_equal 'noindex', @response.headers['X-Robots-Tag']
    # You might think we should just use no-store without private, but
    # some systems (including Fastly) ignore no-store, so both are needed.
    assert_equal 'private, no-store', @response.headers['Cache-Control']
  end

  test 'JSON provides reasonable results when not logged in, but NOT email' do
    get "/en/users/#{@user.id}.json"
    assert_response :success
    assert_equal '{', @response.body.first
    assert_not_includes @response.body, 'example.com' # Must NOT include email
    json_response = JSON.parse(@response.body)
    assert_equal @user.id, json_response['id']
    assert_not_includes json_response, 'email'
  end

  test 'should NOT show email address when logged in as another user' do
    log_in_as(@other_user)
    get "/en/users/#{@user.id}"
    assert_response :success
    assert_not_includes @response.body, '%40example.com'
    assert_not_includes @response.body, '@example.com'
    assert_equal 'private, no-store', @response.headers['Cache-Control']
  end

  test 'JSON should NOT show email address when logged in as another user' do
    log_in_as(@other_user)
    get "/en/users/#{@user.id}.json"
    assert_response :success
    assert_not_includes @response.body, 'example.com'
    assert_equal 'private, no-store', @response.headers['Cache-Control']
    json_response = JSON.parse(@response.body)
    assert_equal @user.id, json_response['id']
    assert_not_includes json_response, 'email'
  end

  # This is a change, due to the EU General Data Protection Regulation (GDPR)
  # requirement to support "right of access" (users must be able to see
  # the personal data we record about them).
  # We originally didn't do this, since obviously users already know their
  # email addresses, and we wanted to reduce the risk of leaks of this
  # data. That said, we aren't trying to *hide* information about users from
  # themselves, and showing this information appears to be the expectation.
  test 'should show email address of self when logged in as self (GDPR)' do
    log_in_as(@user, password: 'password1')
    get "/en/users/#{@user.id}"
    assert_response :success
    assert_includes @response.body, 'mailto:melissa%40example.com'
    assert_equal 'private, no-store', @response.headers['Cache-Control']
  end

  test 'should show email address when logged in as admin' do
    log_in_as(@admin)
    get "/en/users/#{@user.id}"
    assert_response :success
    assert_includes @response.body, 'mailto:melissa%40example.com'
    assert_equal 'private, no-store', @response.headers['Cache-Control']
  end

  test 'JSON should show email address when logged in as admin' do
    log_in_as(@admin)
    # We can also use ".json" in the URL; we vary it here so we also test
    # that both URL formats work.
    get "/en/users/#{@user.id}?format=json"
    assert_response :success
    assert_includes @response.body, 'melissa@example.com'
    assert_equal 'private, no-store', @response.headers['Cache-Control']
  end

  test 'should redirect edit when not logged in' do
    get "/en/users/#{@user.id}/edit"
    assert_not flash.empty?
    assert_redirected_to login_url
  end

  test 'can create local user' do
    # NOTE: We don't rate limit *creating* a local user, but we have
    # additional requirements for actual *activation* of local user accounts.
    VCR.use_cassette('can_create_local_user') do
      # This will produce a "create" call on the controller
      post '/en/users', params: {
        user: { name: 'Not here', email: 'nonsense@example.org' }
      }
    end
    assert_response :found
    assert_redirected_to root_url
    @new_user = User.find_by(email: 'nonsense@example.org')
    assert_not_nil @new_user
    assert 'Not here', @new_user.name
  end

  # TODO: Also accept post '/en/users/' - the router should be more flexible.

  test 'cannot create local user if login disabled' do
    # NOTE: This test is NOT thread-safe, it manipulates a global variable
    deny_login_old = Rails.application.config.deny_login
    Rails.application.config.deny_login = true
    begin
      VCR.use_cassette('cannot_create_local_user_if_login_disabled') do
        # This will produce a "create" call on the controller
        post '/en/users', params: {
          user: { name: 'Not here', email: 'nonsense@example.org' }, locale: :en
        }
      end
      assert '403', response.code
    ensure
      Rails.application.config.deny_login = deny_login_old
    end
  end

  test 'should redirect update when not logged in' do
    # This becomes an 'update' on the users controller
    patch "/en/users/#{@user.id}", params: {
      user: { name: @user.name, email: @user.email }
    }
    assert_redirected_to login_url
  end

  test 'should redirect edit when logged in as wrong user' do
    log_in_as(@other_user)
    get "/en/users/#{@user.id}/edit"
    assert_redirected_to root_url
    follow_redirect!
    assert_includes @response.body, 'Sorry, you are not allowed to do that.'
    my_assert_select '.alert-danger', 'Sorry, you are not allowed to do that.'
  end

  test 'should redirect update when logged in as wrong user' do
    log_in_as(@other_user)
    patch "/en/users/#{@user.id}", params: {
      user: { name: @user.name, email: @user.email }
    }
    assert_redirected_to root_url
    follow_redirect!
    assert_includes @response.body, 'Sorry, you are not allowed to do that.'
    my_assert_select '.alert-danger', 'Sorry, you are not allowed to do that.'
  end

  test 'should update user when logged in as admin' do
    new_name = @user.name + '_updated'
    log_in_as(@admin)
    VCR.use_cassette('should_update_user_when_logged_in_as_admin') do
      patch "/en/users/#{@user.id}", params: { user: { name: new_name } }
    end
    follow_redirect!
    my_assert_select '.alert-success', 'Profile updated'
    @user.reload
    assert_equal @user.name, new_name
  end

  test 'should be able to change locale' do
    log_in_as(@user, password: 'password1')
    VCR.use_cassette('should_be_able_to_change_locale') do
      patch "/en/users/#{@user.id}", params: {
        user: { preferred_locale: 'fr' }
      }
    end
    # The redirected URL has form "/fr/users/ID", not "?id=...".
    assert_redirected_to users_path(locale: 'fr') + "/#{@user.id}"
    follow_redirect!
    my_assert_select '.alert-success', 'Profil mis à jour'
    # Check that the database has been properly updated:
    @user.reload
    assert_equal 'fr', @user.preferred_locale
  end

  test 'should redirect destroy when not logged in' do
    assert_no_difference 'User.count' do
      delete "/en/users/#{@user.id}"
    end
    assert_redirected_to login_url
  end

  test 'should redirect destroy when logged in as wrong non-admin user' do
    log_in_as(@other_user)
    assert_no_difference 'User.count' do
      delete "/en/users/#{@user.id}"
    end
    assert_redirected_to root_url
  end

  test 'admin should be able to destroy a user without projects' do
    log_in_as(@admin)
    assert_difference('User.count', -1) do
      delete "/en/users/#{@other_user.id}"
    end
    assert_redirected_to root_url
  end

  test 'should be able to destroy self without projects (GDPR)' do
    # EU General Data Protection Regulation (GDPR) requires users be able to
    # erase information about themselves.
    log_in_as(@other_user)
    assert session.key?('user_id') # Current session has a user_id
    assert @other_user.id, session['user_id']
    assert session.key?('session_id') # Current session has a user_id
    old_session_id = session['session_id']
    assert_difference('User.count', -1) do
      delete "/en/users/#{@other_user.id}"
    end
    assert_not session.key?('user_id')
    # New session has been initiated
    assert_not_equal old_session_id, session['session_id']
    assert_redirected_to root_url
    get root_url
    my_assert_select '.alert-success', 'User deleted.'
    assert_not session.key?('user_id')
    # TODO: The session key is restored here. It won't matter,
    # since it lacks a user_id, but it's weird. Should fix in the long term.
    # refute session.key?('session_id')
  end

  test 'should not be able to destroy self if have projects' do
    log_in_as(@user, password: 'password1')
    assert_no_difference 'User.count' do
      delete "/en/users/#{@user.id}"
    end
    assert_response :found
    follow_redirect!
    assert_response :ok
    my_assert_select '.alert-danger', 'Cannot delete a user who owns projects.'
  end

  test 'admin should not be able to destroy user if have projects' do
    log_in_as(@admin)
    assert_no_difference 'User.count' do
      delete "/en/users/#{@user.id}"
    end
    assert_redirected_to user_path(id: @user.id)
    follow_redirect!
    my_assert_select '.alert-danger', 'Cannot delete a user who owns projects.'
  end

  test 'admin should be able to destroy self without projects' do
    log_in_as(@admin)
    assert_difference('User.count', -1) do
      delete "/en/users/#{@admin.id}"
    end
    assert_redirected_to root_url
    follow_redirect!
    my_assert_select '.alert-success', 'User deleted.'
  end

  test 'logged in user can change own notification_emails setting' do
    log_in_as(@user, password: 'password1')
    original_value = @user.notification_emails
    new_value = !original_value

    VCR.use_cassette('logged_in_user_can_change_own_notification_emails_setting') do
      patch "/en/users/#{@user.id}", params: {
        user: { notification_emails: new_value }
      }
    end

    assert_redirected_to user_path(@user)
    @user.reload
    assert_equal new_value, @user.notification_emails
  end

  test 'logged in user can see notification_emails field in edit form' do
    log_in_as(@user, password: 'password1')

    get "/en/users/#{@user.id}/edit"

    assert_response :success
    assert_includes @response.body, 'notification_emails'
    assert_includes @response.body, 'Email notifications'
  end

  test 'logged in user cannot change other user notification_emails setting' do
    log_in_as(@user, password: 'password1')
    original_value = @other_user.notification_emails
    new_value = !original_value

    patch "/en/users/#{@other_user.id}", params: {
      user: { notification_emails: new_value }
    }

    assert_redirected_to root_url
    @other_user.reload
    assert_equal original_value, @other_user.notification_emails
  end

  test 'logged in user cannot see other user edit form' do
    log_in_as(@user, password: 'password1')

    get "/en/users/#{@other_user.id}/edit"

    assert_redirected_to root_url
    follow_redirect!
    assert_includes @response.body, 'Sorry, you are not allowed to do that.'
  end

  test 'admin can change any user notification_emails setting' do
    log_in_as(@admin)
    original_value = @user.notification_emails
    new_value = !original_value

    VCR.use_cassette('admin_can_change_any_user_notification_emails_setting') do
      patch "/en/users/#{@user.id}", params: {
        user: { notification_emails: new_value }
      }
    end

    assert_redirected_to user_path(@user)
    @user.reload
    assert_equal new_value, @user.notification_emails
  end

  # Unit tests for search_users_by_lists
  test 'search_users_by_lists returns user IDs for valid names' do
    controller = UsersController.new
    controller.stub(:current_user, @admin) do
      result = controller.send(:search_users_by_lists, 'Test', nil)
      assert_nil result[:error]
      assert_not_empty result[:user_ids]
    end
  end

  test 'search_users_by_lists returns user IDs for valid emails' do
    controller = UsersController.new
    controller.stub(:current_user, @admin) do
      result = controller.send(:search_users_by_lists, nil, 'melissa@example.com')
      assert_nil result[:error]
      assert_equal 1, result[:user_ids].size
    end
  end

  test 'search_users_by_lists handles blank lines' do
    controller = UsersController.new
    controller.stub(:current_user, @admin) do
      result = controller.send(:search_users_by_lists, "Test\n\n  \nMark", nil)
      assert_nil result[:error]
      assert_not_empty result[:user_ids]
    end
  end

  test 'search_users_by_lists returns error for invalid UTF-8 in names' do
    invalid_utf8 = "\xFF\xFE"
    controller = UsersController.new
    controller.stub(:current_user, @admin) do
      result = controller.send(:search_users_by_lists, invalid_utf8, nil)
      assert_equal 'Invalid UTF-8 in name search', result[:error]
      assert_empty result[:user_ids]
    end
  end

  test 'search_users_by_lists returns error for invalid UTF-8 in emails' do
    invalid_utf8 = "\xFF\xFE"
    controller = UsersController.new
    controller.stub(:current_user, @admin) do
      result = controller.send(:search_users_by_lists, nil, invalid_utf8)
      assert_equal 'Invalid UTF-8 in email search', result[:error]
      assert_empty result[:user_ids]
    end
  end

  test 'search_users_by_lists returns error for invalid email format' do
    controller = UsersController.new
    controller.stub(:current_user, @admin) do
      result = controller.send(:search_users_by_lists, nil, 'not-an-email')
      assert_includes result[:error], 'Invalid email format'
      assert_empty result[:user_ids]
    end
  end

  test 'search_users_by_lists returns error when too many results from names' do
    controller = UsersController.new
    controller.stub(:current_user, @admin) do
      # Use a low limit to trigger too many results
      # "%" wildcard matches multiple users in our fixtures
      result = controller.send(:search_users_by_lists, '%', nil, 2)
      assert_includes result[:error], 'Too many results'
      assert_empty result[:user_ids]
    end
  end

  test 'search_users_by_lists returns error when too many results from emails' do
    emails = "melissa@example.com\nmark@example.com\ngithub-user@example.com"
    controller = UsersController.new
    controller.stub(:current_user, @admin) do
      result = controller.send(:search_users_by_lists, nil, emails, 2)
      assert_includes result[:error], 'Too many results'
      assert_empty result[:user_ids]
    end
  end

  test 'search_users_by_lists deduplicates results' do
    controller = UsersController.new
    controller.stub(:current_user, @admin) do
      result = controller.send(:search_users_by_lists, @user.name, @user.email)
      assert_nil result[:error]
      # Should only return one ID even though user matches both criteria
      assert_equal 1, result[:user_ids].size
    end
  end

  test 'search_users_by_lists returns empty array when no matches' do
    controller = UsersController.new
    controller.stub(:current_user, @admin) do
      result = controller.send(:search_users_by_lists,
                               'NonexistentUser12345',
                               'nonexistent@example.com')
      assert_nil result[:error]
      assert_empty result[:user_ids]
    end
  end

  test 'search_users_by_lists handles nil inputs' do
    controller = UsersController.new
    controller.stub(:current_user, @admin) do
      result = controller.send(:search_users_by_lists, nil, nil)
      assert_nil result[:error]
      assert_empty result[:user_ids]
    end
  end

  test 'search_email extracts email from Fullname <email> format' do
    controller = UsersController.new
    controller.stub(:current_user, @admin) do
      result = controller.send(:search_users_by_lists,
                               nil,
                               'Melissa User <melissa@example.com>')
      assert_nil result[:error]
      assert_equal 1, result[:user_ids].size
    end
  end

  test 'search_email handles malformed > without <' do
    controller = UsersController.new
    controller.stub(:current_user, @admin) do
      result = controller.send(:search_users_by_lists,
                               nil,
                               'melissa@example.com>')
      assert_nil result[:error]
      assert_equal 1, result[:user_ids].size
    end
  end

  test 'search_users_by_lists handles CRLF line endings' do
    controller = UsersController.new
    controller.stub(:current_user, @admin) do
      result = controller.send(:search_users_by_lists,
                               "Test\r\nMark\r\n",
                               "melissa@example.com\r\ngithub-user@example.com\r\n")
      assert_nil result[:error]
      assert_not_empty result[:user_ids]
    end
  end

  test 'search_users_by_lists returns empty for non-admin' do
    controller = UsersController.new
    controller.stub(:current_user, users(:test_user)) do
      result = controller.send(:search_users_by_lists, 'Test', nil)
      assert_nil result[:error]
      assert_empty result[:user_ids]
    end
  end

  test 'Admin search with no matches returns empty list, not all users' do
    log_in_as(@admin)
    get '/en/users?search_names=NonexistentUserXYZ123'
    assert_response :success
    # Should not include any actual users
    assert_not_includes @response.body, 'French Test'
    assert_not_includes @response.body, 'Mark Watney'
    assert_not_includes @response.body, @user.name
  end
end
# rubocop:enable Metrics/ClassLength
