# frozen_string_literal: true

# Copyright the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Backfill baseline_N_saved flags using badge_percentage_baseline_N.
# The original backfill in AddLevelSavedFlags had two bugs:
# 1. Symbol/String mismatch in criteria name intersection (always empty)
# 2. Compared integer status columns to string '?' instead of integer 0
# As a result, baseline saved flags were never set for existing projects.
# This migration uses the same badge_percentage > 10 approach that works
# correctly for metal levels.
class BackfillBaselineSavedFlags < ActiveRecord::Migration[8.1]
  # rubocop:disable Rails/SkipsModelValidations
  def up
    Project.where('badge_percentage_baseline_1 > ?', 10)
           .update_all(baseline_1_saved: true)
    Project.where('badge_percentage_baseline_2 > ?', 10)
           .update_all(baseline_2_saved: true)
    Project.where('badge_percentage_baseline_3 > ?', 10)
           .update_all(baseline_3_saved: true)
  end
  # rubocop:enable Rails/SkipsModelValidations

  def down
    # No-op: we can't distinguish which flags were set by this migration
    # vs. set by normal user edits since the original migration ran.
  end
end
