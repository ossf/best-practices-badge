# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# SecurityInsightsDetective - infers badge criteria answers from a project's
# security-insights.yml file (OpenSSF Security Insights spec).
#
# The file is looked up in the repository root and .github/ directory.
# Mappings from security-insights fields to badge criteria are defined in
# criteria/security_insights_map.yml.  Entries with confidence: 0 are stripped
# at load time and never evaluated — they exist only as documentation of
# understood situations we deliberately do not act on.
# To refresh the # Target: criterion-text comments in that map file, run:
#   ruby script/update_security_insights_comments.rb
#
# SECURITY: The security-insights.yml file is untrusted data.  Here is a
# summary of how each threat category is mitigated:
#
# DoS / oversized file:
#   GithubContentAccess#get_content checks GitHub's *reported* file size first
#   and skips the content-fetch API call entirely if it exceeds MAX_SI_SIZE
#   (early stop — we never ask GitHub to send the bytes at all).  After the
#   fetch, actual bytesize is re-checked as defense in depth.  The Octokit gem
#   buffers the full response before returning, so true streaming early-stop is
#   not possible at this layer; the metadata pre-check is the primary control.
#
# YAML injection / object deserialization:
#   YAML.safe_load is called with permitted_classes: [] (no Ruby objects) and
#   aliases: false (prevents YAML anchor/alias bombs).
#
# ReDoS (regular-expression denial of service):
#   No regex is applied to untrusted data anywhere in this class.
#   The substring: true mapping flag uses String#include?, which is a plain
#   linear substring search — not a regex — so ReDoS is not possible.
#
# Type-confusion / unexpected exceptions from untrusted values:
#   Every untrusted value is guarded with is_a? before calling type-specific
#   methods.  Comparisons call .to_s first (handles nil, Integer, Array, Hash,
#   etc. without raising).  No exceptions are possible from malformed values.
#
# Trust boundary in value_matches? and find_matching_element:
#   All mapping fields that control matching behaviour (si_item_field, also,
#   substring, si_value, si_alternatives) come from the trusted MAPPINGS
#   constant loaded from the project's own map file.  Only the +value+ /
#   +element+ arguments carry untrusted SI data; they only ever reach
#   .to_s.downcase and String#== or String#include?, both of which are safe.
#
# Oversized comment injection:
#   Comment strings extracted from SI data are truncated to MAX_SI_COMMENT_SIZE
#   before being embedded in justification text, preventing a malicious file
#   from bloating stored justifications up to the 100 KB file cap.
#
# SQL / XSS injection:
#   No SQL is constructed from SI data. The explanation/justification string
#   is stored in a plain text column and rendered through Rails ERB templates,
#   which auto-escape HTML by default.
# rubocop:disable Metrics/ClassLength
class SecurityInsightsDetective < Detective
  # Maximum size of a security-insights file we will fetch and parse.
  # 100 KB is generous; real files are typically a few kilobytes.
  MAX_SI_SIZE = 100_000

  # Maximum length of a comment string extracted from the SI file to include
  # in a justification.  Prevents a malicious file from injecting an
  # arbitrarily long string into the stored criterion justification text.
  MAX_SI_COMMENT_SIZE = 2048

  # Candidate file paths to check, in priority order.
  SI_CANDIDATE_PATHS = %w[
    security-insights.yml
    SECURITY-INSIGHTS.yml
    .github/security-insights.yml
    .github/SECURITY-INSIGHTS.yml
  ].freeze

  # Load the mappings from security-insights to our criteria.
  # Screens out confidence=0 entries (documented no-ops) at load time so they
  # never appear in OUTPUTS or any detective logic.
  # Field-combination validation is performed at evaluation time by
  # validate_condition_fields!, which is called from condition_met?.
  MAPPINGS =
    YAML.safe_load_file(
      Rails.root.join('criteria/security_insights_map.yml'),
      permitted_classes: [],
      aliases: false
    )['mappings'].reject { |m| m['confidence'].to_f.zero? }.freeze

  INPUTS  = [:repo_files].freeze
  OUTPUTS = MAPPINGS.map { |m| :"#{m['target_criterion']}_status" }.uniq.freeze
  OVERRIDABLE_OUTPUTS = [].freeze

  # Analyze project's security-insights.yml file and propose criterion values.
  # @param _evidence [Evidence] unused
  # @param current [Hash] must contain :repo_files
  # @return [Hash] proposed criterion status changes
  def analyze(_evidence, current)
    repo_files = current[:repo_files]
    return {} if repo_files.blank?

    content, location = find_security_insights(repo_files)
    return {} if content.nil?

    si_data = parse_security_insights(content)
    return {} unless si_data.is_a?(Hash)

    evaluate_mappings(si_data, location)
  end

  private

  # Look for a security-insights file in the standard locations.
  # @param repo_files [GithubContentAccess] repo file accessor
  # @return [Array(String, String), nil] [content, path] or nil if not found
  def find_security_insights(repo_files)
    SI_CANDIDATE_PATHS.each do |path|
      content = repo_files.get_content(path, max_size: MAX_SI_SIZE)
      return [content, path] if content
    end
    nil
  end

  # Parse security-insights YAML content safely.
  # Uses safe_load with no permitted classes and aliases disabled to prevent
  # Ruby object injection and YAML alias/anchor bombs.
  # @param content [String] raw YAML text
  # @return [Object, nil] parsed YAML or nil on error
  def parse_security_insights(content)
    YAML.safe_load(
      content,
      permitted_classes: [],
      aliases: false,
      symbolize_names: false
    )
  rescue Psych::Exception
    nil
  end

  # Walk the MAPPINGS array, evaluate each condition, and collect proposals.
  # When multiple entries target the same criterion, keep the highest confidence.
  # @param si_data [Hash] parsed security-insights YAML
  # @param location [String] file path (for explanation text)
  # @return [Hash] proposed criterion status changes
  def evaluate_mappings(si_data, location)
    results = {}
    MAPPINGS.each do |mapping|
      value = dig_path(si_data, mapping['si_path'])
      next unless condition_met?(mapping, value)

      apply_mapping(results, mapping, location, value, si_data)
    end
    results
  end

  # Record one mapping's proposal into results, keeping highest confidence.
  # @param results [Hash] accumulator for proposals
  # @param mapping [Hash] one MAPPINGS entry
  # @param location [String] file path (for explanation text)
  # @param value [Object] resolved value at si_path
  # @param si_data [Hash] full parsed security-insights YAML (for comment extraction)
  def apply_mapping(results, mapping, location, value, si_data)
    target_field = :"#{mapping['target_criterion']}_status"
    confidence   = mapping['confidence']
    return if results.key?(target_field) && confidence <= results[target_field][:confidence]

    results[target_field] = {
      value:       CriterionStatus.parse(mapping['inferred_status']),
      confidence:  confidence,
      explanation: build_explanation(location, mapping, value, si_data)
    }
  end

  # Navigate a dot-separated path through a nested Hash.
  # Returns nil for any missing key or non-Hash intermediate node.
  # @param data [Object] root of the YAML tree
  # @param path [String] dot-separated key path, e.g. "repository.status"
  # @return [Object, nil] value at that path, or nil
  def dig_path(data, path)
    return unless data.is_a?(Hash) && path.is_a?(String)

    path.split('.').reduce(data) do |obj, key|
      return nil unless obj.is_a?(Hash)

      obj[key]
    end
  end

  # True if a non-nil, non-empty value is present.
  # Arrays must contain at least one element that is itself non-nil/non-empty
  # so that [""] or [nil] does not count as present.
  # @param value [Object] value to test
  # @return [Boolean]
  def value_present?(value)
    return false if value.nil?
    return false if value.respond_to?(:empty?) && value.empty?
    return false if value.is_a?(Array) &&
                    value.all? { |e| e.nil? || (e.respond_to?(:empty?) && e.empty?) }

    true
  end

  # Evaluate the mapping's condition against the resolved value.
  # The condition is inferred from which fields are present in the mapping:
  #   si_item_field present  — array-of-objects scan via find_matching_element
  #   no si_value/si_alternatives — presence check via value_present?
  #   otherwise              — scalar/list value match via value_matches?
  #
  # Raises ArgumentError for invalid field combinations (si_value +
  # si_alternatives together, or also without si_item_field).
  # @param mapping [Hash] one entry from MAPPINGS
  # @param value [Object] resolved value at si_path
  # @return [Boolean]
  def condition_met?(mapping, value)
    validate_condition_fields!(mapping)
    if mapping['si_item_field']
      !find_matching_element(value, mapping).nil?
    elsif mapping['si_value'].nil? && mapping['si_alternatives'].nil?
      value_present?(value)
    else
      value_matches?(value, mapping)
    end
  end

  # Raise ArgumentError for invalid field combinations.
  # Called by condition_met? on every evaluation.
  # @param mapping [Hash] one entry from MAPPINGS
  def validate_condition_fields!(mapping)
    if mapping.key?('si_value') && mapping.key?('si_alternatives')
      raise ArgumentError, 'si_value and si_alternatives are mutually exclusive'
    end
    return unless mapping.key?('also') && !mapping.key?('si_item_field')

    raise ArgumentError, "'also' requires 'si_item_field'"
  end

  # True if +value+ satisfies the si_value / si_alternatives / substring match
  # expressed in +mapping+.  Uses case-insensitive .to_s comparison throughout.
  # +value+ is untrusted SI data; mapping fields are from the trusted MAPPINGS
  # constant.
  # @param value [Object] untrusted value to test (from SI file)
  # @param mapping [Hash] mapping entry supplying si_value/si_alternatives/substring
  # @return [Boolean]
  def value_matches?(value, mapping)
    # Use key? rather than truthiness so si_value: false is handled correctly.
    candidates =
      if mapping.key?('si_value')
        [mapping['si_value']]
      else
        Array(mapping['si_alternatives'])
      end
    str = value.to_s.downcase
    if mapping['substring']
      candidates.any? { |c| str.include?(c.to_s.downcase) }
    else
      candidates.any? { |c| str == c.to_s.downcase }
    end
  end

  # Return the first element in +value+ (an array of objects) for which
  # si_item_field satisfies the value/substring match and, when +also+ is
  # present, the sub-path within the element equals true.
  # Returns nil if no element matches or if +value+ is not an Array.
  # si_item_field and also come from the trusted MAPPINGS constant; only the
  # array elements themselves are untrusted SI data.
  # @param value [Array, Object] value at si_path (untrusted)
  # @param mapping [Hash] mapping entry
  # @return [Hash, nil] first matching element, or nil
  def find_matching_element(value, mapping)
    return unless value.is_a?(Array)

    also_path = mapping['also']
    value.find do |element|
      next false unless element.is_a?(Hash)

      value_matches?(element[mapping['si_item_field']], mapping) &&
        (also_path.nil? || dig_path(element, also_path) == true)
    end
  end

  # Build a human-readable explanation string for a proposal.
  # Appends any comment found in the security-insights data for this field.
  # Uses i18n so the base message can be translated; the comment itself is not
  # translated (it is a verbatim quote from the project's own documentation).
  # @param location [String] file path where the data was found
  # @param mapping [Hash] mapping entry (for condition type and si_value)
  # @param value [Object] resolved value used in the condition
  # @param si_data [Hash] full parsed security-insights YAML
  # @return [String]
  def build_explanation(location, mapping, value, si_data)
    base    = base_explanation(File.basename(location), mapping, value)
    comment = extract_si_comment(si_data, mapping, value)
    return base unless comment

    "#{base} #{I18n.t('detectives.security_insights.comment_suffix', comment: comment)}"
  end

  # Build the base explanation before any comment suffix.
  # @param basename [String] file basename
  # @param mapping [Hash] mapping entry
  # @param value [Object] resolved value
  # @return [String]
  def base_explanation(basename, mapping, value)
    match_desc = array_match_description(mapping)
    if match_desc
      array_match_explanation(basename, mapping['si_path'], match_desc)
    else
      display_value = value.is_a?(String) ? value : value.to_s
      I18n.t('detectives.security_insights.field_value',
             location: basename, field: mapping['si_path'], value: display_value)
    end
  end

  # Return a human-readable match description string for si_item_field entries,
  # or nil for scalar/presence entries.
  # @param mapping [Hash] mapping entry
  # @return [String, nil]
  def array_match_description(mapping)
    return unless mapping['si_item_field']

    # Use key? so a hypothetical boolean si_value is rendered correctly.
    val  =
      if mapping.key?('si_value')
        mapping['si_value'].to_s
      else
        Array(mapping['si_alternatives']).join('|')
      end
    op   = mapping['substring'] ? ' includes ' : '='
    desc = "#{mapping['si_item_field']}#{op}#{val}"
    mapping['also'] ? "#{desc} with #{mapping['also']}=true" : desc
  end

  # Build the i18n explanation string for an array-match condition.
  # @param basename [String] file basename
  # @param si_path [String] dot-notation field path
  # @param match_desc [String] human-readable match description
  # @return [String]
  def array_match_explanation(basename, si_path, match_desc)
    I18n.t('detectives.security_insights.array_match',
           location: basename, field: si_path, match: match_desc)
  end

  # Extract an optional comment string from the security-insights data
  # relevant to this mapping's condition, truncated to MAX_SI_COMMENT_SIZE.
  # - Array entries (si_item_field present): comment from the matching element.
  # - Scalar/presence entries: comment from the parent object of si_path.
  # Returns nil if no non-empty String comment is found.
  # @param si_data [Hash] full parsed security-insights YAML
  # @param mapping [Hash] one MAPPINGS entry
  # @param value [Object] resolved value at si_path
  # @return [String, nil]
  def extract_si_comment(si_data, mapping, value)
    raw =
      if mapping['si_item_field']
        find_matching_element(value, mapping)&.dig('comment')
      else
        si_parent_comment(si_data, mapping['si_path'])
      end
    return unless raw.is_a?(String)

    stripped = raw.strip
    return if stripped.empty?

    stripped.length <= MAX_SI_COMMENT_SIZE ? stripped : "#{stripped[0, MAX_SI_COMMENT_SIZE]}..."
  end

  # Return the "comment" key of the parent object of si_path, or nil.
  # @param si_data [Hash] full parsed security-insights YAML
  # @param si_path [String] dot-notation path to the checked field
  # @return [Object, nil]
  def si_parent_comment(si_data, si_path)
    parts = si_path.split('.')
    return if parts.length < 2

    parent = dig_path(si_data, parts[0..-2].join('.'))
    parent.is_a?(Hash) ? parent['comment'] : nil
  end
end
# rubocop:enable Metrics/ClassLength
