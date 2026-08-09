# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Handle local user account activations
class AccountActivationsController < ApplicationController
  # Time in seconds after activating local account before login allowed.
  LOCAL_LOGIN_COOLOFF_TIME =
    Integer(ENV['LOCAL_LOGIN_COOLOFF_TIME'] || '3600', 10)

  # Activation tokens are SecureRandom.urlsafe_base64: [A-Za-z0-9_-] only.
  VALID_TOKEN_RE = /\A[A-Za-z0-9_-]{10,128}\z/

  # Show the activation confirmation page. We do NOT activate here, so
  # email clients that auto-fetch URLs (e.g., to pre-validate linked pages)
  # cannot activate accounts on behalf of users who never saw the email.
  def edit
    activation_params = params.permit(:email, :token)
    @token = activation_params[:token]
    @email = activation_params[:email]
    return if valid_activation_params?(@token, @email)

    flash[:danger] = t('account_activations.failed_activation')
    redirect_to root_url
  end

  # Process a local user account activation request (POST/PATCH).
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def update
    activation_params = params.permit(:email, :token)
    unless valid_activation_params?(activation_params[:token], activation_params[:email])
      flash[:danger] = t('account_activations.link_invalid_or_used')
      return redirect_to login_path
    end
    user = User.find_unactivated_by_valid_token(
      activation_params[:email], activation_params[:token]
    )
    if user
      user.can_login_starting_at = Time.zone.now + LOCAL_LOGIN_COOLOFF_TIME
      user.activate # This saves our result
      flash[:success] = t('account_activations.activated') + ' ' +
                        t(
                          'account_activations.delay',
                          count: LOCAL_LOGIN_COOLOFF_TIME / 3600.0
                        )
      # We do *not* log in user. This reduces the number of paths that
      # automatically log in, and increases the likelihood
      # that a user's password manager will see the password.
    else
      flash[:danger] = t('account_activations.link_invalid_or_used')
    end
    redirect_to login_path
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  private

  # Returns true iff token and email are present and match expected formats.
  def valid_activation_params?(token, email)
    token.present? && email.present? &&
      token.match?(VALID_TOKEN_RE) && email.match?(EmailValidator::EMAIL_RE)
  end
end
