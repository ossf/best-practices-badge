# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Adds fields to support badge-loss email notifications:
#
# users.important_notifications - user opt-out for high-priority notifications
#   (e.g. "your badge was lost due to changed requirements"). Defaults true.
#   Distinct from notification_emails (which covers reminder emails).
#   If false, loss notifications are silently drained without sending email.
#
# projects.unreported_badge_loss - rank (1-3) of the metal badge level that was
#   lost but not yet notified. 0 = no pending notification (NOT NULL DEFAULT 0).
#   Set by update_all_badge_percentages; cleared by badge_loss_notifications task.
#
# projects.unreported_baseline_badge_loss - same, for the baseline series.
#
# projects.last_loss_sent_at - datetime of the most recent loss notification
#   sent (or silently drained) for this project. NULL = never notified.
#
# Partial indexes cover only the non-zero rows, keeping index size minimal
# since the vast majority of projects will have 0 in both columns.
class AddBadgeLossNotificationFields < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :important_notifications, :boolean,
               null: false, default: true

    add_column :projects, :unreported_badge_loss, :integer,
               null: false, default: 0
    add_column :projects, :unreported_baseline_badge_loss, :integer,
               null: false, default: 0
    add_column :projects, :last_loss_sent_at, :datetime

    add_index :projects, :unreported_badge_loss,
              where: 'unreported_badge_loss > 0',
              name: 'index_projects_on_unreported_badge_loss'
    add_index :projects, :unreported_baseline_badge_loss,
              where: 'unreported_baseline_badge_loss > 0',
              name: 'index_projects_on_unreported_baseline_badge_loss'
  end
end
