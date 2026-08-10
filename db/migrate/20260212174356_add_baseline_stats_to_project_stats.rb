# frozen_string_literal: true

# Copyright the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Add baseline badge series statistics to project_stats.
# These track daily progress of projects toward baseline-1/2/3 badges,
# paralleling the existing metal series stats (percent_1_ge_*, percent_2_ge_*).
class AddBaselineStatsToProjectStats < ActiveRecord::Migration[7.2]
  def change
    # rubocop:disable Rails/SchemaComment
    change_table :project_stats, bulk: true do |t|
      # Baseline level 1
      t.integer :percent_baseline_1_ge_25
      t.integer :percent_baseline_1_ge_50
      t.integer :percent_baseline_1_ge_75
      t.integer :percent_baseline_1_ge_90
      t.integer :percent_baseline_1_ge_100

      # Baseline level 2
      t.integer :percent_baseline_2_ge_25
      t.integer :percent_baseline_2_ge_50
      t.integer :percent_baseline_2_ge_75
      t.integer :percent_baseline_2_ge_90
      t.integer :percent_baseline_2_ge_100

      # Baseline level 3
      t.integer :percent_baseline_3_ge_25
      t.integer :percent_baseline_3_ge_50
      t.integer :percent_baseline_3_ge_75
      t.integer :percent_baseline_3_ge_90
      t.integer :percent_baseline_3_ge_100
    end
    # rubocop:enable Rails/SchemaComment
  end
end
