# frozen_string_literal: true

# Copyright 2015-2020, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'application_system_test_case'

class GithubLoginTest < ApplicationSystemTestCase
  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:github] = nil
  end

  # rubocop:disable Metrics/BlockLength
  test 'Can sign up with GitHub' do
    configure_omniauth_mock unless ENV['GITHUB_PASSWORD']

    VCR.use_cassette('github_login', allow_playback_repeats: true) do
      visit '/en'
      assert_text 'OpenSSF Best Practices Badge Program'
      click_on 'Login'
      assert_equal login_path(locale: :en), current_path
      assert_text 'Log in with GitHub'
      num = ActionMailer::Base.deliveries.size
      click_link 'Log in with GitHub'

      # When re-recording cassetes you must use DRIVER=chrome
      # Github has an anti bot mechanism that requires real mouse movement
      # to authorize an application.
      unless has_content? 'Logged in'
        fill_in 'login', with: 'bestpracticestest'
        fill_in 'password', with: ENV.fetch('GITHUB_PASSWORD', nil)
        click_on 'Sign in'
      end
      # We don't assume not authorized so look for whether we are on the
      # authorization page and click authorize if we are
      if page.has_content?('Test BadgeApp (not for production use)')
        click_on 'Authorize dankohn'
      end
      assert_text 'Logged in!'
      assert_equal '/en', current_path
      assert_equal num + 1, ActionMailer::Base.deliveries.size
      # Check a user can edit a project they can edit on Github
      # This particular check requires GitHub interaction so we do it here
      # We use a "find" to disambiguate requests
      find('#projects_page').click
      assert_text 'Justified perfect project'
      click_on 'Justified perfect project'
      assert_text 'Edit'
      # Check a user cannot edit a Github project they CAN'T push to.
      find('#projects_page').click
      click_on 'Unjustified perfect project'
      assert_not has_content? 'Edit'
    end
    if ENV['GITHUB_PASSWORD'] # revoke OAuth authorization
      # We used to automate this, but GitHub changes too often, and
      # we don't do this often. So tell the user how to do it, since the
      # user can figure out how to deal with UI changes better.
      puts "\n\nDon't forget to REVOKE access to the test app on GitHub"
      puts 'Log in to GitHub as bestpracticestest. Then go to'
      puts 'https://github.com/settings/applications.'
      puts 'Revoke the app "Test BadgeApp (not for production use)".\n\n'
    end
  end
end
