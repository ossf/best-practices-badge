# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

class AddNotNullToBaselineStatusFields < ActiveRecord::Migration[8.1]
  using SymbolRefinements

  def up
    # Get all status field names and filter for osps_ prefix
    all_status_fields = Criteria.all.map(&:status)
    baseline_fields = all_status_fields.select { |f| f.to_s.start_with?('osps_') }

    say_with_time "Adding NOT NULL constraint to #{baseline_fields.size} baseline status fields" do
      baseline_fields.each_with_index do |field, index|
        say "Adding NOT NULL to #{field} (#{index + 1}/#{baseline_fields.size})", :subitem

        # First ensure no NULL values exist (there shouldn't be any)
        # Convert any NULLs to 0 (unknown) just to be safe
        execute <<-SQL.squish
          UPDATE projects
          SET "#{field}" = 0
          WHERE "#{field}" IS NULL
        SQL

        # Add NOT NULL constraint
        change_column_null :projects, field, false
      end
    end
  end

  def down
    all_status_fields = Criteria.all.map(&:status)
    baseline_fields = all_status_fields.select { |f| f.to_s.start_with?('osps_') }

    say_with_time "Removing NOT NULL constraint from #{baseline_fields.size} baseline status fields" do
      baseline_fields.each_with_index do |field, index|
        say "Removing NOT NULL from #{field} (#{index + 1}/#{baseline_fields.size})", :subitem

        # Remove NOT NULL constraint
        change_column_null :projects, field, true
      end
    end
  end
end
