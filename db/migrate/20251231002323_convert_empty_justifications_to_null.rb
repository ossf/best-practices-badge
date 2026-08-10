# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

class ConvertEmptyJustificationsToNull < ActiveRecord::Migration[8.1]
  using SymbolRefinements

  def up
    # Get all justification field names from Criteria
    justification_fields = Criteria.all.map(&:justification)

    say_with_time "Converting #{justification_fields.size} justification fields: empty strings to NULL" do
      justification_fields.each_with_index do |field, index|
        say "Converting #{field} (#{index + 1}/#{justification_fields.size})", :subitem

        # Convert empty strings to NULL
        execute <<-SQL.squish
          UPDATE projects
          SET "#{field}" = NULL
          WHERE "#{field}" = ''
        SQL
      end
    end
  end

  def down
    # Get all justification field names from Criteria
    justification_fields = Criteria.all.map(&:justification)

    say_with_time "Converting #{justification_fields.size} justification fields: NULL to empty strings" do
      justification_fields.each_with_index do |field, index|
        say "Converting #{field} (#{index + 1}/#{justification_fields.size})", :subitem

        # This would Convert NULL back to empty strings, but it would do it
        # everywhere.
        # execute <<-SQL
        #   UPDATE projects
        #   SET "#{field}" = ''
        #   WHERE "#{field}" IS NULL
        # SQL
      end
    end
  end
end
