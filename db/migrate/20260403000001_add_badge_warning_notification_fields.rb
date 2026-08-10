# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Adds fields to support badge-warning email notifications.
# Warnings are sent before criteria changes take effect, giving projects
# time to update their badge entries before actually losing a badge.
#
# projects.unreported_badge_warning - rank (1-3) of the metal badge level that
#   WILL BE lost when the new criteria take effect, but has not yet been
#   notified. 0 = no pending warning. NOT NULL DEFAULT 0.
#   Set by update_all_badge_warnings; cleared by badge_warning_notifications.
#
# projects.unreported_baseline_badge_warning - same, for the baseline series.
#
# projects.last_warning_sent_at - datetime of the most recent warning
#   notification sent (or silently drained) for this project. NULL = never.
#
# projects.badge_warning_effective_date - date when the criteria change takes
#   effect (i.e. when the badge will actually be lost). Shown in the email.
#   Shared by both the metal and baseline warning columns.
#
# Partial indexes cover only non-zero rows (vast majority will be 0).
class AddBadgeWarningNotificationFields < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :unreported_badge_warning, :integer,
               null: false, default: 0
    add_column :projects, :unreported_baseline_badge_warning, :integer,
               null: false, default: 0
    add_column :projects, :last_warning_sent_at, :datetime
    add_column :projects, :badge_warning_effective_date, :date

    add_index :projects, :unreported_badge_warning,
              where: 'unreported_badge_warning > 0',
              name: 'index_projects_on_unreported_badge_warning'
    add_index :projects, :unreported_baseline_badge_warning,
              where: 'unreported_baseline_badge_warning > 0',
              name: 'index_projects_on_unreported_baseline_badge_warning'
  end
end
