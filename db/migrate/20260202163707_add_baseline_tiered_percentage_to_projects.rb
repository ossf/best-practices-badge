# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Add baseline_tiered_percentage field to projects table.
# This is analogous to tiered_percentage for metal badges:
# - 0-99: working on baseline-1
# - 100-199: passed baseline-1, working on baseline-2
# - 200-299: passed baseline-1 & 2, working on baseline-3
# - 300: completed all three baseline levels
class AddBaselineTieredPercentageToProjects < ActiveRecord::Migration[8.1]
  def up
    add_column :projects, :baseline_tiered_percentage, :integer,
               comment: 'Tiered percentage for baseline series (0-300)'
    add_index :projects, :baseline_tiered_percentage

    # Backfill the baseline_tiered_percentage for all existing projects
    # rubocop:disable Rails/SkipsModelValidations
    say_with_time 'Backfilling baseline_tiered_percentage' do
      Project.find_each do |project|
        # Skip validations for performance; we're computing from existing data
        project.update_column(:baseline_tiered_percentage,
                              project.compute_baseline_tiered_percentage)
      end
    end
    # rubocop:enable Rails/SkipsModelValidations
  end

  def down
    remove_index :projects, :baseline_tiered_percentage
    remove_column :projects, :baseline_tiered_percentage
  end
end
