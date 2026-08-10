# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

Rails.application.configure do
  # Settings specified here will take precedence over those in
  # config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.enable_reloading = true

  config.public_file_server.enabled = true
  # Do not eager load code on boot.
  config.eager_load = false

  # This replaces the quiet assets gem in Rails 5
  config.assets.quiet = true

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

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.delivery_method = :test
  host = 'localhost:3000'
  config.action_mailer.default_url_options = { host: host }

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Don't force SSL in dev environment - causes 301 redirects that break it
  config.force_ssl = false

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Asset digests allow you to set far-future HTTP expiration dates on all
  # assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = true
end
