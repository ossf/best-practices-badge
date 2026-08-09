# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# rubocop: disable Metrics/ClassLength
# Controller for users functionality.
#
class UsersController < ApplicationController
  # NOTE: If a "before" filter renders or redirects, the action will not run,
  # and other additional filters scheduled to run after it are cancelled.
  # See: http://guides.rubyonrails.org/action_controller_overview.html
  # Require being logged in for "index" to slightly discourage enumeration
  before_action :redir_unless_logged_in, only: %i[edit update destroy index]
  before_action :redir_unless_current_user_can_edit,
                only: %i[edit update destroy]
  before_action :enable_maximum_privacy_headers
  include SessionsHelper

  # These are the permitted parameters in compute_user_params.
  PERMITTED_PARAMS = %i[
    name email password password_confirmation
    preferred_locale notification_emails important_notifications
  ].freeze

  # Maximum number of user search results to prevent system overwhelm
  MAX_USER_SEARCH_RESULTS = 500

  # Displays list of resources.
  # @return [void]
  def index
    user_result = search_users
    @pagy, @users = pagy(:offset, user_result)
  end

  # Search users for desired_name (which is presumed to be non-empty)
  # @param desired_name [String] The name to search for (case-insensitive partial match)
  # @param limit [Integer] Maximum number of IDs to return
  # @return [Array<Integer>] Array of user IDs matching the name
  def search_name(desired_name, limit = MAX_USER_SEARCH_RESULTS + 1)
    # We *only* allow search of names and/or email by admins.
    # Email search reveals confidential info; name search would permit
    # possibly-excessive load by untrusted users.
    return [] unless current_user&.admin?

    # To maximize finding, use a case-insensitive "find anywhere" search.
    # An exact case-sensitive search would for names look like this:
    # result = result.where(name: params[:name])
    #
    # INTENTIONAL: We do NOT escape LIKE wildcards (% and _) here because
    # admin users need wildcard search capabilities for GDPR compliance
    # and legal requests. This allows admins to use % for zero or more
    # characters and _ for exactly one character in their search patterns.
    # This is safe because only admin users can access this functionality.
    # Return only IDs to minimize memory usage.
    User.where('lower(name) LIKE ?', "%#{desired_name.strip.downcase}%")
        .limit(limit).ids
  end

  # Search users for desired_email (which is presumed to be non-empty)
  # @param desired_email [String] The email address to search for (exact match)
  # @param limit [Integer] Maximum number of IDs to return
  # @return [Array<Integer>] Array of user IDs matching the email
  def search_email(desired_email, limit = MAX_USER_SEARCH_RESULTS + 1)
    # We *only* allow search of names and/or email by admins.
    # Email search reveals confidential info; name search would permit
    # possibly-excessive load by untrusted users.
    return [] unless current_user&.admin?

    # Handle "Fullname <email@domain>" format
    email_to_search = desired_email.strip
    # Check if '>' is the last non-space character
    if email_to_search.rstrip.end_with?('>')
      # Remove trailing '>' and spaces
      email_to_search = email_to_search.rstrip.chomp('>')
      # If there's a '<', extract everything after it
      if email_to_search.include?('<')
        email_to_search = email_to_search.split('<').last
      end
      email_to_search = email_to_search.strip
    end
    # We presume email is stored as citext, which is case-insensitive.
    # Return only IDs to minimize memory usage.
    User.where(email: email_to_search).limit(limit).ids
  end

  # Validate email has @ with character around it
  # @param email [String] The email to validate
  # @return [Boolean] true if valid basic format
  def valid_email_format?(email)
    return false if email.blank?

    # Must have @ with at least one character before and after
    email.match?(/\S@\S/)
  end

  # Search users by lists of names and/or emails
  # @param search_names_list [String] Newline-separated names (can be nil)
  # @param search_emails_list [String] Newline-separated emails (can be nil)
  # @param max_num_results [Integer] Maximum number of results allowed
  # @return [Hash] { user_ids: Array<Integer>, error: String|nil }
  # rubocop: disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity
  def search_users_by_lists(
    search_names_list,
    search_emails_list,
    max_num_results = MAX_USER_SEARCH_RESULTS
  )
    # We *only* allow search of names and/or email by admins.
    # Email search reveals confidential info; name search would permit
    # possibly-excessive load by untrusted users.
    return { user_ids: [], error: nil } unless current_user&.admin?

    # Validate UTF-8 encoding; check before .present? to avoid ArgumentError
    if search_names_list && !search_names_list.valid_encoding?
      return { user_ids: [], error: 'Invalid UTF-8 in name search' }
    end
    if search_emails_list && !search_emails_list.valid_encoding?
      return { user_ids: [], error: 'Invalid UTF-8 in email search' }
    end

    # Use limit + 1 to detect when we've exceeded the maximum
    query_limit = max_num_results + 1
    found_user_ids = Set.new

    # Process names
    if search_names_list.present?
      # Split by \n; .strip will remove any \r from CRLF line endings
      search_names_list.split("\n").each do |name|
        next if name.strip.empty?

        found_user_ids.merge(search_name(name, query_limit))

        # Early termination if too many results
        next if found_user_ids.size <= max_num_results

        return {
          user_ids: [],
          error: "Too many results (>#{max_num_results}). " \
                 'Please refine your search.'
        }
      end
    end

    # Process emails - only works with production blind index key
    if search_emails_list.present? && User.email_search_available?
      # Split by \n; .strip will remove any \r from CRLF line endings
      search_emails_list.split("\n").each do |email|
        # Store stripped email once to avoid multiple .strip calls
        email_stripped = email.strip
        next if email_stripped.empty?

        # Validate email format
        unless valid_email_format?(email_stripped)
          return {
            user_ids: [],
            error: "Invalid email format: #{email_stripped}"
          }
        end

        found_user_ids.merge(search_email(email, query_limit))

        # Early termination if too many results
        next if found_user_ids.size <= max_num_results

        return {
          user_ids: [],
          error: "Too many results (>#{max_num_results}). " \
                 'Please refine your search.'
        }
      end
    end

    { user_ids: found_user_ids.to_a, error: nil }
  end
  # rubocop: enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity

  # Search users. Search is ONLY supported for admin, so that we can't leak
  # email data about users, and to discourage people from being harassed
  # if they can be searched by name. It also counters DoS, since we will
  # refuse to provide a service we don't want to provide.
  # For normal users we ignore search parameters.
  # rubocop: disable Metrics/AbcSize
  def search_users
    result = User.all
    search_names = params[:search_names]
    search_emails = params[:search_emails]
    search = search_names.present? || search_emails.present?
    if current_user.admin? && search
      search_result = search_users_by_lists(search_names, search_emails)
      return User.none.tap { flash[:danger] = search_result[:error] } if search_result[:error]

      # If no match, result will be empty
      result = User.where(id: search_result[:user_ids])
    end
    result
  end
  # rubocop: enable Metrics/AbcSize

  private :search_name, :search_email, :valid_email_format?,
          :search_users_by_lists, :search_users

  # rubocop: disable Metrics/MethodLength, Metrics/AbcSize
  def show
    @user = User.find(params[:id])
    respond_to :html, :json
    # Paginate the list of user-owned projects.
    # Use "select_needed" to minimize the fields we extract
    # Note: No need to eager-load user - all projects belong to @user
    @pagy, @projects = pagy(:offset, select_needed(@user.projects))

    # Don't bother paginating the projects with additional rights,
    # we practically never have that many and the interface would be confusing.
    @projects_additional_rights =
      select_needed(Project.includes(:user).joins(:additional_rights)
        .where(additional_rights: { user_id: @user.id }))
    # *Separately* list edit_projects from projects_additional_rights.
    # Jason Dossett thinks they should be combined, but David A. Wheeler
    # thinks these are important to keep separate because how to *change*
    # what is in these lists is radically different.
    return unless @user == current_user && @user.provider == 'github'

    # NOTE: we intentionally only obtain a *subset* of the projects
    # the user controls using github_user_projects (since otherwise we
    # could wait a ridiculous amount of time). So in some cases
    # this won't include all projects the user can actually edit.
    # That's okay, since we *always* show the projects with additional rights;
    # this is just an attempt to "sweep up" other data we otherwise lack.
    @edit_projects =
      select_needed(
        Project.includes(:user).where(repo_url: github_user_projects)
      ) - @projects
  end

  # Displays form for creating new resource.
  # @return [void]
  def new
    @user = User.new
  end

  # rubocop: enable Metrics/MethodLength, Metrics/AbcSize

  def edit
    @user = User.find(params[:id])
    # Force redirect if current_user cannot edit.  Otherwise, the process
    # of displaying the edit fields (with their defaults) could cause an
    # unauthorized exposure of an email address.
    redirect_to @user unless current_user_can_edit?(@user)
  end

  # Create new user account (signup functionality).
  # NOTE: Rate limiting for account creation is handled by Rack::Attack
  # (see config/initializers/rack_attack.rb)
  # rubocop: disable Metrics/MethodLength, Metrics/AbcSize
  def create
    if Rails.application.config.deny_login
      flash.now[:danger] = t('sessions.login_disabled')
      render 'new', status: :forbidden
      return
    end
    user_parameter_values = compute_user_params
    @user = User.find_by(email: user_parameter_values[:email])
    if @user
      # If user exists but is not activated, retry activation unless too soon
      if !@user.activated
        # Rate limit activation emails, else attackers can really annoy others
        if activation_email_too_soon?(@user.activation_email_sent_at)
          # Logger doesn't escape, but user.id is just a number so no problem
          Rails.logger.info "Activation request too soon for #{@user.id}"
        else
          regenerate_activation_digest
          @user.send_activation_email
        end
      end
    else
      @user = User.new(user_parameter_values)
      @user.provider = 'local'
      @user.preferred_locale = I18n.locale.to_s
      @user.use_gravatar = @user.gravatar_exists? # this is local
      if @user.save
        @user.send_activation_email
      end
    end
    # ALWAYS show "activation link created" message, so people can't
    # determine whether or not the email address already exists
    flash[:info] = t('users.new_activation_link_created')
    redirect_to root_path, status: :found
  end

  # Produce a cleaned-up hash of changes.
  # The key is the field that was changed, the value is [old, new]
  # We must cleanup, because password_digest stores changes even when
  # old and new have the same value (so we must remove it).
  # In addition, because email values are encrypted, we have to separately
  # report the old and new values if they changed.
  # @param changeset [Hash] Hash of field changes from ActiveModel
  # @param old_email [String] The previous email address before change
  # @param new_email [String] The new email address after change
  def cleanup_changes(changeset, old_email, new_email)
    result = {}
    changeset.each do |key, change|
      # Only consider "change" if it is in the expected form [old, new]
      if change.is_a?(Array) && change.length == 2
        result[key] = change if change.first != change[1]
      end
    end
    result['email'] = [old_email, new_email] unless old_email == new_email
    result
  end

  # rubocop: disable Metrics/AbcSize, Metrics/MethodLength
  def update
    @user = User.find(params[:id])
    old_email = @user&.email_if_decryptable
    user_parameter_values = compute_user_params
    @user.assign_attributes(user_parameter_values)
    changes = cleanup_changes(
      @user.changes, old_email, @user.email_if_decryptable
    )
    if @user.save
      # If user changed his own locale, switch to it.  It's possible for an
      # *admin* to change someone else's locale, in that case leave it alone.
      # Store preferred_locale once to avoid duplicate hash lookup
      preferred_locale = user_parameter_values[:preferred_locale]
      if current_user == @user && preferred_locale
        I18n.locale = preferred_locale.to_sym
      end
      # Email user on every change.  That way, if the user did *not* initiate
      # the change (e.g., because it's by an admin or by someone who broke
      # into their account), the user will know about it.
      UserMailer.user_update(@user, changes).deliver_now
      @user.use_gravatar = @user.gravatar_exists? if @user.provider == 'local'
      flash[:success] = t('.profile_updated')
      locale_prefix = '/' + I18n.locale.to_s
      redirect_to "#{locale_prefix}/users/#{@user.id}"
    else
      render 'edit'
    end
  end
  # rubocop: enable Metrics/AbcSize, Metrics/MethodLength

  # rubocop: disable Metrics/MethodLength, Metrics/AbcSize
  def destroy
    id_to_delete = Integer(params[:id], 10)
    # TODO: Should we show a more graceful output if id is not found?
    user_to_delete = User.find(id_to_delete) # Exception raised if not found
    # Nest transaction to be *certain* we include all in the transaction
    Project.transaction do
      User.transaction do
        if Project.exists?(user_id: id_to_delete)
          flash[:danger] = t('.cannot_delete_user_with_projects')
          redirect_to user_path(id: id_to_delete)
        else
          # Use destroy! - raises exception on (unexpected) failure, and auto-
          # removes associated ApplicationRecords via the has_many association.
          # There may be ApplicationRecords on this user, because the user
          # cannot necessarily control the rights granted to him by others.
          log_out if id_to_delete == current_user.id
          user_to_delete.destroy!
          flash[:success] = t('.user_deleted')
          redirect_to root_path
        end
      end
    end
  end
  # rubocop: enable Metrics/MethodLength, Metrics/AbcSize

  DELAY_BETWEEN_ACTIVATION_EMAILS = Integer(
    ENV['BADGEAPP_DELAY_BETWEEN_ACTIVATION_EMAIL'] ||
     24.hours.seconds.to_s, 10
  ).seconds

  private

  # Return true iff sent_at is too soon (compared to the current time)
  # to send an activation email.
  def activation_email_too_soon?(sent_at)
    # We've never sent one before, so it's obviously not too soon.
    return false if sent_at.blank?

    DELAY_BETWEEN_ACTIVATION_EMAILS.since(sent_at) > Time.zone.now
  end

  # Enable privacy headers to the maximum we can.
  # @return [void]
  def enable_maximum_privacy_headers
    # Harden the response by maximizing HTTP headers of user data
    # for privacy. We do this by inhibiting indexing and caching.
    # Our primary goal is to ensure that we maintain the privacy of
    # private data.  However, we also want to be prepared so that
    # if there *is* a breach, we reduce its impact.
    # These lines instruct others to disable indexing and caching of
    # user data, so that if private data is inadvertently released,
    # it is much less likely to be easily available to others via
    # web-crawled data (such as from search engines) or via caches.
    # The goal is to make it harder for adversaries to get leaked data.
    # We do this as HTTP headers, so it applies to anything (HTML, JSON, etc.)
    # We don't say "must-revalidate", because we're already saying
    # no-store (so there would be nothing to revalidate); even if we try,
    # Rails notices the inconsistency & removes it.
    # Note that we need "private" along with "no-store"; the spec suggests
    # "no-store" is enough, but "no-store" is ignored by some systems
    # such as Fastly. See:
    # https://github.com/rails/rails/issues/40798
    response.set_header('X-Robots-Tag', 'noindex')
    response.set_header('Cache-Control', 'private, no-store')
  end

  # Reply with only permitted user parameters and ensure required
  # ones are present
  def compute_user_params
    # Base parameters that all users can modify for their own account
    # NOTE: We don't allow *anyone* to modify :provider and :uid.
    user_params = params.expect(user: PERMITTED_PARAMS)
    # Remove the password and password confirmation keys for empty values
    user_params.delete(:password) if user_params[:password].blank?
    user_params.delete(:password_confirmation) if
      user_params[:password_confirmation].blank?
    user_params
  end

  # Confirm this is logged-in user; redirect if not
  def redir_unless_logged_in
    return if logged_in?

    flash[:danger] = t('users.please_log_in')
    redirect_to login_path
  end

  # Return true if current_user can edit account 'user'
  def current_user_can_edit?(user)
    return false unless current_user

    user == current_user || current_user.admin?
  end

  # Confirm that this user can edit; sets @user to the user to process
  def redir_unless_current_user_can_edit
    @user = User.find(params[:id])
    return if current_user_can_edit?(@user)

    flash[:danger] = t('users.edit.inadequate_privileges')
    redirect_to(root_path)
  end

  # Handles regenerate activation digest functionality.
  # @return [void]
  def regenerate_activation_digest
    @user.activation_token = User.new_token
    @user.activation_digest = User.digest(@user.activation_token)
    @user.save!(touch: false)
  end

  # If we're sending an HTML project table, select only the fields needed.
  # This significantly reduces memory allocations.
  # @param dataset [ActiveRecord::Relation] The project dataset to optimize
  def select_needed(dataset)
    return dataset unless request.format.symbol == :html

    dataset.select(ProjectsController::HTML_INDEX_FIELDS)
  end
end
# rubocop: enable Metrics/ClassLength
