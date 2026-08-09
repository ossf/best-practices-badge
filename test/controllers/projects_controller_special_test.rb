# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

class ProjectsControllerSpecialTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:one)
  end

  test 'should fail to edit due to old session without remember token' do
    # Log in without remember_me
    log_in_as(@project.user, remember_me: '0')
    # Time travel past session timeout (48 hours + 1 second)
    travel 49.hours do
      get "/en/projects/#{@project.id}/passing/edit"
      assert_response :found
      # After session timeout without remember token, user is logged out
      # and can_edit_else_redirect redirects to login with return_to param
      assert_match %r{/en/login\?return_to=}, response.location
    end
  end

  test 'should stay logged in with old session if remember token valid' do
    # Log in WITH remember_me (the default)
    log_in_as(@project.user, remember_me: '1')
    # Time travel past session timeout (48 hours + 1 second)
    travel 49.hours do
      get "/en/projects/#{@project.id}/passing/edit"
      # Remember token should auto-login the user despite session timeout
      # so edit page should load successfully
      assert_response :success
      # Verify user is still logged in (session was recreated by remember token)
      assert_not_nil session[:user_id]
      assert_equal @project.user.id, session[:user_id]
    end
  end
end
