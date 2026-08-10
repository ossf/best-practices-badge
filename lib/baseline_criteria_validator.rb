# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'yaml'
require 'json'

# Validates the baseline criteria YAML and mapping JSON files for
# internal consistency. Used by CI rake tasks and pre-migration checks
# to catch errors before they reach production.
# Requires Rails.root and the BASELINE_CONFIG initializer constant.
# rubocop:disable Metrics/ClassLength
class BaselineCriteriaValidator
  # @return [Array<String>] human-readable error messages from the last
  #   call to {#validate}; empty if all checks passed
  attr_reader :errors

  # Sets up file paths from BASELINE_CONFIG. Requires Rails.root.
  def initialize
    @criteria_file = Rails.root.join(BASELINE_CONFIG[:criteria_file])
    @mapping_file = Rails.root.join(BASELINE_CONFIG[:mapping_file])
    @en_locale_file = Rails.root.join('config', 'locales', 'en.yml')
    @errors = []
  end

  # Runs all validation checks against the criteria and mapping files.
  # Clears errors from any prior run before starting.
  # @return [Boolean] true if all checks passed, false if any errors were found
  #
  # These are command methods that perform validation and modify state (@errors),
  # not pure predicate methods. The naming follows validation command conventions.
  # rubocop:disable Naming/PredicateMethod
  def validate
    @errors = []

    validate_criteria_file_exists
    validate_criteria_yaml_valid
    validate_criteria_content
    validate_i18n_descriptions
    validate_mapping_file_exists if File.exist?(@mapping_file)

    @errors.empty?
  end

  private

  def validate_criteria_file_exists
    unless File.exist?(@criteria_file)
      @errors << "Criteria file not found: #{@criteria_file}"
      return false
    end
    true
  end

  def validate_criteria_yaml_valid
    return false unless validate_criteria_file_exists

    YAML.safe_load_file(
      @criteria_file,
      permitted_classes: [Symbol],
      aliases: true
    )
    true
  rescue Psych::SyntaxError => e
    @errors << "Invalid YAML in #{@criteria_file}: #{e.message}"
    false
  end

  # rubocop:disable Metrics/MethodLength
  def validate_criteria_content
    return false unless validate_criteria_file_exists

    criteria = YAML.safe_load_file(
      @criteria_file,
      permitted_classes: [Symbol],
      aliases: true
    )

    criteria.each do |level, level_data|
      next if level == '_metadata'

      traverse_criteria(level_data) do |key, data|
        validate_not_future_and_obsolete(key, data)
        validate_has_description(key, data)
      end
    end

    true
  rescue Psych::SyntaxError
    false # YAML errors already reported by validate_criteria_yaml_valid
  end
  # rubocop:enable Metrics/MethodLength

  def traverse_criteria(data, &block)
    return unless data.is_a?(Hash)

    data.each do |key, value|
      next unless value.is_a?(Hash)

      if value.key?('category')
        yield(key, value)
      else
        traverse_criteria(value, &block)
      end
    end
  end

  def validate_not_future_and_obsolete(key, data)
    return unless data['future'] == true && data['obsolete'] == true

    @errors << "Criterion '#{key}' has both future: true and obsolete: true (mutually exclusive)"
  end

  def validate_has_description(key, data)
    return unless data['description'].nil? || data['description'].to_s.strip.empty?

    @errors << "Criterion '#{key}' has no description"
  end

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def validate_i18n_descriptions
    return false unless validate_criteria_file_exists
    return true unless File.exist?(@en_locale_file)

    criteria = YAML.safe_load_file(
      @criteria_file, permitted_classes: [Symbol], aliases: true
    )
    en_data = YAML.safe_load_file(@en_locale_file, aliases: true)
    en_criteria = en_data.dig('en', 'criteria') || {}

    criteria.each do |level, level_data|
      next if level == '_metadata'

      traverse_criteria(level_data) do |key, data|
        next if data['description'].nil? || data['description'].to_s.strip.empty?

        en_desc = en_criteria.dig(level, key, 'description').to_s.strip
        if en_desc.empty?
          @errors << "Criterion '#{key}' has description in criteria YAML but is missing from en.yml " \
                     '(run: rake baseline:extract_i18n)'
        end
      end
    end

    true
  rescue Psych::SyntaxError
    false
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  def validate_mapping_file_exists
    unless File.exist?(@mapping_file)
      @errors << "Mapping file not found: #{@mapping_file}"
      return false
    end

    begin
      JSON.parse(File.read(@mapping_file))
      true
    rescue JSON::ParserError => e
      @errors << "Invalid JSON in #{@mapping_file}: #{e.message}"
      false
    end
  end
  # rubocop:enable Naming/PredicateMethod
end
# rubocop:enable Metrics/ClassLength
