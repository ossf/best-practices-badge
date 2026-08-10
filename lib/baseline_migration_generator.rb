# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'json'
require 'fileutils'

# rubocop:disable Rails/Output, Metrics/ClassLength
# This is a command-line utility script, not Rails code.
# Using puts for user output is appropriate here.
# Class length is reasonable for a migration generator.

# Generates database migrations for baseline criteria
class BaselineMigrationGenerator
  def initialize
    @mapping_file = Rails.root.join(BASELINE_CONFIG[:mapping_file])
    @criteria_file = Rails.root.join(BASELINE_CONFIG[:criteria_file])
  end

  def generate
    # Load or generate mapping
    mapping = ensure_mapping_exists

    # Compare with existing schema to find new fields
    new_fields = find_new_fields(mapping)

    if new_fields.empty?
      puts 'No new fields to add. Schema is up to date.'
      return
    end

    puts "Found #{new_fields.size} new fields to add:"
    new_fields.each { |field| puts "  - #{field['database_field']}" }

    # Generate migration file
    generate_migration_file(new_fields, mapping)
  end

  private

  def ensure_mapping_exists
    if File.exist?(@mapping_file)
      mapping = JSON.parse(File.read(@mapping_file))
      sync_mapping_with_criteria(mapping)
    else
      # Generate mapping from criteria file
      puts "Generating field mapping from #{@criteria_file}..."
      mapping = generate_mapping_from_criteria
      File.write(@mapping_file, JSON.pretty_generate(mapping))
      puts "Generated: #{@mapping_file}"
      mapping
    end
  end

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def sync_mapping_with_criteria(mapping)
    criteria = YAML.safe_load_file(
      @criteria_file,
      permitted_classes: [Symbol],
      aliases: true
    )

    existing_keys = mapping['mappings'].to_set { |m| m['criterion_key'] }
    new_entries = []

    criteria.each do |level, level_data|
      next if level == '_metadata'

      traverse_criteria(level_data) do |criterion_key, criterion_data|
        next if existing_keys.include?(criterion_key)

        new_entries << {
          'level' => level,
          'criterion_key' => criterion_key,
          'database_field' => criterion_key,
          'baseline_id' => criterion_data['baseline_id'] || criterion_data['external_id'],
          'category' => criterion_data['category']
        }
      end
    end

    if new_entries.any?
      puts "Adding #{new_entries.size} new entr#{new_entries.size == 1 ? 'y' : 'ies'} to mapping:"
      new_entries.each { |e| puts "  + #{e['criterion_key']}" }
      mapping['mappings'].concat(new_entries)
      mapping['generated_at'] = Time.now.iso8601
      File.write(@mapping_file, JSON.pretty_generate(mapping))
    end

    mapping
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  # rubocop:disable Metrics/MethodLength
  def generate_mapping_from_criteria
    criteria = YAML.safe_load_file(
      @criteria_file,
      permitted_classes: [Symbol],
      aliases: true
    )

    mappings = []

    criteria.each do |level, level_data|
      next if level == '_metadata'

      traverse_criteria(level_data) do |criterion_key, criterion_data|
        mappings << {
          'level' => level,
          'criterion_key' => criterion_key,
          'database_field' => criterion_key,
          'baseline_id' => criterion_data['baseline_id'] || criterion_data['external_id'],
          'category' => criterion_data['category']
        }
      end
    end

    {
      'version' => '1.0',
      'generated_at' => Time.now.iso8601,
      'mappings' => mappings
    }
  end
  # rubocop:enable Metrics/MethodLength

  def traverse_criteria(data, &block)
    return unless data.is_a?(Hash)

    data.each do |key, value|
      if value.is_a?(Hash)
        if value.key?('category')
          yield(key, value)
        else
          traverse_criteria(value, &block)
        end
      end
    end
  end

  # Find new fields that need to be added to the database
  # IMPORTANT: Only returns fields that DON'T already exist in the schema
  # This prevents duplicate column errors when re-running after upstream updates
  # rubocop:disable Metrics/MethodLength
  def find_new_fields(mapping)
    # Get existing columns from the database
    existing_columns = Project.column_names.to_set

    # Find fields that don't exist yet
    new_fields = []
    skipped_fields = []

    mapping['mappings'].each do |field_map|
      status_field = "#{field_map['database_field']}_status"

      if existing_columns.include?(status_field)
        # Field already exists - skip it (preserves existing data)
        skipped_fields << field_map['database_field']
      else
        # New field - will be added
        new_fields << field_map
      end
    end

    # Report what was skipped
    if skipped_fields.any?
      puts "\nSkipping #{skipped_fields.size} existing fields (already in database):"
      skipped_fields.each { |field| puts "  ✓ #{field}" }
    end

    new_fields
  end
  # rubocop:enable Metrics/MethodLength

  def generate_migration_file(new_fields, mapping)
    timestamp = Time.current.strftime('%Y%m%d%H%M%S')
    filename = Rails.root.join('db', 'migrate', "#{timestamp}_add_baseline_criteria_sync_#{new_fields.size}_fields.rb")

    # Group by level for organization
    by_level = new_fields.group_by { |f| f['level'] }

    migration_content = generate_migration_content(by_level, mapping)

    File.write(filename, migration_content)
    puts "\n✓ Generated migration: #{filename}"
    puts "\nNext steps:"
    puts "  1. Review the migration: #{filename}"
    puts '  2. Run: rails db:migrate'
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def generate_migration_content(by_level, _mapping)
    class_name = "AddBaselineCriteriaSync#{by_level.values.flatten.size}Fields"

    lines = []
    lines << '# frozen_string_literal: true'
    lines << ''
    lines << '# Auto-generated migration from baseline criteria sync'
    lines << "# Generated at: #{Time.now.iso8601}"
    lines << "# Source: #{BASELINE_CONFIG[:criteria_file]}"
    lines << "# Mapping: #{BASELINE_CONFIG[:mapping_file]}"
    lines << ''
    lines << "class #{class_name} < ActiveRecord::Migration[8.0]"
    lines << '  def change'

    by_level.each do |level, fields|
      lines << ''
      lines << "    # #{level} criteria (#{fields.size} criteria)"
      fields.each do |field|
        field_name = field['database_field']
        lines << "    add_column :projects, :#{field_name}_status, :smallint, default: 0, null: false"
        lines << "    add_column :projects, :#{field_name}_justification, :text"
      end
    end

    lines << '  end'
    lines << 'end'
    lines << ''

    lines.join("\n")
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
end

# rubocop:enable Rails/Output, Metrics/ClassLength
