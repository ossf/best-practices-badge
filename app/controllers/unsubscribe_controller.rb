# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Controller for handling unsubscribe requests
class UnsubscribeController < ApplicationController
  include SessionsHelper
  include UnsubscribeHelper

  # Security: Enable CSRF protection for form submissions (create action)
  protect_from_forgery with: :exception

  # GET /unsubscribe
  # Display the unsubscribe form with email, token, and issued date
  # for confirmation.
  def edit
    # Extract params once to avoid multiple hash lookups
    @email = params[:email]
    @issued = params[:issued] # YYYY-MM-DD
    @token = params[:token]

    return unless validate_unsubscribe_params?
  end

  # POST /unsubscribe
  # Process the unsubscribe request
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def create
    # Extract params once to avoid multiple hash lookups
    @email = params[:email]
    @issued = params[:issued] # YYYY-MM-DD
    @token = params[:token]

    return unless validate_unsubscribe_params?

    # Security: Validate token before checking the database.
    # This gives specific error responses
    unless verify_unsubscribe_token?(@email, @issued, @token)
      # Security: Log potential security incident (without PII)
      # Use rpartition for efficiency (fixed 3-element array vs variable-size split)
      email_domain = @email.rpartition('@').last
      Rails.logger.info "Invalid unsubscribe token attempt for email domain: #{email_domain}"
      flash.now[:error] = t('unsubscribe.invalid_token')
      render :edit, status: :unprocessable_content
      return
    end

    # Update ALL users with exact matching email address (case-sensitive)
    # Security: Use safe database queries with parameterized statements
    # Note: update_all is safe here since we're only updating a simple boolean field
    # and we've already validated all inputs above
    # rubocop:disable Rails/SkipsModelValidations
    updated_count = User.where(email: @email, notification_emails: true)
                        .update_all(notification_emails: false,
                                    updated_at: Time.current)
    # rubocop:enable Rails/SkipsModelValidations

    if updated_count.zero?
      flash.now[:error] = t('unsubscribe.no_matching_accounts')
      render :edit, status: :unprocessable_content
      return
    end

    # Security: Log the unsubscribe action (without PII)
    # Calculate email domain once to avoid duplicate rpartition call
    email_domain = @email.rpartition('@').last
    Rails.logger.info "Unsubscribe success: #{updated_count} accounts updated for domain: #{email_domain}"
    flash[:notice] = t('unsubscribe.success', count: updated_count)

    redirect_to root_path
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  private

  # Security: Validate all unsubscribe parameters
  # Uses instance variables @email, @issued, @token set by calling methods
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def validate_unsubscribe_params?
    # Step 1: Check for required parameters
    if @email.blank? || @issued.blank? || @token.blank?
      flash.now[:error] = t('unsubscribe.missing_parameters')
      render :edit, status: :bad_request
      return false
    end

    # Step 2: Check parameter lengths to prevent DoS attacks
    if @email.length > 254 || @issued.length > 12 || @token.length > 64
      flash.now[:error] = t('unsubscribe.invalid_parameters')
      render :edit, status: :bad_request
      return false
    end

    # Step 3: Validate individual field formats
    valid_formats = valid_email_format?(@email) &&
                    valid_issued_format?(@issued) &&
                    valid_token_format?(@token)
    unless valid_formats
      flash.now[:error] = t('unsubscribe.invalid_parameters')
      render :edit, status: :bad_request
      return false
    end

    true
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
end
