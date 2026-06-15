# frozen_string_literal: true

# The trusted proxies' IP addresses are *not* being used for user
# authentication; they're being used to counter CDN piercing and to
# ensure that our rate limits apply to the correct IP addresses.

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require_relative 'boot'

# This loads all Rails libraries that are *present*. However,
# note that our Gemfile only includes the Rails gems we actually use
# (to reduce memory use and attack surface).
require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module BadgeApp
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified
    # here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Load framework defaults cumulatively from 5.0 through 8.1. Each version
    # includes all defaults from earlier versions. Key effects per version:
    #   5.0: per-form CSRF tokens, origin-header CSRF check, belongs_to required
    #   5.2: AES-256-GCM cookie encryption (rotation in cookies_rotations.rb)
    #   6.0: cookie metadata, modern mail delivery job
    #   6.1: has_many_inversing, SameSite=Lax, jitter on job retries
    #   7.0: SHA-256 key derivation, partial_inserts=false, open-redirect raise
    #   7.1: autoload path isolation, secure-token on initialize
    #   7.2: PostgreSQL date decoding
    #   8.0: Regexp.timeout (ReDoS defense), strict ETag freshness
    #   8.1: YJIT off in dev/test, no JSON HTML-escaping, relative-redirect raise
    config.load_defaults 8.1

    # Add lib/ to autoload paths so modules there are automatically loaded
    config.autoload_paths << Rails.root.join('lib')
  end
end

Rails.application.configure do
  config.middleware.use Rack::Attack
end

# NOTE: the only timezone we use is UTC.
