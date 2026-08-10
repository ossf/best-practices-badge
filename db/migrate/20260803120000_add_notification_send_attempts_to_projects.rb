# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Count delivery attempts for the two notification series, so that
# "retry tomorrow" cannot become "retry forever".  A permanently
# undeliverable address would otherwise fail every night indefinitely,
# recreating the incident in docs/warning_failures.md with a different
# cause.
#
# Two counters, not one, because the two series are independent and a
# project can be pending in both at once.  Two, not four, because metal
# and baseline already share a sent-at column apiece and are delivered
# to the same address in the same iteration, so a transient failure
# affects both identically.  If the series ever diverge, for instance by
# mailing different addresses, these must split too.
#
# PostgreSQL 11 and later add a NOT NULL DEFAULT column without
# rewriting the table, which matters on a projects table this wide and
# this busy.
class AddNotificationSendAttemptsToProjects < ActiveRecord::Migration[8.1]
  # bulk: true so both columns are added in one ALTER TABLE, taking the
  # lock on this busy table once rather than twice.
  def change
    change_table :projects, bulk: true do |t|
      t.column :loss_send_attempts, :integer,
               null: false, default: 0,
               comment: 'Failed attempts to deliver the pending ' \
                        'badge-loss notification; reset to 0 when a ' \
                        'loss is newly recorded'
      t.column :warning_send_attempts, :integer,
               null: false, default: 0,
               comment: 'Failed attempts to deliver the pending ' \
                        'badge-warning notification; reset to 0 when a ' \
                        'warning is newly recorded'
    end
  end
end
