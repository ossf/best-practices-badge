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

# Chromedriver selection and sandbox handling for local (non-remote) runs.
module SystemTestChromedriver
  # Where the Chromium snap's chromedriver launcher lives: Debian and
  # Ubuntu mount snaps at /snap, Fedora and Arch at /var/lib/snapd/snap.
  SNAP_CHROMEDRIVERS = %w[
    /snap/bin/chromium.chromedriver
    /var/lib/snapd/snap/bin/chromium.chromedriver
  ].freeze

  module_function

  # @return [String, nil] the first executable chromedriver found: one on
  #   PATH (the normal way to find a program), else the Chromium snap's,
  #   since /snap/bin often isn't on PATH
  def find
    dirs = ENV.fetch('PATH', '').split(File::PATH_SEPARATOR)
    on_path = dirs.map { |dir| File.join(dir, 'chromedriver') }
    (on_path + SNAP_CHROMEDRIVERS).find do |path|
      File.file?(path) && File.executable?(path)
    end
  end

  # @return [Boolean] true if the Chromium snap's chromedriver launcher
  #   exists (it's a symlink to the snap binary; this follows it)
  def snap_installed?
    SNAP_CHROMEDRIVERS.any? { |path| File.exist?(path) }
  end

  # @param explicit [String, nil] the SE_CHROMEDRIVER setting, if any
  # @return [Boolean] true if we must run the Chromium snap's binaries
  #   directly: under no_new_privs, with the snap installed, and unless an
  #   explicit SE_CHROMEDRIVER names something other than its launcher
  def use_snap_wrapper?(explicit)
    no_new_privs? && snap_installed? &&
      (explicit.nil? || SNAP_CHROMEDRIVERS.include?(explicit))
  end

  # @return [Boolean] true if this process has no_new_privs set, so the
  #   kernel ignores setuid bits and file capabilities on exec. Landlock
  #   sandboxes such as nono require it.
  def no_new_privs?
    File.read('/proc/self/status').match?(/^NoNewPrivs:\s*1$/)
  rescue SystemCallError
    false
  end
end

if SELENIUM_REMOTE_URL.nil?
  explicit = ENV.fetch('SE_CHROMEDRIVER', nil)
  # Snap's launcher needs snap-confine's file capabilities, which the
  # kernel withholds under no_new_privs (e.g., in a nono sandbox), so it
  # can't start at all there, and Selenium would later report only
  # "connection refused". In that situation, if the Chromium snap is
  # installed, run its binaries directly instead, without even looking at
  # PATH: a chromedriver there may be a shim that runs the snap anyway.
  # An explicit SE_CHROMEDRIVER wins unless it's itself a snap launcher.
  if SystemTestChromedriver.use_snap_wrapper?(explicit)
    warn 'Note: no_new_privs is set (e.g., in a nono sandbox), so snap\'s ' \
         'launcher cannot run; using script/snap-chromedriver and ' \
         'script/snap-chromium to run the Chromium snap directly.'
    wrapper = Rails.root.join('script/snap-chromedriver').to_s
    ENV['SE_CHROMEDRIVER'] = wrapper
    ENV['CHROME_BINARY'] ||= Rails.root.join('script/snap-chromium').to_s
    # Fail fast: Selenium hides chromedriver's stderr, so a wrapper failure
    # (e.g., a sandbox that can't read /snap) would otherwise surface only
    # as "connection refused", minutes later. This is a direct exec, not
    # through snap, so it takes well under a second.
    unless system(wrapper, '--version', out: File::NULL)
      raise StandardError, 'script/snap-chromedriver failed; see above.'
    end
  # Selenium Manager (selenium-webdriver's own chromedriver resolver)
  # ships as an x86_64-only binary and cannot run at all on arm64 Linux.
  # Left alone it fails deep inside Selenium with "Syntax error: '('
  # unexpected" instead of an explanation, ten seconds into the first
  # test, which reads as an unrelated failure. So on arm64 Linux, find a
  # chromedriver ourselves, and fail fast with a clear message if there's
  # none. Skipped for SELENIUM_REMOTE_URL, which never invokes Selenium
  # Manager locally in the first place (see above).
  elsif explicit.nil? && RUBY_PLATFORM == 'aarch64-linux'
    found = SystemTestChromedriver.find
    unless found
      raise StandardError, <<~MESSAGE
        arm64 Linux detected, but no chromedriver is configured, and none
        was found (neither on PATH nor the Chromium snap's). If you're
        in a sandbox, it may be unable to read them.

        Selenium Manager cannot resolve one itself here - it is x86_64-only
        - so system tests cannot run without one. See docs/INSTALL.md, or
        set SE_CHROMEDRIVER yourself.
      MESSAGE
    end

    ENV['SE_CHROMEDRIVER'] = found
  end
end

# Chromedriver sometimes reports a node that a page load or DOM update has
# just replaced as "unknown error: unhandled inspector error: ... Node
# with given id does not belong to the document" (or "No node with given
# id found"), instead of as a stale element. Capybara's synchronize
# retries stale element errors, waiting for the page to settle, but not
# unknown errors, so this race fails a random test outright: the test
# flaps. So we extend only Capybara's retry decision, and only when the
# caller didn't pass its own error list: the error itself is unchanged,
# and if the page never settles, it still fails with the original error.
# Delete this once https://github.com/teamcapybara/capybara/issues/2850
# is fixed.
module RetryChromeStaleNode
  STALE_NODE = Regexp.union(
    'Node with given id does not belong to the document',
    'No node with given id found'
  )

  protected

  def catch_error?(error, errors = nil)
    super || (errors.nil? &&
              error.is_a?(Selenium::WebDriver::Error::UnknownError) &&
              STALE_NODE.match?(error.message))
  end
end
Capybara::Node::Base.prepend(RetryChromeStaleNode)

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
