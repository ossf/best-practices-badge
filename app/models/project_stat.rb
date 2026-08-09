# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# rubocop:disable Metrics/ClassLength
class ProjectStat < ApplicationRecord
  # Percentage values that we record as statistics.
  # We only record percentage "0" for level 0 (passing),
  # because *all* projects meet at least percentage 0 by definition.
  # Level 0, percentage 0 *is* stored - it's the total count of all projects.
  # You can loop over these like this:
  # # ProjectStat::STAT_VALUES.each do |percentage|
  # # # next if !level.zero? && percentage.zero?
  STAT_VALUES = %w[0 25 50 75 90 100].freeze

  # Percentage values *without* "0"
  # rubocop:disable Style/MethodCalledOnDoEndBlock
  STAT_VALUES_GT0 = STAT_VALUES.select do |e|
    e.to_i.positive?
  end.freeze
  STAT_VALUES_GT25 = STAT_VALUES.select do |e|
    e.to_i > 25
  end.freeze
  # rubocop:enable Style/MethodCalledOnDoEndBlock

  # Badge level identifiers as integers (0=passing, 1=silver, 2=gold)
  # Derived from Sections::METAL_LEVEL_NAMES so adding a level auto-propagates.
  BADGE_LEVELS = (0..(Sections::METAL_LEVEL_NAMES.length - 1))

  # Baseline badge level identifiers (1=baseline-1, 2=baseline-2, 3=baseline-3)
  # Derived from Sections::BASELINE_LEVEL_NAMES; new levels auto-propagate.
  BASELINE_BADGE_LEVELS = (1..Sections::BASELINE_LEVEL_NAMES.length)

  # NOTE: The constants below are for clarity.  Don't just change them,
  # or trend lines will be recording different cutoffs.
  # See below for their meaning.
  REACTIVATION_PERIOD = 14 # number of days from reminder to update.
  ACTIVE_PERIOD = 30 # number of days; an active project entries has an update

  before_create :stamp

  # Stamps (fills in) current aggregate values into this ProjectStat record.
  # Called automatically via before_create; wraps all DB reads in a transaction
  # to ensure a consistent snapshot.
  # @return [ProjectStat] self, to support method chaining
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/BlockLength
  def stamp
    # Use a transaction to get values from a single consistent point in time.
    Project.transaction do
      # Count projects at different levels of completion
      STAT_VALUES.each do |completion|
        public_send :"percent_ge_#{completion}=", Project.gteq(completion).count
        next if completion.to_i.zero? # Don't record percentage "0" > level 0

        public_send :"percent_1_ge_#{completion}=",
                    Project.where(badge_percentage_1: completion.to_i..).count
        public_send :"percent_2_ge_#{completion}=",
                    Project.where(badge_percentage_2: completion.to_i..).count
      end
      stamp_baseline_stats
      self.projects_edited = Project.where('created_at < updated_at').count

      # These use 1.day.ago, so a create or updates in 24 hours + fractional
      # seconds won't be counted today, and *might* not be counted previously.
      # This isn't important enough to solve.
      self.created_since_yesterday = Project.created_since(1.day.ago).count

      # Exclude newly-created records from updated_since count
      self.updated_since_yesterday = Project.updated_since(1.day.ago).count -
                                     created_since_yesterday

      # Record the number of reminders sent within the day.
      self.reminders_sent =
        Project.where('last_reminder_at > ?', 1.day.ago).count

      # If an inactive project becomes active within REACTIVATION_PERIOD
      # number of days after a reminder, the reminder is likely to be the
      # cause.  Record the number of such projects.
      self.reactivated_after_reminder =
        Project.where('last_reminder_at > ?', REACTIVATION_PERIOD.day.ago)
               .where('updated_at > ?', REACTIVATION_PERIOD.day.ago).count

      # Record the number of active project badge entries
      # (the number of project badge entries updated
      # within ACTIVE_PERIOD number of days)
      self.active_projects = Project.updated_since(ACTIVE_PERIOD.day.ago).count
      self.active_edited_projects =
        Project.updated_since(ACTIVE_PERIOD.day.ago)
               .where('created_at < updated_at').count
      self.active_in_progress =
        Project.updated_since(ACTIVE_PERIOD.day.ago)
               .where('badge_percentage_0 < 100').count
      self.active_edited_in_progress =
        Project.updated_since(ACTIVE_PERIOD.day.ago)
               .where('created_at < updated_at')
               .where('badge_percentage_0 < 100').count

      # The following nested transaction is defensive coding.
      # We don't need to use a nested transaction today, because Project and
      # User are implemented in a single database.  However, we ever
      # implemented Project and User in multiple class-specific databases
      # in the future, and did not nest them, we would silently be
      # outside a transaction - and that bug would be hard to detect. See:
      # http://api.rubyonrails.org/classes/ActiveRecord/Transactions/
      # ClassMethods.html
      User.transaction do
        # Some of these values can be calculated from others, but it's
        # convenient to provide them separately.
        self.users = User.count
        self.github_users = User.where(provider: 'github').count
        self.local_users = User.where(provider: 'local').count
        self.users_created_since_yesterday = User.created_since(1.day.ago).count
        self.users_updated_since_yesterday = User.updated_since(1.day.ago).count
        self.users_with_projects = Project.select(:user_id).distinct.count
        self.users_without_projects = users - users_with_projects
        self.users_with_multiple_projects =
          Project.unscoped.group(:user_id).having('count(*) > 1').count.length
        self.users_with_passing_projects =
          Project.select(:user_id)
                 .where('badge_percentage_0 >= 100')
                 .distinct.count
        self.users_with_silver_projects =
          Project.select(:user_id)
                 .where('badge_percentage_1 >= 100')
                 .distinct.count
        self.users_with_gold_projects =
          Project.select(:user_id)
                 .where('badge_percentage_2 >= 100')
                 .distinct.count
      end
      AdditionalRight.transaction do
        self.additional_rights_entries = AdditionalRight.count
        self.projects_with_additional_rights =
          AdditionalRight.select(:project_id).distinct.count
        self.users_with_additional_rights =
          AdditionalRight.select(:user_id).distinct.count
      end
    end

    self # Return self to support method chaining
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/BlockLength

  # Return the last ProjectStat value available in the month of "date";
  # returns nil if no ProjectStat is available in that month.
  # Note that created_at is an index, so this should be extremely fast.
  def self.last_in_month(query_date)
    ProjectStat
      .where(created_at: query_date.beginning_of_month..)
      .where(created_at: ..query_date.end_of_month)
      .reorder(:created_at).last
  end

  # Return the name of the field for a given level 0..2
  # and percentage (as an integer: 0, 25, 50, 75, 90, or 100).
  # E.g., given level 1 and percentage 50, return "percent_1_ge_50".
  # The methods for handling percentage levels in stats are in this
  # class, because this is the class responsible for them.
  def self.percent_field_name(level, percentage)
    level = level.to_i # Force integer representation
    if level.zero?
      "percent_ge_#{percentage}"
    else
      "percent_#{level}_ge_#{percentage}"
    end
  end

  # Return human-readable name of the field for a given level 0..2
  # and percentage.
  # They aren't internationalized, since they're used in
  # system reports instead of user interaction.
  # rubocop:disable Metrics/MethodLength
  def self.percent_field_description(level, percentage)
    return "Bad level #{level}" if Project::LEVEL_IDS.exclude?(level.to_s)

    level_i = level.to_i
    percentage_i = percentage.to_i
    if level_i.zero? && percentage_i.zero?
      'Total Projects'
    elsif percentage_i == 100
      "#{I18n.t("projects.form_early.level.#{level}")} Projects"
    elsif level_i.zero?
      "In Progress Projects #{percentage}%+"
    else
      level_name = I18n.t("projects.form_early.level.#{level}")
      prev_name = I18n.t("projects.form_early.level.#{level_i - 1}")
      "#{prev_name} Projects, #{percentage}%+ to #{level_name}"
    end
  end
  # rubocop:enable Metrics/MethodLength

  # Return the name of the field for a given baseline level 1..3
  # and percentage (as an integer: 25, 50, 75, 90, or 100).
  # E.g., given level 2 and percentage 50, return "percent_baseline_2_ge_50".
  def self.baseline_percent_field_name(level, percentage)
    "percent_baseline_#{level.to_i}_ge_#{percentage}"
  end

  # Return human-readable name of the baseline field for a given level 1..3
  # and percentage. Not internationalized (used in system reports).
  # rubocop:disable Metrics/MethodLength
  def self.baseline_percent_field_description(level, percentage)
    level_i = level.to_i
    percentage_i = percentage.to_i
    if BASELINE_BADGE_LEVELS.exclude?(level_i)
      return "Bad baseline level #{level}"
    end

    level_name = I18n.t("projects.form_early.level.baseline-#{level_i}")
    if percentage_i == 100
      "#{level_name} Projects"
    elsif level_i == 1
      "#{percentage}%+ to #{level_name}"
    else
      prev_name = I18n.t("projects.form_early.level.baseline-#{level_i - 1}")
      "#{prev_name} Projects, #{percentage}%+ to #{level_name}"
    end
  end
  # rubocop:enable Metrics/MethodLength

  private

  # Stamp baseline badge statistics for all three baseline levels.
  # For partial percentages (<100%), counts are independent per level.
  # For 100%, we require all lower baseline levels to also be at 100%,
  # since a project shouldn't count as completing baseline-3 without
  # having completed baseline-1 and baseline-2.
  def stamp_baseline_stats
    BASELINE_BADGE_LEVELS.each do |bl|
      STAT_VALUES_GT0.each do |completion|
        public_send :"percent_baseline_#{bl}_ge_#{completion}=",
                    baseline_count(bl, completion.to_i)
      end
    end
  end

  # Count projects at or above a threshold for a given baseline level.
  # At 100%, also requires all lower baseline levels to be at 100%.
  def baseline_count(level, threshold)
    query = Project.where("badge_percentage_baseline_#{level}": threshold..)
    if threshold >= 100
      (1...level).each do |lower|
        query = query.where("badge_percentage_baseline_#{lower}": 100..)
      end
    end
    query.count
  end
end
# rubocop:enable Metrics/ClassLength
