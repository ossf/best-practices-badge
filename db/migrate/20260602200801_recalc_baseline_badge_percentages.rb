# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

class RecalcBaselineBadgePercentages < ActiveRecord::Migration[8.1]
  def change
    # This migration originally called Project.update_all_badge_percentages,
    # but it crashed in staging due to validation errors on existing data.
    # It has been made a no-op here to protect production; the work is now
    # handled by the subsequent 'fixed' migration.
  end
end
