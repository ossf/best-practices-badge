# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# NOTE: If you change SimpleCov configuration (used locally), you may also
# need to change codecov configuration (used on the website) as managed
# via codecov.yml.

# *MUST* load 'simplecov' FIRST, before any other code is run.
# See: https://github.com/colszowka/simplecov/issues/296
require 'simplecov'

# *MUST* state VERY EARLY that we're in the test environment.
ENV['RAILS_ENV'] ||= 'test'

# Configure SimpleCov formatting before we start it
if ENV['CI']
  require 'codecov'
  SimpleCov.formatters = [
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::Codecov
  ]
else
  SimpleCov.formatters = SimpleCov::Formatter::HTMLFormatter
end

# Start SimpleCov to track coverage
# NOTE: If you change SimpleCov configuration (used locally), you may also
# need to change codecov configuration (used on the website) as managed
# via codecov.yml.
SimpleCov.start 'rails' do
  # Ensure this is NOT set to false - we'll use its test merging capabilities
  use_merging true
  # Set a long merge_timeout (default is 10 mins) to ensure
  # system tests don't take so long that the regular test results "expire"
  merge_timeout 3600

  # Give each process a unique name so they don't overwrite each other
  # if running in parallel.
  command_name "job-#{ENV['TEST_ENV_NUMBER'] || 'manual'}"

  # If we are deferring, don't generate the HTML/Text formatter output yet
  if ENV['DEFER_COVERAGE']
    formatter SimpleCov::Formatter::SimpleFormatter # Minimal overhead
  end

  add_group 'Validators', 'app/validators'
  add_filter '/config/'
  add_filter '/lib/tasks'
  add_filter '/test/'
  add_filter '/vendor/'
  # Exclude baseline development scripts (not run in production)
  add_filter %r{^/lib/baseline_.*\.rb$}
end

# Some tests flap, producing false failures, so enable auto-retry
if ENV['CI']
  require 'minitest/retry'
  Minitest::Retry.use!
end

require 'minitest/reporters'
if ENV['CI'] || ENV['SLOW']
  Minitest::Reporters.use! [
    Minitest::Reporters::SpecReporter.new,
    Minitest::Reporters::MeanTimeReporter.new,
    Minitest::Reporters::HtmlReporter.new
  ]
else
  Minitest::Reporters.use! Minitest::Reporters::DefaultReporter.new
end

require File.expand_path('../config/environment', __dir__)
require 'rails/test_help'

# NOTE: Rails 8+ automatically raises ActiveModel::MissingAttributeError when
# code tries to access attributes that weren't included in SELECT queries.
# This built-in protection catches bugs where fields are added to views but
# not to controller field selection lists.

