# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'yaml'

# rubocop:disable Rails/Output
# This is a command-line utility script, not Rails code.
# Using puts for user output is appropriate here.

# Extracts i18n strings from baseline_criteria.yml to config/locales/en.yml
class BaselineI18nExtractor
  BEGIN_MARKER = '  # BEGIN BASELINE CRITERIA AUTO-GENERATED'
  END_MARKER = '  # END BASELINE CRITERIA AUTO-GENERATED'
  MARKER_WARNING = '  # WARNING: This section is automatically generated from criteria/baseline_criteria.yml'
  MARKER_DO_NOT_EDIT = '  # Do not edit manually. Run: rake baseline:extract_i18n'

  def initialize
    @baseline_criteria_file = Rails.root.join(BASELINE_CONFIG[:criteria_file])
    @en_locale_file = Rails.root.join('config', 'locales', 'en.yml')
  end

  def extract
    puts "Extracting i18n strings from #{@baseline_criteria_file}..."

    # Load baseline criteria
    baseline_criteria = load_baseline_criteria

    # Extract translatable fields
    i18n_data = extract_i18n_data(baseline_criteria)

    # Update en.yml preserving existing content
    update_locale_file(i18n_data)

    puts '✓ i18n extraction complete!'
    puts "  Updated: #{@en_locale_file}"
  end

  private

  def load_baseline_criteria
    unless File.exist?(@baseline_criteria_file)
      raise StandardError, "Baseline criteria file not found: #{@baseline_criteria_file}"
    end

    YAML.safe_load_file(
      @baseline_criteria_file,
      permitted_classes: [Symbol],
      aliases: true
    )
  end

  # Extract description, details, placeholders from criteria
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def extract_i18n_data(criteria)
    i18n_hash = {}

    criteria.each do |level, level_data|
      next if level == '_metadata' # Skip metadata

      i18n_hash[level] = {}

      traverse_criteria(level_data) do |criterion_key, criterion_data|
        fields = {}
        fields['description'] = criterion_data['description'] if criterion_data['description']
        fields['details'] = criterion_data['details'] if criterion_data['details']
        fields['met_placeholder'] = criterion_data['met_placeholder'] if criterion_data['met_placeholder']
        fields['unmet_placeholder'] = criterion_data['unmet_placeholder'] if criterion_data['unmet_placeholder']
        fields['na_placeholder'] = criterion_data['na_placeholder'] if criterion_data['na_placeholder']

        i18n_hash[level][criterion_key] = fields unless fields.empty?
      end
    end

    i18n_hash
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  # Recursively traverse nested criteria structure
  def traverse_criteria(data, &block)
    return unless data.is_a?(Hash)

    data.each do |key, value|
      if value.is_a?(Hash)
        # Check if this is a criterion (has 'category' field) or a category/subcategory
        if value.key?('category')
          yield(key, value)
        else
          # Recurse into category/subcategory
          traverse_criteria(value, &block)
        end
      end
    end
  end

  # Update en.yml preserving existing content and comments
  def update_locale_file(i18n_data)
    # Read the entire file
    content = File.read(@en_locale_file)

    # Find marker positions
    begin_pos = content.index(BEGIN_MARKER)
    end_pos = content.index(END_MARKER)

    if begin_pos.nil? || end_pos.nil?
      raise StandardError, "ERROR: Marker comments not found in #{@en_locale_file}\n" \
                           'Please add markers as described in docs/baseline_details.md section 2.3'
    end

    # Replace content between markers
    replace_between_markers(content, i18n_data, begin_pos, end_pos)
  end

  def replace_between_markers(content, i18n_data, begin_pos, end_pos)
    # Extract content before and after markers
    before_markers = content[0...begin_pos]
    after_end_marker_line = content.index("\n", end_pos)
    after_end_marker_line = content.length if after_end_marker_line.nil?
    # Skip the newline that terminates the END_MARKER line itself; generated_content
    # already ends with "\n", so including it here would produce a spurious blank line.
    after_markers = content[(after_end_marker_line + 1)..]

    # Generate new content between markers
    generated_content = generate_yaml_content(i18n_data)

    # Combine
    new_content = before_markers + generated_content + after_markers

    # Write back
    File.write(@en_locale_file, new_content)
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def generate_yaml_content(i18n_data)
    lines = []
    lines << BEGIN_MARKER
    lines << MARKER_WARNING
    lines << MARKER_DO_NOT_EDIT

    i18n_data.each do |level, criteria|
      lines << "    #{level}:"
      criteria.each do |criterion_key, fields|
        lines << "      #{criterion_key}:"
        fields.each do |field_name, field_value|
          # Format as YAML with proper indentation
          # Handle multi-line strings
          if field_value.include?("\n")
            lines << "        #{field_name}: >-"
            field_value.split("\n").each do |line|
              lines << "          #{line}"
            end
          else
            # Escape backslashes first, then quotes (order matters!)
            escaped_value = field_value.gsub('\\', '\\\\').gsub('"', '\\"')
            lines << "        #{field_name}: \"#{escaped_value}\""
          end
        end
      end
    end

    lines << END_MARKER
    lines.join("\n") + "\n"
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
end

# rubocop:enable Rails/Output
