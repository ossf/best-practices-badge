# frozen_string_literal: true

# Copyright OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Enable Fastly support from Rails.
# We once used the fastly-rails gem, but that doesn't support Rails 6.
# The fastly (fastly-ruby) gem doesn't support threads (!).
# So we'll just call the purge API directly, as recommended in:
# https://github.com/fastly/fastly-ruby
# See also:
# https://developer.fastly.com/reference/api/purging/
# https://developer.fastly.com/reference/api/auth/

# We could require 'net/http', but that needs more code for HTTPS.

class FastlyRails
  include HTTParty

  # Base of API. To create a "dead port" after .com append ":444" or some
  # other unused port
  # FASTLY_BASE = 'https://api.fastly.com'
  FASTLY_BASE = 'https://api.fastly.com'
  FASTLY_API_KEY = ENV['FASTLY_API_KEY'].to_s
  FASTLY_OPTIONS = {
    headers: { 'Fastly-Key': FASTLY_API_KEY, 'User-Agent': USER_AGENT },
    timeout: 10 # seconds
  }.freeze
  FASTLY_SERVICE_ID = ENV['FASTLY_SERVICE_ID'].to_s

  # Purge the CDN resources associated with this key.
  # Use "force" to force a post even when we have no key or service id
  # (this is used for testing).
  # Returns true if the purge succeeded or was skipped (no credentials),
  # false if the purge failed (HTTP error or network exception).
  # Does not raise — callers that need to retry on failure should check
  # the return value and raise themselves (see PurgeCdnProjectJob).
  # rubocop:disable Metrics/MethodLength
  def self.purge_by_key(key, force = false, base = FASTLY_BASE)
    return true if !force && (FASTLY_API_KEY.blank? || FASTLY_SERVICE_ID.blank?)

    begin
      response = HTTParty.post(
        "#{base}/service/#{FASTLY_SERVICE_ID}/purge/#{key}",
        FASTLY_OPTIONS
      )
      if response.success?
        true
      else
        # HTTParty does not raise on HTTP error status codes, so we must
        # check explicitly. A 403/404 here typically means the API key or
        # service ID is misconfigured — not a network error, so StandardError
        # rescue below would not catch it.
        Rails.logger.error do
          "ERROR:: PURGE #{key} returned HTTP #{response.code}: #{response.body}"
        end
        false
      end
    rescue StandardError => e
      # I hate catching StandardError, ideally we'd be more specific.
      # However, there doesn't seem to be a safe way to identify
      # all network-based exceptions. See:
      # https://stackoverflow.com/questions/5370697/
      # what-s-the-best-way-to-handle-exceptions-from-nethttp
      # For example, this does NOT work:
      # rescue HTTParty::Error, Net::OpenTimeout, IOError => e
      Rails.logger.error do
        "ERROR:: FAILED TO PURGE #{key} , #{e.class}: #{e}"
      end
      false
    end
  end
  # rubocop:enable Metrics/MethodLength

  # rubocop:disable Metrics/MethodLength
  def self.purge_all(force = false, base = FASTLY_BASE)
    return if !force && (FASTLY_API_KEY.blank? || FASTLY_SERVICE_ID.blank?)

    begin
      # https://developer.fastly.com/reference/api/purging/
      # We won't ask for a "soft purge" because purge-all doesn't support it.
      response = HTTParty.post(
        "#{base}/service/#{FASTLY_SERVICE_ID}/purge_all",
        FASTLY_OPTIONS
      )
      unless response.success?
        # HTTParty does not raise on HTTP error status codes, so we must
        # check explicitly. A 403/404 here typically means the API key or
        # service ID is misconfigured.
        Rails.logger.error do
          "ERROR:: PURGE_ALL returned HTTP #{response.code}: #{response.body}"
        end
      end
      response
    rescue StandardError => e
      # I hate catching StandardError, ideally we'd be more specific.
      # However, there doesn't seem to be a safe way to identify
      # all network-based exceptions. See:
      # https://stackoverflow.com/questions/5370697/
      # what-s-the-best-way-to-handle-exceptions-from-nethttp
      # For example, this does NOT work:
      # rescue HTTParty::Error, Net::OpenTimeout, IOError => e
      Rails.logger.error do
        "ERROR:: FAILED TO PURGE_ALL, #{e.class}: #{e}"
      end
    end
  end
  # rubocop:enable Metrics/MethodLength

  # Log the Fastly service name returned at startup.
  # If expected_name is set (via FASTLY_SERVICE_NAME_EXPECTED), logs an error
  # when the name does not match, making wrong-service misconfiguration visible.
  # Extracted into a method so it can be unit-tested with arbitrary inputs;
  # called from config/initializers/fastly.rb after the credential check.
  # @param actual_name [String] service name from the Fastly API response
  # @param expected_name [String, nil] expected value of FASTLY_SERVICE_NAME_EXPECTED
  # @param service_id [String] included in log messages for context
  def self.log_service_name(actual_name, expected_name, service_id)
    Rails.logger.info("Fastly service name: '#{actual_name}' (#{service_id})")
    return if expected_name.blank? || actual_name == expected_name

    Rails.logger.error(
      "FASTLY CONFIG ERROR: Service name '#{actual_name}' does not match " \
      "expected '#{expected_name}' (FASTLY_SERVICE_NAME_EXPECTED). " \
      'CDN purges may be targeting the wrong service.'
    )
  end
end
