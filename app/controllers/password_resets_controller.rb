# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

class PasswordResetsController < ApplicationController
  before_action :obtain_user, only: %i[edit update]
  before_action :require_valid_user, only: %i[edit update]
  before_action :require_unexpired_reset, only: %i[edit update]

  def new; end

  def edit; end

  # Process password reset requests.
  # NOTE: Rate limiting for password reset requests is handled by Rack::Attack
  # (see config/initializers/rack_attack.rb)
  #
  # NOTE: password resets *always* reply with the same message, in all cases.
  # At one time we replied with error reports if there was no account or if
  # there was a GitHub account (not a local account) with the email address.
  # However, that allowed attackers to determine if a given email address
  # was present or not in an account. That's not a large leak of
  # information; the attacker has to already guess the specific email address,
  # and they merely get "is present/absent" instead of the specific account.
  # Many systems *do* provide such error messages, so many users would
  # be unsurprised by this information leak.
  # Still, we want to be excellent at providing user privacy, so we're
  # going to go beyond what some might see as the minimum, and instead
  # do what we can to maximize our users' privacy.
  def create
    @user = User.find_by(email: hash_param(:password_reset)[:email],
                         provider: 'local')
    if @user
      # NOTE: We send the password reset to the email address originally
      # created by the *original* user, and *not* to the requester
      # (who may be attacking the original user's account). This prevents
      # attacks where the finding system is "overly generous" and matches
      # the "wrong" email address (e.g., exploiting dotless i). See:
      # https://eng.getwisdom.io/hacking-github-with-unicode-dotless-i/
      email_reset_password(@user)
    end
    flash[:info] = t('password_resets.instructions_sent')
    redirect_to root_url
  end

  # Updates an existing resource.
  # @return [void]
  def update
    new_password = hash_param(:user)[:password]
    if new_password.nil? || new_password == ''
      @user.errors.add(:password, t('password_resets.password_empty'))
      render 'edit'
    elsif @user.update(user_params)
      flash[:success] = t('password_resets.password_reset')
      redirect_to login_path
    else
      render 'edit'
    end
  end

  # Configuration constant for delay between reset passwords.
  DELAY_BETWEEN_RESET_PASSWORDS = Integer(
    ENV['DELAY_BETWEEN_RESET_PASSWORDS'] || 4.hours.seconds.to_s, 10
  ).seconds

  private

  # Return true iff sent_at is too soon (compared to the current time)
  # to send a reset password request.
  # @return [Boolean]
  def reset_password_too_soon?(sent_at)
    # We've never sent one before, so it's obviously not too soon.
    return false if sent_at.blank?

    DELAY_BETWEEN_RESET_PASSWORDS.since(sent_at) > Time.zone.now
  end

  # Handles email reset password instance method functionality.
  # @param user [User] The user instance
  # @return [Object] Method return value
  def email_reset_password(user)
    # Local password resets only make sense for local users
    return unless user.provider == 'local'

    # Don't send resets to unactivated accounts. If they were
    # created by a bot using someone else's email address, sending a
    # reset would generate a second unsolicited email to that address.
    return unless user.activated?

    # Once a password reset has been sent, wait at least
    # DELAY_BETWEEN_RESET_PASSWORDS before sending another so attackers
    # can't badger our users with password reset requests.
    return if reset_password_too_soon?(user.reset_sent_at)

    @user.create_reset_digest
    @user.send_password_reset_email
  end

  # Handles user params - only returns what's permitted
  def user_params
    params.expect(user: %i[password password_confirmation])
  end

  # Obtain User information
  def obtain_user
    @user = User.find_by(email: params[:email])
  end

  # Confirms a valid user.
  def require_valid_user
    unless @user&.activated? &&
           @user.authenticated?(:reset, params[:id])
      redirect_to root_url
    end
  end

  # Reject expired reset requests via redirect, else do nothing
  def require_unexpired_reset
    return unless @user.password_reset_expired?

    flash[:danger] = t('password_resets.reset_expired')
    redirect_to new_password_reset_url
  end
end
