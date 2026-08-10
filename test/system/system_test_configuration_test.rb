# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'application_system_test_case'

# Test that system test environment is configured correctly
class SystemTestConfigurationTest < ApplicationSystemTestCase
  test 'force_ssl is disabled in test environment' do
    # With force_ssl disabled, the test server uses HTTP not HTTPS
    # This prevents SSL redirect errors in system tests
    assert_equal false, Rails.configuration.force_ssl,
                 'force_ssl must be false to avoid HTTPS redirects in tests'
  end

  # Guards against a failure that really happened while developing this:
  # a change meant to drive a browser in a separate container silently
  # kept using the local one, and every test passed anyway. A green suite
  # is not evidence that the browser you think you configured is the
  # browser you got. So when SELENIUM_REMOTE_URL is set, insist on it.
  #
  # The two assertions check different things on purpose: the first that
  # we asked for the right thing, the second that asking worked, since
  # reading page.driver.browser forces a real session to be created.
  test 'SELENIUM_REMOTE_URL, when set, is the browser actually used' do
    # In CI the variable is not optional. Skipping here would be the same
    # silent pass in a different disguise: CI would drive whatever browser
    # happened to be lying around and report success.
    if ENV['CI'].present? && SELENIUM_REMOTE_URL.blank?
      flunk 'CI must set SELENIUM_REMOTE_URL; see .circleci/config.yml'
    end
    skip 'no remote browser configured' if SELENIUM_REMOTE_URL.blank?

    assert_equal SELENIUM_REMOTE_URL, page.driver.options[:url]
    assert_kind_of Selenium::WebDriver::Remote::Driver, page.driver.browser
  end

  test 'can visit home page without SSL errors' do
    # This test verifies system tests work without SSL errors
    visit '/'

    # Should redirect to locale path like /en/ or /fr/
    # Note that Ruby regex uses \A...\z, not ^...$, for full string matches
    assert_current_path %r{\A/[a-z]{2}(_[A-Z]{2})?/?\z}
    # More specifically, it should be English if unspecified
    assert_current_path %r{\A/en/?\z}
    # Should successfully load text without SSL errors
    assert_selector 'body', text: 'Best Practices'
  end
end
