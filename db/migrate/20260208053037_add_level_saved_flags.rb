# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Migration to add level-specific "saved" flags to projects table.
# These flags track whether a user has edited/saved each badge level,
# allowing us to skip automation on subsequent edits (performance optimization).
class AddLevelSavedFlags < ActiveRecord::Migration[8.1]
  def up
    # Add saved flags for all badge levels
    add_column :projects, :passing_saved, :boolean, default: false, null: false
    add_column :projects, :silver_saved, :boolean, default: false, null: false
    add_column :projects, :gold_saved, :boolean, default: false, null: false
    add_column :projects, :baseline_1_saved, :boolean, default: false, null: false
    add_column :projects, :baseline_2_saved, :boolean, default: false, null: false
    add_column :projects, :baseline_3_saved, :boolean, default: false, null: false

    # Backfill: Mark levels as saved if they have non-'?' criteria filled
    # This prevents re-running automation on mature projects
    backfill_saved_flags
  end

  def down
    remove_column :projects, :baseline_3_saved
    remove_column :projects, :baseline_2_saved
    remove_column :projects, :baseline_1_saved
    remove_column :projects, :gold_saved
    remove_column :projects, :silver_saved
    remove_column :projects, :passing_saved
  end

  private

  # Backfill saved flags based on existing data.
  # If a project has >10% of level-specific criteria filled,
  # mark that level as already saved (skip automation on next edit).
  # Use >10% threshold to avoid false positives from overlapping criteria.
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def backfill_saved_flags
    # For metal levels: use badge_percentage as heuristic
    # If percentage > 10, user has clearly edited this level
    Project.where('badge_percentage_0 > ?', 10).update_all(passing_saved: true)
    Project.where('badge_percentage_1 > ?', 10).update_all(silver_saved: true)
    Project.where('badge_percentage_2 > ?', 10).update_all(gold_saved: true)

    # For baseline levels: check if any osps_ criteria are filled
    # This is more complex since baseline criteria have osps_ prefix
    baseline_criteria_names = Criteria.all.select do |c|
      c.name.start_with?('osps_')
    end.map(&:name)

    return if baseline_criteria_names.empty?

    # Check each baseline level
    backfill_baseline_level('baseline-1', :baseline_1_saved,
                           baseline_criteria_names)
    backfill_baseline_level('baseline-2', :baseline_2_saved,
                           baseline_criteria_names)
    backfill_baseline_level('baseline-3', :baseline_3_saved,
                           baseline_criteria_names)
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  # Mark baseline level as saved if any level-specific criteria are filled
  def backfill_baseline_level(level_name, flag_name, all_baseline_names)
    # Get criteria specific to this baseline level
    level_criteria = Criteria.active(level_name).map(&:name)
    baseline_level_names = level_criteria & all_baseline_names

    return if baseline_level_names.empty?

    # Build SQL to check if any of these criteria have non-'?' values
    conditions = baseline_level_names.map do |name|
      status_field = "#{name}_status"
      "(#{status_field} IS NOT NULL AND #{status_field} != '?')"
    end.join(' OR ')

    Project.where(conditions).update_all(flag_name => true)
  end
end
