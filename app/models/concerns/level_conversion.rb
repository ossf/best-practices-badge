# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Shared module for converting between criteria level names and numbers
# Used by both Project and Criteria models for consistent level handling
module LevelConversion
  # Convert level name to number for comparison and conditional logic
  # Baseline levels map to numeric values for ordering purposes
  # @param level [String, Integer] level name or number
  # @return [Integer] numeric level for comparison
  # rubocop:disable Lint/DuplicateBranch
  def level_to_number(level)
    case level.to_s
    when '0', 'passing' then 0
    when '1', 'silver' then 1
    when 'baseline-1' then 1  # Baseline-1 roughly equivalent to silver
    when '2', 'gold' then 2
    when 'baseline-2' then 2  # Baseline-2 roughly equivalent to gold
    when 'baseline-3' then 3  # Baseline-3 is highest
    else
      level.to_i # Fallback for unknown levels
    end
  end
  # rubocop:enable Lint/DuplicateBranch
end
