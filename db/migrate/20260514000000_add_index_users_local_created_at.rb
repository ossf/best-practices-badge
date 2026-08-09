# frozen_string_literal: true

# Copyright 2026 the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Adds a partial index on users.created_at covering only local accounts.
# This supports the daily purge of never-activated local accounts without
# a full table scan, consistent with the existing email_local_unique_bidx
# partial index pattern.
class AddIndexUsersLocalCreatedAt < ActiveRecord::Migration[8.0]
  def change
    add_index :users, :created_at,
              where: "provider = 'local'",
              name: 'index_users_on_created_at_local'
  end
end
