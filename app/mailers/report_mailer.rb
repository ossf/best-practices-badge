# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# This mailer is for reports from the badge system about projects,
# individually or collectively.  This includes reports about
# badge status changes, summary reports, reminders that a project
# isn't done, etc.  This does not include email to a user
# regarding that user's account; those are handled by UserMailer.

# When sending emails we use I18n.with_locale do..end.
# If the destination is user.email, use:
# ... I18n.with_locale(user.preferred_locale.to_sym) do
# If the destination is REPORT_EMAIL_DESTINATION, use:
# ... I18n.with_locale(I18n.default_locale) do
# That's because it's possible that the current user is an administrator
# or script, in which case the current I18n.locale is not necessarily
# the recipient's preferred_locale.  Where possible, we want to use
# the recipient's preferred_locale when sending an email.

# We have not internationalized debug/monthly reports, since they are
# only sent in one language anyway (translators have enough work to do,
# let's not ask them to translate unused text!).

# Mailer for report email notifications.
# rubocop:disable Metrics/MethodLength, Metrics/ClassLength
class ReportMailer < ApplicationMailer
  include SessionsHelper
  include UnsubscribeHelper

  # Configuration constant for report email destination.

  REPORT_EMAIL_DESTINATION = 'cii-badge-log@lists.coreinfrastructure.org'

  # Report to Linux Foundation that a project's status has changed.
  # @param project [Project] The project whose badge status has changed
  # @param old_badge_status [String] The previous badge level (e.g., 'in_progress', 'passing')
  # @param new_badge_status [String] The new badge level after the change
  def project_status_change(project, old_badge_status, new_badge_status)
    @project = project
    @old_badge_status = old_badge_status
    @new_badge_status = new_badge_status
    @project_info_url = project_url(@project, locale: nil)
    @report_destination = REPORT_EMAIL_DESTINATION
    set_standard_headers
    I18n.with_locale(I18n.default_locale) do
      mail(
        to: @report_destination,
        subject: "Project #{project.id} status change to #{new_badge_status}"
      )
    end
  end

  # Return subject line for given badge status.  Uses current I18n.locale.
  # @param old_badge_level [String] The previous badge level
  # @param new_badge_level [String] The new badge level
  # @param lost_level [Boolean] True if the project lost badge status
  def subject_for(old_badge_level, new_badge_level, lost_level)
    if lost_level
      t('report_mailer.subject_no_longer_passing', old_level: old_badge_level)
    else
      t('report_mailer.subject_achieved_passing', new_level: new_badge_level)
    end
  end

  # Create email to badge entry owner about their new badge status.
  # Looks up the owner from the database; prefer email_owner_with_user
  # when the caller already has the user to avoid an extra DB query.
  # @param project [Project] The project whose badge status changed
  # @param old_badge_level [String] The previous badge level
  # @param new_badge_level [String] The new badge level
  # @param lost_level [Boolean] True if the project lost badge status
  # @param badge_suffix [String] URL suffix for badge image ('badge' or 'baseline')
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def email_owner(project, old_badge_level, new_badge_level, lost_level, badge_suffix)
    return if project.nil? || project.id.nil? || project.user_id.nil?

    user = User.find(project.user_id)
    return if user.nil?

    email_owner_with_user(project, user, old_badge_level, new_badge_level,
                          lost_level, badge_suffix)
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity

  # Create email to badge entry owner using a pre-fetched user object.
  # Used by the daily loss-notification task to avoid an extra DB query
  # (the user is already loaded with a tight SELECT).
  # @param project [Project] The project whose badge status changed
  # @param user [User] The project owner (already loaded)
  # @param old_badge_level [String] The previous badge level
  # @param new_badge_level [String] The new badge level
  # @param lost_level [Boolean] True if the project lost badge status
  # @param badge_suffix [String] URL suffix for badge image ('badge' or 'baseline')
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity, Metrics/ParameterLists
  def email_owner_with_user( # rubocop:disable Metrics/ParameterLists
    project, user, old_badge_level, new_badge_level, lost_level, badge_suffix
  )
    return if project.nil? || project.id.nil?
    return if user.nil?
    return unless user.deliverable_email?

    @project = project
    @project_info_url =
      project_url(@project, locale: user.preferred_locale.to_sym)
    @email_destination = user.email
    @new_level = new_badge_level
    @old_level = old_badge_level
    @badge_suffix = badge_suffix
    @hostname = ENV.fetch('PUBLIC_HOSTNAME', 'localhost')
    set_standard_headers
    I18n.with_locale(user.preferred_locale.to_sym) do
      mail(
        to: @email_destination,
        template_name: lost_level ? 'lost_level' : 'gained_level',
        subject: subject_for(
          old_badge_level, new_badge_level, lost_level
        ).strip
      )
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity, Metrics/ParameterLists

  # Create warning email to badge entry owner using a pre-fetched user object.
  # Warns that the project's badge WILL BE lost on effective_date.
  # Used by the daily warning-notification task to avoid an extra DB query
  # (the user is already loaded with a tight SELECT).
  # @param project [Project] The project at risk of losing its badge
  # @param user [User] The project owner (already loaded)
  # @param old_level [String] The badge level that will be lost
  # @param badge_suffix [String] URL suffix for badge image ('badge' or 'baseline')
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
  def warn_owner_with_user(project, user, old_level, badge_suffix)
    return if project.nil? || project.id.nil?
    return if user.nil?
    return unless user.deliverable_email?

    @project = project
    @project_info_url =
      project_url(@project, locale: user.preferred_locale.to_sym)
    @email_destination = user.email
    @old_level = old_level
    @badge_suffix = badge_suffix
    @effective_date = project.badge_warning_effective_date
    @hostname = ENV.fetch('PUBLIC_HOSTNAME', 'localhost')
    set_standard_headers
    I18n.with_locale(user.preferred_locale.to_sym) do
      mail(
        to: @email_destination,
        template_name: 'warned_level',
        subject: t('report_mailer.subject_warned_level',
                   old_level: old_level).strip
      )
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

  # Create reminder email to inactive badge entry owner
  # @param project [Project] The project for which to send a reminder
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
  def email_reminder_owner(project)
    return if project.nil? || project.id.nil? || project.user_id.nil?

    @project = project
    user = User.find(project.user_id)
    return if user.nil?
    return unless user.email?
    return if user.email.exclude?('@')

    # Security: Only send reminders to users who have notifications enabled
    return unless user.notification_emails?

    @project_info_url =
      project_url(@project, locale: user.preferred_locale.to_sym)
    @email_destination = user.email

    # Security: Generate unsubscribe URL for this email
    @unsubscribe_url = generate_unsubscribe_url(user.email, locale: user.preferred_locale.to_sym)

    set_standard_headers
    I18n.with_locale(user.preferred_locale.to_sym) do
      mail(
        to: @email_destination,
        # bcc: REPORT_EMAIL_DESTINATION, # This would bcc individual reminders
        subject: t('report_mailer.subject_reminder').strip
      )
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

  # Report on reminders sent.  This is internal, so we haven't bothered
  # to internationalize this.
  # @param projects [Array<Project>] List of projects that were sent reminders
  def report_reminder_summary(projects)
    @report_destination = REPORT_EMAIL_DESTINATION
    return if projects.nil?

    @projects = projects
    set_standard_headers
    I18n.with_locale(I18n.default_locale) do
      mail(
        to: @report_destination,
        subject: 'Summary of reminders sent'
      )
    end
  end

  # Generate monthly announcement, but only if there's a destination
  # email address environment variable REPORT_MONTHLY_EMAIL
  # We currently only send these out in English, so it's not internationalized
  # (no point in asking the translators to do unnecessary work).
  def report_monthly_announcement(
    projects,
    month_display,
    last_stat_in_prev_month,
    last_stat_in_prev_prev_month
  )
    @report_destination = ENV.fetch('REPORT_MONTHLY_EMAIL', nil)
    return if @report_destination.blank?

    @projects = projects
    @month_display = month_display
    @last_stat_in_prev_month = last_stat_in_prev_month
    @last_stat_in_prev_prev_month = last_stat_in_prev_prev_month
    @hostname = ENV.fetch('PUBLIC_HOSTNAME', 'localhost')
    set_standard_headers
    I18n.with_locale(I18n.default_locale) do
      mail(
        to: @report_destination,
        subject: 'Projects that received badges (monthly summary)'
      )
    end
  end

  # Email user when they add a new project.
  # @param project [Project] The newly created project to send welcome email for
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
  def email_new_project_owner(project)
    return if project.nil? || project.id.nil? || project.user_id.nil?

    @project = project
    user = User.find(project.user_id)
    return if user.nil?
    return unless user.email?
    return if user.email.exclude?('@')

    @project_info_url =
      project_url(@project, locale: user.preferred_locale.to_sym)
    @email_destination = user.email
    set_standard_headers
    I18n.with_locale(user.preferred_locale.to_sym) do
      mail(
        to: @email_destination,
        subject: t('report_mailer.subject_new_project').strip
      )
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

  # Report if a project is deleted.  "deletion_rationale" is untrusted
  # data from a user.
  # @param project [Project] The project that was deleted
  # @param user [User] The user who deleted the project
  # @param deletion_rationale [String] User-provided reason for deletion
  def report_project_deleted(project, user, deletion_rationale)
    @report_destination = REPORT_EMAIL_DESTINATION
    @project = project
    @user = user
    @deletion_rationale = deletion_rationale
    set_standard_headers
    I18n.with_locale(I18n.default_locale) do
      mail(
        to: @report_destination,
        subject: t(
          'report_mailer.subject_project_deleted',
          project_id: project.id, project_name: project.name
        ).strip
      )
    end
  end
end
# rubocop:enable Metrics/MethodLength, Metrics/ClassLength
