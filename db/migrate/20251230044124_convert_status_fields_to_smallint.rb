# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

class ConvertStatusFieldsToSmallint < ActiveRecord::Migration[8.1]
  using SymbolRefinements

  def up
    # Get all status field names from Criteria
    status_fields = Criteria.all.map(&:status)

    # Also include achievement status fields
    achievement_fields = %i[achieve_passing_status achieve_silver_status]

    all_fields = (status_fields + achievement_fields).uniq

    say_with_time "Converting #{all_fields.size} status fields to smallint" do
      all_fields.each_with_index do |field, index|
        say "Converting #{field} (#{index + 1}/#{all_fields.size})", :subitem

        # Step 1: Drop existing default value (required for type change)
        change_column_default :projects, field, from: '?', to: nil

        # Step 2: Convert column type with data transformation
        # Use explicit CASE for each value to ensure correct conversion
        execute <<-SQL
          ALTER TABLE projects
          ALTER COLUMN "#{field}"
          TYPE smallint
          USING (
            CASE "#{field}"
              WHEN '?' THEN 0
              WHEN 'Unmet' THEN 1
              WHEN 'N/A' THEN 2
              WHEN 'Met' THEN 3
              ELSE 0
            END
          )
        SQL

        # Step 3: Set new default value
        change_column_default :projects, field, from: nil, to: 0

        # Add check constraint
        execute <<-SQL
          ALTER TABLE projects
          ADD CONSTRAINT check_#{field}_range
          CHECK ("#{field}" >= 0 AND "#{field}" <= 3)
        SQL
      end
    end
  end

  def down
    status_fields = Criteria.all.map(&:status)
    achievement_fields = %i[achieve_passing_status achieve_silver_status]
    all_fields = (status_fields + achievement_fields).uniq

    say_with_time "Converting #{all_fields.size} status fields back to varchar" do
      all_fields.each_with_index do |field, index|
        say "Converting #{field} (#{index + 1}/#{all_fields.size})", :subitem

        # Step 1: Drop check constraint
        execute <<-SQL
          ALTER TABLE projects
          DROP CONSTRAINT IF EXISTS check_#{field}_range
        SQL

        # Step 2: Drop existing default value (required for type change)
        change_column_default :projects, field, from: 0, to: nil

        # Step 3: Convert back to varchar
        # Use explicit CASE for each value to ensure correct reverse conversion
        execute <<-SQL
          ALTER TABLE projects
          ALTER COLUMN "#{field}"
          TYPE varchar
          USING (
            CASE "#{field}"
              WHEN 0 THEN '?'
              WHEN 1 THEN 'Unmet'
              WHEN 2 THEN 'N/A'
              WHEN 3 THEN 'Met'
              ELSE '?'
            END
          )
        SQL

        # Step 4: Set default value back
        change_column_default :projects, field, from: nil, to: '?'
      end
    end
  end
end
