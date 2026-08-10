# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Helper module for unsubscribe functionality
module UnsubscribeHelper
  # Maximum unsubscribe token age in days (from environment, frozen at startup)
  MAX_TOKEN_AGE_DAYS = (ENV['BADGEAPP_UNSUBSCRIBE_DAYS'] || '30').to_i

  # Frozen regexes for token/date validation (memory optimization)
  TOKEN_FORMAT_REGEX = /\A[a-f0-9]{64}\z/
  ISSUED_DATE_FORMAT_REGEX = /\A\d{4}-\d{2}-\d{2}\z/

  # Compute key array from comma-separated string
  # @param keys_string [String] Comma-separated string of keys
  # @return [Array<String>] Array of keys with empty ones removed and frozen
  def self.compute_key_array(keys_string)
    keys_string.split(',').map(&:strip).reject(&:empty?).freeze
  end

  # Unsubscribe secret keys for key rotation (computed once at startup)
  # This allows tokens generated with any of these keys to be valid
  # Format: comma-separated keys; first key is used for new token generation
  UNSUBSCRIBE_KEYS =
    begin
      keys_env = ENV['BADGEAPP_UNSUBSCRIBE_KEYS'] ||
                 Rails.application.secret_key_base
      compute_key_array(keys_env)
    end

  # Generate secure unsubscribe token with email and issued date.
  # This method generates tokens using only email and date, no database access
  #
  # @param email [String] The email address to generate the token for
  # @param issued_date [String] The date when the email was issued
  # @param key [String] secret key (default: first key in UNSUBSCRIBE_KEYS)
  # @return [String] a secure HMAC-based token
  def generate_unsubscribe_token(
    email, issued_date, key: UNSUBSCRIBE_KEYS.first
  )
    return if email.blank? || issued_date.nil?
    return unless email.is_a?(String) && issued_date.is_a?(String)

    # Security: Use HMAC with secret key for token generation
    # Include issued date in the message for time-based validation
    message = "#{email}:#{issued_date}"
    OpenSSL::HMAC.hexdigest('SHA256', key, message)
  end

  # Generate new unsubscribe token with current date.
  # This method determines current date and generates token with issued date
  #
  # @param email [String] The email address to generate the token for
  # @return [Array(String, String)] [issued_date, token] on success
  # @return [Array(nil, nil)] if email is blank
  def generate_new_unsubscribe_token(email)
    return [nil, nil] if email.blank?

    # Get current date as string in YYYY-MM-DD format
    issued_date = Date.current.strftime('%Y-%m-%d')

    # Generate token using email and current date
    token = generate_unsubscribe_token(email, issued_date)

    [issued_date, token]
  end

  # Generate secure unsubscribe URL with issued date
  # This method creates a complete URL that can be used in emails
  #
  # @param email [String] The email address to generate the URL for
  # @param locale [String] Optional locale for the URL (default: current locale)
  # @return [String] A complete unsubscribe URL with token and issued date
  def generate_unsubscribe_url(email, locale: I18n.locale)
    return if email.blank?

    # Generate current date and token
    issued_date, token = generate_new_unsubscribe_token(email)
    return if token.nil?

    # Build URL parameters and generate URL
    url_params = build_unsubscribe_url_params(email, token, issued_date, locale)
    url_for(url_params)
  end

  private

  # Build URL parameters for unsubscribe URL generation
  # @param email [String] Email address
  # @param token [String] Generated token
  # @param issued_date [String] Date token was issued
  # @param locale [String, nil] Locale for the URL
  # @return [Hash] URL parameters
  def build_unsubscribe_url_params(email, token, issued_date, locale)
    url_params = {
      controller: 'unsubscribe',
      # This creates an odd URL, but strictly speaking, we are *editing*
      # the subscription, not merely *showing* it, so this seems appropriate:
      action: 'edit',
      email: email,
      token: token,
      issued: issued_date,
      only_path: false,
      protocol: Rails.application.config.force_ssl ? 'https' : 'http'
    }

    # Add locale if provided
    url_params[:locale] = locale if locale
    url_params
  end

  public

  # Security: Verify unsubscribe token with time-based validation
  # This method uses constant-time comparison and NO database access
  # Tries all keys in the provided keys array for key rotation support
  #
  # @param email [String] The email address to verify the token for
  # @param issued_date [String] The issued date from the request
  # @param token [String] The token to verify
  # @param keys [Array<String>] keys to try (default: UNSUBSCRIBE_KEYS)
  # @return [Boolean] true if the token is valid and within time window
  def verify_unsubscribe_token?(
    email, issued_date, token, keys: UNSUBSCRIBE_KEYS
  )
    return false if email.blank? || token.blank? || issued_date.blank?
    return false if keys.blank?

    # Security: Validate issued date format and time window
    return false unless valid_issued_date?(issued_date)

    # Security: Try verification with each key in the array
    verify_token_with_keys?(email, issued_date, token, keys)
  end

  private

  # Security: Try verification with each key in the array
  # Supports key rotation: tokens valid with any key in the array
  #
  # @param email [String] The email address to verify the token for
  # @param issued_date [String] The issued date from the request
  # @param token [String] The token to verify
  # @param keys [Array<String>] Keys array to try for verification
  # @return [Boolean] True if any key successfully verifies the token
  def verify_token_with_keys?(email, issued_date, token, keys)
    keys.each do |key|
      next if key.blank?

      # Security: Generate expected token for comparison (no database access)
      expected_token = generate_unsubscribe_token(email, issued_date, key: key)
      next if expected_token.nil?

      # Security: Use constant-time comparison to prevent timing attacks
      secure = ActiveSupport::SecurityUtils
               .secure_compare(expected_token, token)
      return true if secure
    end

    # If we get here, none of the keys worked
    false
  end

  public

  # Security: Validate issued date format and time window
  # @param issued_date [String] The date to validate
  # @return [Boolean] True if date is valid and within acceptable range
  def valid_issued_date?(issued_date)
    return false if issued_date.blank?

    # Security: First check if date format is valid YYYY-MM-DD
    return false unless valid_issued_format?(issued_date)

    # Convert string to Date, won't raise exceptions because we know format OK
    date = Date.parse(issued_date)

    # Security: Check date is not in future.
    # We don't need tolerance for clock skew because the date we're checking
    # should be a date we sent earlier.
    return false if date > Date.current

    # Security: Check date is not too far in past
    # (prevents malicious use of old stolen unsubscribe link)
    return false if date < Date.current - MAX_TOKEN_AGE_DAYS.days

    true
  end

  # Security: Validate email format
  # @param email [String] Email to validate
  # @return [Boolean] True if email format is valid
  def valid_email_format?(email)
    return false if email.blank?
    return false if email.length > 254 # RFC 5321 limit

    # Use very loose email validation - just check for @ symbol
    # Rely on view escaping for XSS protection rather than restricting
    # the email formats, because there's a lot of variation in email formats
    email.include?('@')
  end

  # Security: Validate token format and length
  # @param token [String] Token to validate
  # @return [Boolean] True if token format is valid
  def valid_token_format?(token)
    return false if token.blank?

    # HMAC-SHA256 produces 64-character hex strings
    return false if token.length != 64

    # Security: Ensure token contains only hex characters
    # Use frozen regex constant to avoid regex recompilation
    token.match?(TOKEN_FORMAT_REGEX)
  end

  # Security: Validate issued date format
  # @param issued [String] Issued date string to validate
  # @return [Boolean] True if format is valid
  def valid_issued_format?(issued)
    return false if issued.blank?
    return false if issued.length < 10 || issued.length > 12

    # Strict YYYY-MM-DD format
    # Use frozen regex constant to avoid regex recompilation
    issued.match?(ISSUED_DATE_FORMAT_REGEX)
  end
end
