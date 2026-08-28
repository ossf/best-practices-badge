# frozen_string_literal: true

# Copyright the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'
require 'capybara/rails'
require 'capybara/minitest'
require 'selenium/webdriver'

# webdrivers are now managed by selenium
# Set up a test environment to run client-side JavaScript.
# Setup Capybara -> selenium -> webdriver -> headless chrome/chromium. See:
# https://robots.thoughtbot.com/headless-feature-specs-with-chrome

# Register "headless_chrome" driver - use it via Selenium.
# The configuration approach documented here isn't actually headless:
# https://robots.thoughtbot.com/headless-feature-specs-with-chrome
# So we instead use the approach documented in:
# https://github.com/teamcapybara/capybara/blob/master/spec/
# selenium_spec_chrome.rb#L6
Capybara.register_driver :headless_chrome do |app|
  browser_options = Selenium::WebDriver::Chrome::Options.new
  browser_options.binary = ENV.fetch('GOOGLE_CHROME_SHIM', nil) if ENV['CI']
  browser_options.args << '--headless'
  browser_options.args << '--disable-gpu' if Gem.win_platform?
  driver = Capybara::Selenium::Driver.new(
    app, browser: :chrome, options: browser_options
  )
  driver.browser.download_path = Capybara.save_path
  driver
end

# Register "chrome" driver - use it via Selenium.
Capybara.register_driver :chrome do |app|
  Capybara::Selenium::Driver.new(app, browser: :chrome)
end

driver = ENV['DRIVER'].try(:to_sym)
Capybara.javascript_driver = driver.present? ? driver : :headless_chrome
Capybara.default_driver = driver.present? ? driver : :headless_chrome

# Headroom for the polling/wait helpers (ensure_choice, wait_for_jquery,
# wait_for_url) whose Timeout budgets derive from this. Under load (a full
# system-test batch contending for CPU and the browser), 5s was too tight and
# they would all time out together; 10s costs nothing on the happy path since
# waits return as soon as their condition is met.
Capybara.default_max_wait_time = 10
Capybara.server_port = 31_337

# By default newer versions of Capybara have the annoying habit of
# sending this in the middle of a test:
# > Capybara starting Puma...
# > * Version 3.12.2 , codename: Llamas in Pajamas
# > * Min threads: 0, max threads: 4
# > * Listening on tcp://127.0.0.1:31337
# This makes it hard to see the test status, so quiet it per:
# Capybara.server = :puma, { Silent: true }
# NOTE: This forces Capybara's server to be Puma; if the production server
# is something else, you might want to change this. For more info, see:
# https://github.com/rails/rails/issues/28109
# https://github.com/rspec/rspec-rails/issues/1897
Capybara.server = :puma, { Silent: true }

# Must run headless and disable sandbox, see:
# https://medium.com/@john200Ok/running-rails-6-system-tests-using-chrome-headless-and-selenium-on-gitlab-ci-9b4de5cafcd0

# When SELENIUM_REMOTE_URL is set, Chrome is not installed here: it runs
# in a separate container (selenium/standalone-chrome) and we drive it
# over the network. Unset, everything below behaves exactly as before,
# so local development is unaffected.
#
# This must be passed through driven_by's "options:", not through
# Capybara.register_driver. ActionDispatch::SystemTesting::Driver
# registers a driver of its own and makes it current, so a
# register_driver block of ours is not what system tests run.
#
# "browser: :remote" is Rails' supported spelling, and it does more than
# select a transport: Driver#initialize skips Browser#preload for it,
# and preload is what runs Selenium Manager to find a *local*
# chromedriver. Without it, a machine with no browser would still try to
# download one. See docs/build-environment-staleness.md.
SELENIUM_REMOTE_URL = ENV.fetch('SELENIUM_REMOTE_URL', nil)
SELENIUM_OPTIONS =
  if SELENIUM_REMOTE_URL
    { browser: :remote, url: SELENIUM_REMOTE_URL }
  else
    {}
  end

# Selenium Manager (selenium-webdriver's own chromedriver resolver) ships
# as an x86_64-only binary and cannot run at all on arm64 Linux. Left
# alone it fails deep inside Selenium with "Syntax error: '(' unexpected"
# instead of an explanation, ten seconds into the first test, which reads
# as an unrelated failure. Rather than rely on a developer having set
# SE_CHROMEDRIVER themselves (easy to forget, and it fails exactly this
# way if forgotten), auto-detect the one setup docs/INSTALL.md
# recommends - the Chromium snap - and fail fast with a clear message if
# that is not present either. Skipped for SELENIUM_REMOTE_URL, which
# never invokes Selenium Manager locally in the first place (see above).
if SELENIUM_REMOTE_URL.nil? && ENV['SE_CHROMEDRIVER'].nil? &&
   RUBY_PLATFORM == 'aarch64-linux'
  snap_chromedriver = '/snap/bin/chromium.chromedriver'
  unless File.executable?(snap_chromedriver)
    raise StandardError, <<~MESSAGE
      arm64 Linux detected, but no chromedriver is configured, and the
      Chromium snap (the setup docs/INSTALL.md recommends) isn't
      installed either.

      Selenium Manager cannot resolve one itself here - it is x86_64-only
      - so system tests cannot run without one. See docs/INSTALL.md for
      how to install the Chromium snap, or set SE_CHROMEDRIVER yourself
      if you already have a chromedriver elsewhere.
    MESSAGE
  end

  ENV['SE_CHROMEDRIVER'] = snap_chromedriver
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # DRIVER and SELENIUM_REMOTE_URL are independent, and all four
  # combinations work. DRIVER picks the browser: unset means
  # :headless_chrome, and DRIVER=chrome runs headed so you can watch,
  # which is the usual way to debug a failing system test. Rails adds
  # --headless only for :headless_chrome, so DRIVER=chrome really is
  # headed, in a container as well as here. See docs/testing.md.
  driver = ENV['DRIVER'].try(:to_sym)
  driven_by :selenium, using: driver || :headless_chrome,
            screen_size: [1400, 1400], options: SELENIUM_OPTIONS do |option|
    option.add_argument('no-sandbox')
    # Use /tmp instead of /dev/shm for Chrome's shared memory. /dev/shm is
    # often capped at 64MB in containers/CI; when it fills under load the
    # renderer process crashes, killing the browser session and cascading into
    # spurious errors in later tests. This flag is the standard fix.
    option.add_argument('disable-dev-shm-usage')
    # On arm64 Linux, Selenium Manager's bundled resolver binary is
    # x86_64-only and cannot run at all, and Google publishes no reliable
    # arm64 chromedriver on the Stable channel. CHROME_BINARY lets a
    # matched browser (e.g. the Chromium snap) be pointed at directly,
    # skipping that resolution. See docs/INSTALL.md.
    chrome_binary = ENV.fetch('CHROME_BINARY', nil)
    option.binary = chrome_binary if chrome_binary
  end
end
