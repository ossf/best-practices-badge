# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# rubocop:disable Metrics/BlockLength
Rails.application.configure do
  # Settings specified here will take precedence over those in
  # config/application.rb.

  # The test environment is used exclusively to run your application's
  # test suite. You never need to work with it otherwise. Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs. Don't rely on the data there!
  config.enable_reloading = true

  # Do not eager load code on boot. This avoids loading your whole application
  # just for the purpose of running a single test. If you are using a tool that
  # preloads Rails for running tests, you may have to set it to true.
  config.eager_load = false

  # Configure static file server for tests with Cache-Control for performance.
  config.public_file_server.enabled = true
  config.public_file_server.headers =
    { 'Cache-Control' => 'public, max-age=3600' }

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = true
  # Cache store config - must match production.rb (see explanation there
  # for why this is duplicated rather than shared in application.rb).
  require_relative '../../lib/no_dup_coder'
  config.cache_store =
    :memory_store,
    {
      size: (ENV['RAILS_CACHE_SIZE'] || '128').to_i.megabytes,
      coder: NoDupCoder
    }

  # Raise exceptions instead of rendering exception templates.
  # This makes it easier to detect uncaught exceptions during testing.
  config.action_dispatch.show_exceptions = :none

  # Raise exceptions during test if a translation is missing
  config.i18n.raise_on_missing_translations = true

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test
  host = 'localhost:3000'
  config.action_mailer.default_url_options = { host: host }

  # Randomize the order test cases are executed.
  config.active_support.test_order = :random

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Don't force SSL in test environment - causes 301 redirects that break tests
  config.force_ssl = false

  # Enable Rack's built-in compression mechanism; this is important for people
  # with slow network connections.  Enable during tests to make test
  # more like production
  config.middleware.use Rack::Deflater
end
# rubocop:enable Metrics/BlockLength
