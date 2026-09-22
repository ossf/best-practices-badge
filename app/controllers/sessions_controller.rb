# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Handles user authentication and session management.
# Supports both OAuth (GitHub) and local email/password authentication.
# Manages session creation, destruction, and security measures like
# session fixation protection.
#
# rubocop:disable-next Metrics/ClassLength
class SessionsController < ApplicationController
  include SessionsHelper

  # Do *NOT* redirect session creation, that will cause complicated failures
  # because we don't really want the locale. The same applies to :failure:
  # OmniAuth redirects to the path '/auth/failure' with no locale prefix, so
  # skipping this before_action just avoids a needless extra redirect to add
  # one. This does NOT make the response English-only -- the later
  # set_locale_to_best_available before_action still runs, so I18n.locale
  # (hence the flash message and the login_path we redirect to) reflects the
  # browser's Accept-Language. We use Accept-Language rather than the locale
  # of the originating page on purpose: these failures are often caused by a
  # missing/stale session cookie, so relying on session state to localize
  # would be unreliable exactly when it matters.
  skip_before_action :redir_missing_locale, only: %i[create failure]

  # Display login form or redirect if already logged in.
  # Supports `GET /login`.
  # @return [void]
  def new
    if logged_in?
      flash[:success] = t('sessions.already_logged_in')
      redirect_to root_url
    else
      use_secure_headers_override(:allow_github_form_action)
      store_location_and_locale
    end
  end

  # Process login attempt via OAuth or local authentication.
  # Handles session fixation protection and various authentication methods.
  # Supports `POST /login`.
  # NOTE: Rate limiting for login attempts is handled by Rack::Attack
  # (see config/initializers/rack_attack.rb)
  # @return [void]
  # rubocop:disable-next Metrics/AbcSize, Metrics/MethodLength
  def create
    # session[:locale] was stashed by store_location_and_locale when the
    # login form was first shown (GET /login), so this POST's own response
    # (after counter_fixation's reset_session wipes it) still renders in
    # the locale the person was actually looking at, not whatever this
    # POST's own URL/headers alone would derive (set_locale_to_best_available's
    # earlier before_action already ran using only *this* request's own
    # locale-less form submission).
    I18n.locale = session[:locale] if session[:locale]
    counter_fixation # Counter session fixation (but save forwarding url)
    if Rails.application.config.deny_login
      flash.now[:danger] = t('sessions.login_disabled')
      render 'new', status: :forbidden
    elsif request.env['omniauth.auth'].present?
      omniauth_login
    elsif hash_param(:session)[:provider] == 'local'
      local_login
    else
      # There is no information disclosure in this error message.
      # This path happens when (1) we are allowing logins (information we
      # freely disclose), and (2) the user has failed to log in using the
      # login process that they selected.
      # This path only reveals that the login failed for some reason;
      # it does not reveal whether or not the account exists.
      flash.now[:danger] = t('sessions.incorrect_login_info')
      render 'new'
    end
  end

  # Log out current user and redirect to home page.
  # Supports `DELETE /logout`.
  # @return [void]
  def destroy
    log_out if logged_in?
    flash[:success] = t('sessions.signed_out')
    redirect_to root_url
  end

  # Handle an OmniAuth login failure. OmniAuth redirects here (302) whenever a
  # login attempt fails; the most common cause in production is a missing or
  # stale request-phase CSRF token (e.g. a stale or CDN-cached login page
  # whose token no longer matches the browser's session). Previously there was
  # no route for '/auth/failure', so the user just saw a bare 404 ("not
  # found"). We log the rejection (so its frequency is visible on
  # staging/production) and send the user back to the login page with a
  # "please try again" message, which is what a manual reload accomplished.
  # Supports `GET /auth/failure`.
  # @return [void]
  def failure
    # `message` and `strategy` come from OmniAuth, but this endpoint is
    # public, so treat them as untrusted: truncate and use `inspect` (which
    # escapes newlines) to prevent log forging and log bloat.
    message = params[:message].to_s[0, 200]
    strategy = params[:strategy].to_s[0, 50]
    Rails.logger.warn(
      "OmniAuth login failed: strategy=#{strategy.inspect} " \
      "message=#{message.inspect} ip=#{request.remote_ip}"
    )
    flash[:danger] = t('sessions.login_failed')
    redirect_to login_path
  end

  private

  # Performs post-login setup for authenticated users.
  # Records login time, displays welcome message, and redirects appropriately.
  # If return_to_path is given (already validated), redirects there;
  # otherwise falls back to the session-stored forwarding URL or root.
  #
  # pending_resubmission_token, if given, is this specific login's own
  # request param (see ApplicationController#redirect_to_login_stashing
  # and docs/login-session-18.md's "Step 21"), not ambient session state;
  # writing it to session here, now that this login has actually
  # succeeded, is the only place that write happens.
  # @param user [User] The authenticated user
  # @param return_to_path [String, nil] A pre-validated server-relative path
  # @param pending_resubmission_token [String, nil] This login's own
  #   pending_resubmission_token param, if it carried one
  # @return [void]
  def successful_login(user, return_to_path = nil, pending_resubmission_token = nil)
    return if render_login_rate_limited?(user)

    log_in user
    session[:pending_resubmission_token] = pending_resubmission_token if
      pending_resubmission_token.present?
    redirect_after_login(return_to_path)

    # Report last login time (this can help users detect problems)
    last_login = user.last_login_at
    last_login = t('sessions.no_login_time') if last_login.blank?
    flash[:success] = t('sessions.signed_in', last_login_at: last_login)

    # Record last_login_at time.  We use update_columns because
    # it works even if we don't have the correct email decryption keys,
    # and so it won't change updated_at (so updated_at becomes more useful).
    # We don't need the model validations, we're just setting a timestamp.
    # rubocop: disable-next Rails/SkipsModelValidations
    user.update_columns(last_login_at: Time.now.utc)
  end

  # Renders the "too many logins" response if user is rate-limited
  # (SessionsHelper#login_rate_limited?, docs/login-session-evaluation.md finding #3), so
  # successful_login can bail out with one line instead of three.
  # @param user [User] the user attempting to log in
  # @return [Boolean] true if the rate-limited response was rendered
  def render_login_rate_limited?(user)
    return false unless login_rate_limited?(user)

    flash.now[:danger] = t('sessions.login_rate_limited')
    render 'new', status: :too_many_requests
    true
  end

  # Picks where to send the user right after login: an explicit validated
  # return_to takes priority over the ordinary forwarding_url-or-root
  # fallback. A stashed pending resubmission (docs/login-session-
  # implementation.md section 15) needs no special case here any more:
  # redirect_to_login_stashing already set return_to to the resource's own
  # edit page in that case, so it's handled by the ordinary branch below,
  # which lands the user back on that page with their stash overlaid (see
  # ApplicationController#overlay_pending_resubmission!).
  # @param return_to_path [String, nil] A pre-validated server-relative path
  # @return [void]
  def redirect_after_login(return_to_path)
    if return_to_path.present? && valid_return_path?(return_to_path)
      redirect_to return_to_path, allow_other_host: false
    else
      redirect_back_or root_url
    end
  end

  # Handles local email/password authentication.
  # @return [void]
  def local_login
    session_params = hash_param(:session)
    user = User.authenticate_local_user(
      session_params[:email],
      session_params[:password]
    )

    if user
      local_login_procedure(user)
    else
      flash.now[:danger] = t('sessions.invalid_combo')
      render 'new'
    end
  end

  # Handles OAuth authentication via GitHub.
  # Creates or finds user account and establishes session.
  # @return [void]
  # rubocop:disable-next Metrics/AbcSize
  def omniauth_login
    auth = request.env['omniauth.auth']
    user = User.find_by(provider: auth['provider'], uid: auth['uid']) ||
           User.create_with_omniauth(auth)
    session[:user_token] = auth['credentials']['token']
    update_github_nickname(user, auth['info']['nickname'])
    user.name ||= user.nickname
    return_to = request.env['omniauth.params']&.dig('return_to')
    return_to = nil unless valid_return_path?(return_to)
    pending_resubmission_token =
      request.env['omniauth.params']&.dig('pending_resubmission_token')
    successful_login(user, return_to, pending_resubmission_token)
  end

  # Keeps User#nickname in sync with the GitHub username this login's OAuth
  # payload carries. SessionsHelper#current_user_is_github_owner? trusts
  # this DB column for real edit authorization
  # (docs/login-session-18.md step 19); User.create_with_omniauth only
  # sets it once, at account creation, so later logins need this to catch
  # a real GitHub username change. Flashes the change so a user whose
  # GitHub username changed is never left wondering why something that
  # worked yesterday doesn't today.
  # @param user [User] the user logging in
  # @param new_nickname [String] GitHub nickname from this login's OAuth payload
  # @return [void]
  def update_github_nickname(user, new_nickname)
    new_nickname = new_nickname&.slice(0, User::MAX_NICKNAME_LENGTH_GITHUB)
    return if user.nickname == new_nickname

    old_nickname = user.nickname
    # docs/login-session-evaluation.md finding #5: `update` validates the
    # whole record, not just :nickname, so it can fail for reasons that
    # have nothing to do with the nickname itself (e.g. some other column
    # already held invalid data). Check the result: current_user_is_github_owner?
    # keeps authorizing off the DB column, so a flash claiming the change
    # took effect when it didn't would be actively misleading, not just
    # cosmetic.
    return log_nickname_update_failure(user) unless user.update(nickname: new_nickname)
    return if old_nickname.blank? # first login after account creation; nothing changed

    # Not flash.now: this method is only ever called from omniauth_login,
    # which always ends in successful_login's redirect_to, never a
    # render, so the notice must survive that redirect. RuboCop can't see
    # across the two methods to confirm that.
    # rubocop: disable-next Rails/ActionControllerFlashBeforeRender
    flash[:info] = t('sessions.github_nickname_changed',
                     old_nickname: old_nickname,
                     new_nickname: new_nickname)
  end

  # Logs a failed GitHub nickname update instead of silently proceeding as
  # though it worked (docs/login-session-evaluation.md finding #5). Not a
  # user-facing flash: this is a data problem (invalid state elsewhere on
  # the user record), not something the person logging in can act on.
  # @param user [User] the user whose nickname failed to update
  # @return [void]
  def log_nickname_update_failure(user)
    Rails.logger.warn(
      "Failed to update GitHub nickname for user id=#{user.id}: " \
      "#{user.errors.full_messages.join('; ')}"
    )
  end

  # Validates account status and processes local login.
  # Checks for account activation, login restrictions, and remember-me option.
  #
  # @param user [User] The user attempting to log in
  # @return [void]
  # rubocop:disable-next Metrics/AbcSize, Metrics/MethodLength
  def local_login_procedure(user)
    if !user.activated?
      flash[:warning] = t('sessions.not_activated')
      redirect_to root_url
    elsif !user.login_allowed_now?
      flash.now[:danger] = t('sessions.cannot_login_yet')
      render 'new', status: :forbidden
    else
      session_params = hash_param(:session)
      return_to = session_params[:return_to]
      return_to = nil unless valid_return_path?(return_to)
      successful_login(user, return_to, session_params[:pending_resubmission_token])
      session_params[:remember_me] == '1' ? remember(user) : forget(user)
    end
  end
end
