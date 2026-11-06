# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Persist broken-link warnings until delivery succeeds or the bounded
# retry policy gives up.
class AddBrokenLinkNotificationFields < ActiveRecord::Migration[8.1]
  def change
    change_table :projects, bulk: true do |t|
      t.text :pending_broken_link_notifications,
             null: false, default: '',
             comment: 'JSON payload for a broken-link warning awaiting delivery'
      t.integer :broken_link_notification_send_attempts,
                null: false, default: 0,
                comment: 'Failed attempts to deliver the pending broken-link warning'
    end
    add_index :projects, :id,
              where: "pending_broken_link_notifications <> ''",
              name: 'index_projects_on_pending_broken_link_notifications'
  end
end
