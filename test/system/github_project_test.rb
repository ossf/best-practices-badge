# frozen_string_literal: true

# Copyright 2015-2020, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'application_system_test_case'

class GithubProjectTest < ApplicationSystemTestCase
  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:github] = nil
  end

  # rubocop:disable Metrics/BlockLength
  test 'Can Create new project via GitHub login' do
    configure_omniauth_mock('github_project') unless ENV['GITHUB_PASSWORD']

    VCR.use_cassette('github_project', allow_playback_repeats: true) do
      visit '/en'
      assert_text 'OpenSSF Best Practices Badge Program'
      click_on 'Get Your Badge Now!'
      assert_equal new_project_path(locale: :en), current_path
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
      if ENV['GITHUB_PASSWORD'] # for re-recording cassettes
        # We don't assume not authorized so look for whether we are on the
        # authorization page and click authorize if we are
        if page.has_content?('Test BadgeApp (not for production use)')
          puts 'Please delete github_login.yml cassette and rerun' \
               ' github_login_test.rb with DRIVER=chrome to authorize' \
               ' the test environment app'
        end
      end
      assert_equal num + 1, ActionMailer::Base.deliveries.size
      assert find(
        "option[value='https://github.com/bestpracticestest/best-practices-badge']"
      )
      assert_selector(
        "option[value='https://github.com/andrewfader/test-repo-shared-2']"
      )
      # Should not see repos that already have existing badge
      assert has_no_selector?(
        "option[value='https://github.com/bestpracticestest/test-repo']"
      )
      # assert has_no_selector?(
      # "option[value='https://github.com/andrewfader/test-repo-shared']"
      # )
      select 'bestpracticestest/best-practices-badge', from: 'github_repo'
      click_on 'Submit Project'
      assert_text 'Thanks for adding the Project! Please fill out ' \
                  'the rest of the information to get the Badge.'
      assert_equal num + 2, ActionMailer::Base.deliveries.size
      click_on 'Account'
      assert_text 'Profile'
      click_on 'Profile'
      assert_text 'Best Practices Badge'
      click_on 'Account'
      # Regression test, make sure GitHub users can logout
      assert_text 'Logout'
      click_on 'Logout'
      # Wait for logout redirect to complete
      assert_text 'Logged out!'
      assert_equal '/en', current_path
    end
    if ENV['GITHUB_PASSWORD'] # revoke OAuth authorization
      # We used to automate this, but GitHub changes too often, and
      # we don't do this often. So tell the user how to do it, since the
      # user can figure out how to deal with UI changes better.
      puts "\n\nDon't forget to REVOKE access to the test app on GitHub"
      puts 'Log in to GitHub as ciitest. Then go to'
      puts 'https://github.com/settings/applications.'
      puts 'Revoke the app "Test BadgeApp (not for production use)".\n\n'
    end
  end
  # rubocop:enable Metrics/BlockLength
end
