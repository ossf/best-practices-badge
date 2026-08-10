# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# CriterionFieldValidator provides reusable validation logic for criterion
# fields. Used by detectives, controllers, and other components that need to
# validate status values and justification text.
module CriterionFieldValidator
  # Parse status value string to integer with canonical form conversion.
  # For JSON automation - rejects '?' and empty (no automation value).
  # Accepts: 'met', 'unmet', 'n/a', 'na' (case-insensitive)
  # Rejects: '?', 'unknown', empty strings
  # @param value [String] status value (must be string, not integer)
  # @return [Hash{Symbol => Object}, nil]
  #   {value: Integer, canonical: String} or nil if invalid/unknown
  def self.parse_status_value(value)
    return unless value.is_a?(String)

    stripped = value.strip
    return if stripped.empty?

    # Use shared CriterionStatus logic (rejects UNKNOWN for automation)
    canonical = CriterionStatus.canonicalize_for_automation(stripped)
    return unless canonical

    # Return both integer and canonical form for JSON processing
    { value: CriterionStatus.parse(stripped), canonical: canonical }
  end

  # Validate and sanitize justification text.
  # @param text [String] justification text
  # @return [String, nil] valid text or nil if invalid/empty
  def self.validate_justification(text)
    return unless text.is_a?(String)

    stripped = text.strip
    return if stripped.empty?
    return if stripped.length > Project::MAX_TEXT_LENGTH

    # No need to check UTF-8 - if text came from JSON.parse, it's already UTF-8
    stripped
  end

  # Check if field name is a valid criterion field.
  # @param field_name [String, Symbol] field name
  # @return [Symbol, nil] normalized field symbol or nil if invalid
  def self.validate_field_name(field_name)
    field_sym = field_name.to_sym
    field_sym if Project::PROJECT_PERMITTED_FIELDS.include?(field_sym)
  end

  # Check if field is a status field.
  # @param field_name [Symbol] field name
  # @return [Boolean]
  def self.status_field?(field_name)
    field_name.to_s.end_with?('_status')
  end

  # Check if field is a justification field.
  # @param field_name [Symbol] field name
  # @return [Boolean]
  def self.justification_field?(field_name)
    field_name.to_s.end_with?('_justification')
  end

  # Get corresponding justification field name for a status field.
  # @param status_field [Symbol] e.g., :contribution_status
  # @return [Symbol] e.g., :contribution_justification
  def self.status_to_justification_field(status_field)
    status_field.to_s.sub('_status', '_justification').to_sym
  end
end
