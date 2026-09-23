# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'application_system_test_case'
require 'minitest/mock'

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

  # Guards RetryChromeStaleNode (see application_system_test_case.rb):
  # without it, chromedriver's misreported stale-node race made random
  # system tests flap. Asks Capybara's retry decision directly, so it
  # needs no browser and doesn't depend on winning a race.
  test 'chromedriver stale-node errors are retried, others are not' do
    # A node whose driver has Capybara's real Selenium retry list, which
    # doesn't include UnknownError (that's the upstream bug).
    selenium = Capybara::Selenium::Driver.allocate
    node = Capybara::Node::Base.allocate
    node.define_singleton_method(:driver) { selenium }
    unknown = Selenium::WebDriver::Error::UnknownError
    assert_not_includes selenium.invalid_element_errors, unknown
    stale = unknown.new(
      'unknown error: unhandled inspector error: {"code":-32000,' \
      '"message":"Node with given id does not belong to the document"}'
    )
    assert node.send(:catch_error?, stale)
    assert_not node.send(:catch_error?, unknown.new('something else'))
    # A caller's explicit error list is respected.
    assert_not node.send(:catch_error?, stale, [ArgumentError])
  end

  # The snap wrappers must be chosen exactly when snap's launcher can't
  # run (no_new_privs) and would otherwise be used; never in a normal
  # environment, so normal runs use the normal chromedriver.
  test 'snap wrappers are chosen only when snap launchers cannot run' do
    tc = SystemTestChromedriver
    launcher = SystemTestChromedriver::SNAP_CHROMEDRIVERS.first
    { # [no_new_privs, snap installed, SE_CHROMEDRIVER] => result
      [false, true, nil] => false, [false, true, launcher] => false,
      [true, false, nil] => false, [true, true, nil] => true,
      [true, true, launcher] => true, [true, true, '/usr/bin/x'] => false
    }.each do |(nnp, installed, explicit), expected|
      tc.stub(:no_new_privs?, nnp) do
        tc.stub(:snap_installed?, installed) do
          assert_equal expected, tc.use_snap_wrapper?(explicit),
                       "nnp=#{nnp} installed=#{installed} explicit=#{explicit}"
        end
      end
    end
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
