# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# CriterionStatus provides constants and conversion methods for
# criterion status values. Status values are stored as smallint (0-3)
# in the database but presented as strings ('?', 'Unmet', 'N/A', 'Met')
# in the external API for backward compatibility and easier understanding.
#
# This module centralizes the integer-to-string mapping for all status fields,
# enabling memory and storage optimization while maintaining API compatibility.
#
# Integer values are chosen for natural ordering:
# - 0: Unknown (?)
# - 1: Unmet
# - 2: N/A (Not Applicable)
# - 3: Met - selected as "3" so a 1-bit error can't convert Unknown to Met
#
# Usage:
#   CriterionStatus::MET              # => 3
#   CriterionStatus::STATUS_VALUES[3] # => 'Met'
#   CriterionStatus::STATUS_BY_NAME['Met'] # => 3
#   CriterionStatus.parse('met')      # => 3
#   CriterionStatus.parse('n/a')      # => 2
#   CriterionStatus.canonical(2)      # => 'N/A'
module CriterionStatus
  # Array mapping integer values to their string representations
  # Index = integer value, Value = string name
  # This is the single source of truth - all other constants are derived from it
  STATUS_VALUES = [
    '?',     # 0: UNKNOWN
    'Unmet', # 1: UNMET
    'N/A',   # 2: NA
    'Met'    # 3: MET
  ].freeze

  # Hash mapping string names to their integer values
  # Derived from STATUS_VALUES - used for converting incoming string parameters
  # rubocop:disable Style/MethodCalledOnDoEndBlock
  STATUS_BY_NAME = STATUS_VALUES.each_with_index.to_h do |name, index|
    [name, index]
  end.freeze
  # rubocop:enable Style/MethodCalledOnDoEndBlock

  # Integer constants for status values (derived from STATUS_BY_NAME)
  # These are the canonical values stored in the database
  UNKNOWN = STATUS_BY_NAME['?'] # 0
  UNMET = STATUS_BY_NAME['Unmet'] # 1
  NA = STATUS_BY_NAME['N/A'] # 2
  MET = STATUS_BY_NAME['Met'] # 3

  # Parse a status value string to its integer representation.
  # Accepts multiple formats for flexibility (query params, JSON, user input).
  # @param value [String, Object] status value to parse
  # @return [Integer, nil] integer status (0-3) or nil if invalid
  # @example
  #   CriterionStatus.parse('met')     # => 3
  #   CriterionStatus.parse('Met')     # => 3
  #   CriterionStatus.parse('MET')     # => 3
  #   CriterionStatus.parse('n/a')     # => 2
  #   CriterionStatus.parse('na')      # => 2
  #   CriterionStatus.parse('N/A')     # => 2
  #   CriterionStatus.parse('unknown') # => 0
  #   CriterionStatus.parse('?')       # => 0
  #   CriterionStatus.parse('invalid') # => nil
  #   CriterionStatus.parse('')        # => nil
  def self.parse(value)
    return unless value.is_a?(String)

    normalized = value.strip.downcase
    return if normalized.empty?

    # Map various input formats to integer values
    case normalized
    when '?', 'unknown' then UNKNOWN
    when 'unmet' then UNMET
    when 'n/a', 'na' then NA
    when 'met' then MET
    end
  end

  # Get the canonical string representation for a status integer.
  # @param int_value [Integer] status integer (0-3)
  # @return [String, nil] canonical name ('?', 'Unmet', 'N/A', 'Met') or nil
  # @example
  #   CriterionStatus.canonical(3) # => 'Met'
  #   CriterionStatus.canonical(2) # => 'N/A'
  #   CriterionStatus.canonical(0) # => '?'
  def self.canonical(int_value)
    return unless int_value.is_a?(Integer) && int_value >= 0 && int_value < STATUS_VALUES.size

    STATUS_VALUES[int_value]
  end

  # Parse status value and convert to canonical string form.
  # For query string processing - accepts ALL values including "?" (user can reset).
  # @param value [String] status value string
  # @return [String, nil] canonical string or nil if invalid
  # @example
  #   CriterionStatus.canonicalize('met')   # => 'Met'
  #   CriterionStatus.canonicalize('n/a')   # => 'N/A'
  #   CriterionStatus.canonicalize('?')     # => '?'
  #   CriterionStatus.canonicalize('invalid') # => nil
  def self.canonicalize(value)
    int_value = parse(value)
    canonical(int_value)
  end

  # Parse status value and convert to canonical string, rejecting UNKNOWN.
  # For JSON automation - rejects "?" since it provides no automation value.
  # @param value [String] status value string
  # @return [String, nil] canonical string (Unmet/N/A/Met) or nil if invalid/unknown
  # @example
  #   CriterionStatus.canonicalize_for_automation('met')   # => 'Met'
  #   CriterionStatus.canonicalize_for_automation('n/a')   # => 'N/A'
  #   CriterionStatus.canonicalize_for_automation('?')     # => nil (ignored)
  #   CriterionStatus.canonicalize_for_automation('unknown') # => nil (ignored)
  def self.canonicalize_for_automation(value)
    int_value = parse(value)
    return if int_value.nil? || int_value == UNKNOWN

    canonical(int_value)
  end
end
