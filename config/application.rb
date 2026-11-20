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

    # Do NOT let Rails load lib/tasks/*.rake. The Rakefile loads them
    # itself, before deciding whether this application is needed at all,
    # so letting Rails load them again would give every task two bodies:
    # Rake appends actions rather than replacing them, and
    # "rake deploy_production" would deploy twice.
    #
    # The glob must be truthy but match nothing. Setting it to nil or ""
    # makes Rails::Paths hand the DIRECTORY to Kernel#load instead, which
    # fails. So this names what is going on, and matches no file.
    config.paths['lib/tasks'].glob = 'loaded-by-the-Rakefile-instead'
  end
end

Rails.application.configure do
  config.middleware.use Rack::Attack

  # Configure Rails Active Record Encryption using existing environment
  # variables (or deterministic test defaults when not set).
  # We use hexadecimal encoding (0010=\x00\x10), NOT Base64 or other.
  # 256-bit key in hex = 64 hex digits (256 / 8 * 2).
  # Production fails closed: with a key missing we leave the encryption keys
  # unset, so Rails raises on any email encrypt/decrypt instead of using the
  # publicly known fallback. Booting (e.g., assets:precompile) still works.
  email_key =
    lambda do |env_var, fallback_hex|
      hex = Rails.env.test? ? fallback_hex : ENV.fetch(env_var, nil)
      hex ||= fallback_hex unless Rails.env.production?
      hex && [hex].pack('H*')
    end
  email_encryption_key = email_key.call('EMAIL_ENCRYPTION_KEY', '1' * 64)
  email_blind_index_key = email_key.call('EMAIL_BLIND_INDEX_KEY', '2' * 64)
  email_keys_present = email_encryption_key && email_blind_index_key
  config.active_record.encryption.primary_key =
    email_keys_present ? email_encryption_key : nil
  # The deterministic key comes from the encryption key, not the blind index
  # key, so whoever holds only the former blind index (HMAC) key cannot
  # decrypt the deterministically encrypted email column.
  config.active_record.encryption.deterministic_key =
    if email_keys_present
      OpenSSL::HMAC.digest(
        'SHA256', email_encryption_key, 'badgeapp deterministic email key'
      )
    end
  config.active_record.encryption.key_derivation_salt = email_blind_index_key
  config.active_record.encryption.hash_digest_class = OpenSSL::Digest::SHA256
end

# NOTE: the only timezone we use is UTC.
