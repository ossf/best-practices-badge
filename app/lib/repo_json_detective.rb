# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'json'

# RepoJsonDetective reads and validates .bestpractices.json files from
# repositories. Projects can self-declare criterion statuses by placing
# this file in their repo root or .project.d/ directory.
#
# File format: JSON with field names as keys (e.g., "contribution_status")
# Status values must be text: "Met", "Unmet", "N/A" (case-insensitive)
# Justification fields are optional but recommended with status fields.
#
# SECURITY: the .bestpractices.json file is untrusted data (the repo owner
# controls it). Defenses, so this stays easy to reason about:
#
# DoS / oversized file:
#   get_content fetches at most MAX_FILE_SIZE bytes (GitHub's reported size is
#   checked first, so oversized files are skipped without downloading).
#
# JSON parser abuse:
#   JSON.parse enforces its default max_nesting (100), so a deeply nested file
#   cannot exhaust the stack; combined with the size cap, parse work is
#   bounded. JSON.parse also validates UTF-8 and raises on malformed input,
#   which we rescue.
#
# Type confusion:
#   Only a JSON *object* is meaningful here. We reject any other top-level
#   value (array, string, number, bool, null) up front, so keys are always
#   strings and every value is type-checked (is_a?(String)) before use. This
#   makes the detective safe on its own, not only because Chief happens to
#   rescue detective exceptions.
#
# Injection / stored-value abuse:
#   Field names are whitelisted against PROJECT_PERMITTED_FIELDS, statuses are
#   parsed to a fixed enum, justification length is bounded, and the results
#   are stored in plain text columns rendered through auto-escaping ERB. No
#   SQL is built from this data.
class RepoJsonDetective < Detective
  INPUTS = [:repo_files].freeze
  # OUTPUTS is dynamic based on JSON content, but we must declare it for Chief
  # In practice, this detective can output any criterion status/justification field
  OUTPUTS = [].freeze # Dynamically determined from JSON
  OVERRIDABLE_OUTPUTS = [].freeze # All outputs are overridable at confidence 3.5

  # File locations to check (in order)
  FILE_LOCATIONS = ['.bestpractices.json', '.project.d/bestpractices.json'].freeze
  MAX_FILE_SIZE = 100_000 # 100 KB

  def analyze(_evidence, current)
    repo_files = current[:repo_files]
    return {} if repo_files.blank?

    # Try to read JSON from one of the file locations
    json_data = read_and_parse_json(repo_files)
    # Only a JSON object is meaningful; reject any other top-level value
    # (array, string, number, bool, null) so keys are always strings and
    # every value is type-checked before use. This also covers nil (no file
    # or parse error). See the SECURITY notes above.
    return {} unless json_data.is_a?(Hash)

    # Validate and convert to changeset
    validate_and_convert_fields(json_data)
  end

  private

  # Read JSON from first available file location
  # rubocop:disable Metrics/MethodLength
  def read_and_parse_json(repo_files)
    FILE_LOCATIONS.each do |path|
      content = repo_files.get_content(path, max_size: MAX_FILE_SIZE)
      next if content.blank?

      # JSON.parse will validate UTF-8 encoding and raise exception if invalid
      return JSON.parse(content)
    rescue JSON::ParserError => e
      Rails.logger.info("Invalid JSON in #{path}: #{e.message}")
      return nil
    rescue ArgumentError, EncodingError => e
      # Invalid encoding (JSON.parse checks UTF-8)
      Rails.logger.info("Invalid encoding in #{path}: #{e.message}")
      return nil
    end
    nil
  end
  # rubocop:enable Metrics/MethodLength

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def validate_and_convert_fields(json_data)
    results = {}
    processed_justifications = Set.new

    # First pass: process status fields
    json_data.each do |key, value|
      field_sym = CriterionFieldValidator.validate_field_name(key)
      next unless field_sym && CriterionFieldValidator.status_field?(field_sym)

      parsed = CriterionFieldValidator.parse_status_value(value)
      next if parsed.nil? # Ignores '?', empty, and invalid

      # Get corresponding justification from JSON if present
      just_field = CriterionFieldValidator.status_to_justification_field(field_sym)
      json_justification = json_data[just_field.to_s]
      validated_just = json_justification ? CriterionFieldValidator.validate_justification(json_justification) : nil

      results[field_sym] = {
        value: parsed[:value],
        confidence: 3.5,
        explanation: validated_just || I18n.t('detectives.repo_json.field_from_file')
      }

      processed_justifications.add(just_field) # Mark as handled
    end

    # Second pass: standalone justifications (no corresponding status)
    # Can't be combined with first pass - needs to process statuses first
    # rubocop:disable Style/CombinableLoops
    json_data.each do |key, value|
      field_sym = CriterionFieldValidator.validate_field_name(key)
      next unless field_sym && CriterionFieldValidator.justification_field?(field_sym)
      next if processed_justifications.include?(field_sym) # Already handled

      validated_text = CriterionFieldValidator.validate_justification(value)
      next if validated_text.nil?

      results[field_sym] = {
        value: validated_text,
        confidence: 3.5,
        explanation: I18n.t('detectives.repo_json.field_from_file')
      }
    end
    # rubocop:enable Style/CombinableLoops

    results
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
end