# We must specially allow web calls by test drivers, e.g.,
# GET https://chromedriver.storage.googleapis.com/LATEST_RELEASE_75.0.3770
# See: https://github.com/titusfortner/webdrivers/issues/109
driver_urls = [
  %r{https://chromedriver.storage.googleapis.com/LATEST_RELEASE_[0-9.]+}
]

require 'webmock/minitest'
# This would disable network connections; would interfere with vcr:
WebMock.disable_net_connect!(allow_localhost: true, allow: driver_urls)

# For more info on vcr, see https://github.com/vcr/vcr
# WARNING: Do *NOT* put the fixtures into test/fixtures (./fixtures is ok);
# Rails will try to automatically load them into models, resulting in
# confusing error messages.
require 'vcr'
# Shared rule that neutralizes git SHA-1 object ids which secret scanners
# mistake for CircleCI tokens; see the file for the full rationale.
require_relative 'test_helper_redaction'

VCR.configure do |config|
  config.ignore_localhost = true
  # We use Google Chrome for testing, which chattily updates.
  # Ignore those, as it's the test infrastructure, not the software under test
  config.ignore_hosts('127.0.0.1', 'localhost',
                      'googlechromelabs.github.io', 'storage.googleapis.com')
  config.cassette_library_dir = 'test/vcr_cassettes'
  config.hook_into :webmock
  # Sometimes we have the "same" query but with and without per_page=...
  # query values.  Record both variants by recording new_episodes:
  config.default_cassette_options = { record: :new_episodes }
  # Filter sensitive data from cassettes
  # These aren't really sensitive since they're not real, but tools have
  # trouble determining that and it's safer if we redact them no matter what.
  config.filter_sensitive_data('REDACTED') do |interaction|
    interaction.request.headers['Authorization']&.first
  end
  # Neutralize 40-hex strings (git SHAs, ETags, session HMACs) that secret
  # scanners mistake for CircleCI tokens (see VcrRedaction). Runs only when
  # recording new episodes, so freshly created/updated cassettes are scrubbed
  # automatically.
  config.before_record do |interaction|
    VcrRedaction.redact_message!(interaction.request)
    VcrRedaction.redact_message!(interaction.response)
  end
  # Default :match_requests_on => [:method, :uri]
  # You can also match on: scheme, port, method, host, path, query
  # You can create new matchers like this:
  # config.register_request_matcher :query_skip_changers do |r1, r2|
  #   URI(r1.uri).query == URI(r2.uri).query
  # end
  # config.match_on [:skip_changers]
  # Allow calls needed by test drivers
  # config.ignore_hosts(*driver_urls)
end

# The chromedriver occasionally calls out with its own API,
# which isn't part of the system under test. This can occasionally
# cause an error of this form:
# An HTTP request has been made that VCR does not know how to handle:
# GET https://chromedriver.storage.googleapis.com/LATEST_RELEASE_87.0.4280
# The following code resolves it, see:
# https://github.com/titusfortner/webdrivers/wiki/Using-with-VCR-or-WebMock
# https://github.com/titusfortner/webdrivers/issues/109

require 'uri'

# With activesupport gem
# driver_hosts =
# Webdrivers::Common.subclasses.map do |this_driver|
# URI(this_driver.base_url).host
# end

# VCR.configure { |config| config.ignore_hosts(*driver_hosts) }

# NOTE: We *could* speed up test execution by disabling PaperTrail
# except in cases where we check PaperTrail results. PaperTrail records all
# project creation and change events (enabling you to see older versions),
# so in some cases Papertrail slows tests slightly.  To do this, see:
# https://github.com/paper-trail-gem/paper_trail
# However, we have intentionally chosen to *not* do that.
# Where reasonable we have tried to keep the test environment
# the *same* as the production environment where it's reasonable to do so;
# every difference can hide a problem from our tests.
# The tests run fast enough as it is, and avoiding problems due to such
# differences is more important. At the least, we're making sure that
# PaperTrail doesn't cause a crash in the various tests, and that's worth
# checking.

module ActiveSupport
  # rubocop: disable Metrics/ClassLength
  class TestCase
    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical
    # order.
    ActiveRecord::Migration.maintain_test_schema!
    self.use_transactional_tests = true
    fixtures :all

    # Enable process-based parallelization for faster test execution.
    # System tests are run separately (see rake test:optimized) due to
    # fixed port binding in Capybara.
    parallelize(workers: :number_of_processors, with: :processes)

    # Configure SimpleCov to properly merge coverage from parallel workers.
    # Each worker needs a unique command_name to avoid overwriting results.
    parallelize_setup do |worker|
      SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}"
    end

    # Force SimpleCov to write results when each worker finishes.
    # Without this, coverage data may be lost when workers exit.
    parallelize_teardown do |_worker|
      SimpleCov.result
    end

    # Add more helper methods to be used by all tests here...

    # Reset locale to English before each test to prevent locale state leakage
    # between tests (e.g., when a test logs in as a user with French preference)
    def setup
      @original_locale = I18n.locale
      # rubocop:disable Rails/I18nLocaleAssignment
      I18n.locale = :en
      # rubocop:enable Rails/I18nLocaleAssignment
    end

    def teardown
      # rubocop:disable Rails/I18nLocaleAssignment
      I18n.locale = @original_locale
      # rubocop:enable Rails/I18nLocaleAssignment
    end

    def configure_omniauth_mock(cassette = 'github_login')
      OmniAuth.config.test_mode = true
      OmniAuth.config.add_mock(:github, omniauth_hash(cassette))
    end

    def contents(file_name)
      File.read "test/fixtures/files/#{file_name}"
    end

    # rubocop:disable Metrics/MethodLength
    def kill_sticky_headers
      # https://alisdair.mcdiarmid.org/kill-sticky-headers/
      script = <<-JAVASCRIPT_KILL_STICKY_HEADERS
      (function () {
        var i, elements = document.querySelectorAll('body *');

        for (i = 0; i < elements.length; i++) {
          if (getComputedStyle(elements[i]).position === 'fixed') {
            elements[i].parentNode.removeChild(elements[i]);
          }
        }
      })();
      JAVASCRIPT_KILL_STICKY_HEADERS
      execute_script script
    end
    # rubocop:enable Metrics/MethodLength

    # rubocop:disable Metrics/MethodLength
    # Note: In many tests we use "password" as the password.
    # Users can (no longer) create accounts with this too-easy password.
    # Using "password" helps test that users can log in to their
    # existing accounts, even if we make the password rules harsher later.
    def log_in_as(
      user,
      password: 'password',
      provider: 'local',
      remember_me: '1'
    )
      # This is based on "Ruby on Rails Tutorial" by Michael Hargle, chapter 8,
      # https://www.railstutorial.org/book
      time_last_used = Time.now.utc
      post login_path, params: {
        session: {
          email:  user.email, password: password,
          provider: provider, remember_me: remember_me,
          time_last_used: time_last_used
        }
      }
    end
    # rubocop:enable Metrics/MethodLength

    def scroll_to_see(id)
      # Scroll element to the bottom of the viewport to clear
      # the fixed top navbar, mirroring a realistic user action.
      execute_script("document.getElementById('#{id}').scrollIntoView(false);")
    end

    # Click a radio button and verify it becomes checked.
    # Scrolls into view first to avoid fixed headers intercepting the click.
    # Retries if the click doesn't take (a known Capybara/Selenium issue).
    # rubocop:disable Metrics/MethodLength
    def ensure_choice(radio_button_id, wait_time: Capybara.default_max_wait_time)
      Timeout.timeout(wait_time) do
        loop do
          scroll_to_see(radio_button_id)
          # wait_for_jquery now includes animation and stability checks
          wait_for_jquery

          begin
            choose radio_button_id
          rescue Selenium::WebDriver::Error::ElementClickInterceptedError
            # If intercepted, wait for UI to settle and retry
            wait_for_jquery
            choose radio_button_id
          end

          # Verify state. visible: :all is safe here because we've already
          # successfully called 'choose' (which respects visibility).
          # Some radio buttons are technically "hidden" while their labels
          # are clicked; has_checked_field? handles this correctly.
          break if has_checked_field?(radio_button_id, visible: :all, wait: 0.5)

          sleep 0.1
        end
      end
    rescue Timeout::Error
      raise Timeout::Error,
            "Timeout: radio button '#{radio_button_id}' never became checked"
    end
    # rubocop:enable Metrics/MethodLength

    def user_logged_in?
      # Returns true if a test user is logged in.
      !session[:user_id].nil?
    end

    # rubocop:disable Metrics/MethodLength
    # You should generally use this call after jquery interactions like
    # find(...), ensure_choice, clicking radio buttons, and filling in forms.
    # You should INSTEAD use wait_for_page_load after
    # a page navigation ("visit").
    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def wait_for_jquery
      Timeout.timeout(Capybara.default_max_wait_time) do
        # 1. Wait for jQuery and all AJAX requests to complete
        loop do
          break if evaluate_script('typeof jQuery !== "undefined"') &&
                   finished_all_jquery_requests?

          sleep 0.05
        end

        # 2. Wait for UI stability (animations and scrolling).
        # We use separate loops to ensure each phase completes fully.

        # 2a. Wait for Bootstrap transitions to finish (.collapsing class)
        loop do
          break unless page.has_css?('.collapsing', wait: 0)

          sleep 0.05
        end

        # 2b. Wait for viewport/scroll position to stabilize
        # This ensures we aren't trying to click a moving target.
        last_pos = nil
        loop do
          current_pos = evaluate_script('window.pageYOffset')
          break if current_pos == last_pos && !last_pos.nil?

          last_pos = current_pos
          sleep 0.05
        end
      end
    rescue Timeout::Error
      jquery_defined =
        begin
          evaluate_script('typeof jQuery !== "undefined"')
        rescue StandardError
          false
        end
      jquery_active =
        begin
          evaluate_script('jQuery.active')
        rescue StandardError
          'N/A'
        end
      raise Timeout::Error, "Timeout waiting for jQuery. jQuery defined: #{jquery_defined}, " \
                            "jQuery.active: #{jquery_active}"
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

    def wait_for_url(url)
      Timeout.timeout(Capybara.default_max_wait_time) do
        loop do
          uri = URI.parse(current_url)
          break if url == "#{uri.path}?#{uri.query}"

          sleep 0.05 # Avoid busy-wait CPU burning
        end
      end
    end

    # Wait for page to be fully loaded (document.readyState === 'complete')
    # and for any pending jQuery AJAX requests to finish.
    # You should generally use this call after any page navigation ("visit").
    # This is more reliable than wait_for_jquery for standard form submissions
    # with redirects, as it waits for the entire page lifecycle to complete.
    # rubocop:disable Metrics/MethodLength
    def wait_for_page_load(timeout: Capybara.default_max_wait_time * 2)
      Timeout.timeout(timeout) do
        # Wait for document.readyState to be 'complete'
        loop do
          ready_state = evaluate_script('document.readyState')
          break if ready_state == 'complete'

          sleep 0.05
        end

        # If jQuery is present, also wait for AJAX requests to complete
        jquery_present = evaluate_script('typeof jQuery !== "undefined"')
        if jquery_present
          loop do
            break if evaluate_script('jQuery.active') == 0

            sleep 0.05
          end
        end
      end
    rescue Timeout::Error
      ready_state =
        begin
          evaluate_script('document.readyState')
        rescue StandardError
          'unknown'
        end
      jquery_active =
        begin
          evaluate_script('jQuery.active')
        rescue StandardError
          'N/A'
        end
      raise Timeout::Error, 'Timeout waiting for page load. ' \
                            "readyState: #{ready_state}, jQuery.active: #{jquery_active}"
    end
    # rubocop:enable Metrics/MethodLength

    private

    def finished_all_jquery_requests?
      # jQuery must be loaded for this check to work
      # Use == 0 instead of .zero? to handle potential type coercion issues
      evaluate_script('jQuery.active') == 0 # rubocop:disable Style/NumericPredicate
    end

    def integration_test?
      # Returns true inside an integration test.
      # Based on "Ruby on Rails Tutorial" by Michael Hargle, chapter 8,
      # https://www.railstutorial.org/book
      defined?(post_via_redirect)
    end

    def omniauth_hash(cassette)
      {
        'provider' => 'github',
        'uid' => '12345',
        'credentials' => { 'token' => vcr_oauth_token(cassette) },
        'info' => {
          'name' => 'CII Test',
          'email' => 'test@example.com',
          'nickname' => 'bestpracticestest'
        }
      }
    end

    def vcr_oauth_token(cassette)
      github_login_vcr_file = "test/vcr_cassettes/#{cassette}.yml"
      return unless File.exist?(github_login_vcr_file)

      y = YAML.load_file(github_login_vcr_file).with_indifferent_access
      query_string = y[:http_interactions][0][:response][:body][:string]
      Rack::Utils.parse_nested_query(query_string)['access_token']
    end

    def key_with_nil_value(hash)
      hash.each do |k, v|
        return k.to_s if v.nil?
        next unless v.is_a?(Hash)

        nil_key = key_with_nil_value(v)
        next if nil_key == ''

        return "#{k}.#{nil_key}"
      end
      ''
    end

    # Re-implement assert_select - return true iff a CSS selection
    # using *selector* contains exactly "contents".
    # The problem is that assert_select fails oddly when running a global
    # "rails test" (though it works fine if running "rails test FILENAME").
    # To solve this, we re-implement assert_select so we have a working version.
    # rubocop:disable Naming/PredicateMethod
    def my_assert_select(selector, contents)
      results = css_select(selector)
      results.each do |selection|
        return true if selection.content == contents
      end
      false
    end
    # rubocop:enable Naming/PredicateMethod

    # Assert that the current page has no form validation errors
    # This is useful in system tests to detect when forms fail validation,
    # which often manifests as unexpected redirects or page reloads.
    # The helper checks for common Rails form error patterns.
    #
    # Usage in system tests:
    #   fill_in 'Name', with: 'Test'
    #   click_button 'Save'
    #   assert_no_form_errors  # Fails with clear message if validation errors exist
    def assert_no_form_errors
      # Check for Rails form error div (field_with_errors class)
      assert_no_selector '.field_with_errors',
                         'Form has validation errors (field_with_errors present)'

      # Check for error explanation divs
      assert_no_selector '#error_explanation',
                         'Form has validation errors (error_explanation present)'
      assert_no_selector '.alert-danger',
                         'Form has error alert'
    end
  end
  # rubocop: enable Metrics/ClassLength
end
