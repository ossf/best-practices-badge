#!/usr/bin/env ruby
# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# This script runs standalone outside of Rails, so ActiveRecord methods
# like Array#pluck are unavailable. Use map instead.
# rubocop:disable Rails/Pluck

require_relative '../lib/baseline_html_parser'
require 'json'
require 'yaml'

# Read the HTML source
html_file = 'tmp/baseline_source.html'
unless File.exist?(html_file)
  puts "Error: #{html_file} not found"
  puts "Run: curl -s 'https://baseline.openssf.org/versions/2025-10-10' -o #{html_file}"
  exit 1
end

puts "Reading HTML from #{html_file}..."
html_content = File.read(html_file)

# Extract source URL from canonical link tag so it doesn't need to be hardcoded
source_doc = Nokogiri::HTML(html_content)
source_url = (source_doc.at('link[rel="canonical"]')&.attr('href') || 'unknown').sub(/\.html$/, '')
puts "Source URL: #{source_url}"

# Parse the HTML
parser = BaselineHtmlParser.new(html_content)
controls = parser.parse

puts "Extracted #{controls.length} controls"

# Load existing criteria so new ones can be marked future: true and
# dropped ones can be re-added with obsolete: true.
# existing_criteria_data maps criterion key -> { level:, major:, minor:, data: }
existing_criteria_file = 'criteria/baseline_criteria.yml'
existing_criteria_data = {}
if File.exist?(existing_criteria_file)
  existing_criteria = YAML.safe_load_file(
    existing_criteria_file,
    permitted_classes: [Symbol],
    aliases: true
  )
  existing_criteria.each do |level, level_data|
    next if level == '_metadata'

    level_data.each do |major, major_data|
      major_data.each do |minor, criteria|
        criteria.each do |key, data|
          existing_criteria_data[key] = {
            level: level, major: major, minor: minor, data: data
          }
        end
      end
    end
  end
  puts "Loaded #{existing_criteria_data.size} existing criterion keys from #{existing_criteria_file}"
else
  puts "No existing #{existing_criteria_file}; all criteria will be treated as new"
end

# Save as JSON for easy review
json_file = 'tmp/baseline_extracted.json'
File.write(json_file, JSON.pretty_generate(controls))
puts "Saved JSON to: #{json_file}"

# Save as YAML in our criteria format
yaml_data = {
  '_metadata' => {
    'source' => 'OpenSSF Baseline HTML',
    'source_url' => source_url,
    'extracted_at' => Time.now.iso8601,
    'auto_generated' => true,
    'total_controls' => controls.length
  }
}

new_keys = []
changed_keys = []
extracted_keys = controls.map { |c| c[:field_name] }

# Group by maturity level
controls.group_by { |c| c[:maturity_level].first }
        .each do |level, level_controls|
  level_key = "baseline-#{level}"
  yaml_data[level_key] = {}

  # Group by category
  level_controls.group_by { |c| c[:category] }
                .each do |category, cat_controls|
    yaml_data[level_key][category] = {}
    yaml_data[level_key][category]['Controls'] = {}

    cat_controls.each do |control|
      is_new = !existing_criteria_data.key?(control[:field_name])
      new_keys << control[:field_name] if is_new

      unless is_new
        old_data = existing_criteria_data[control[:field_name]][:data]
        old_desc = old_data['description'].to_s.strip
        old_details = old_data['details'].to_s.strip
        new_desc = control[:requirement].to_s.strip
        new_details = control[:recommendation].to_s.strip
        changed_keys << control[:field_name] if old_desc != new_desc || old_details != new_details
      end

      entry = {
        'category' => 'MUST',
        'description' => control[:requirement],
        'details' => control[:recommendation],
        'met_url_required' => false,
        'original_id' => control[:original_id],
        'na_allowed' => true,
        'na_justification_required' => true
      }
      is_future = is_new || existing_criteria_data.dig(control[:field_name], :data, 'future') == true
      entry['future'] = true if is_future
      is_obsolete = existing_criteria_data.dig(control[:field_name], :data, 'obsolete') == true
      entry['obsolete'] = true if is_obsolete

      yaml_data[level_key][category]['Controls'][control[:field_name]] = entry
    end
  end
end

# Re-add criteria dropped from the new version with obsolete: true so they
# remain findable. We don't act on obsolete criteria yet, but the flag makes
# future handling straightforward.
obsolete_keys = existing_criteria_data.keys - extracted_keys
obsolete_keys.each do |key|
  info = existing_criteria_data[key]
  yaml_data[info[:level]] ||= {}
  yaml_data[info[:level]][info[:major]] ||= {}
  yaml_data[info[:level]][info[:major]][info[:minor]] ||= {}
  entry = info[:data].dup
  entry['obsolete'] = true
  yaml_data[info[:level]][info[:major]][info[:minor]][key] = entry
end

yaml_file = 'tmp/baseline_extracted.yml'
File.write(yaml_file, yaml_data.to_yaml)
puts "Saved YAML to: #{yaml_file}"

# Print summary
puts "\nSummary by maturity level:"
controls.group_by { |c| c[:maturity_level].first }
        .sort.each do |level, level_controls|
  puts "  Level #{level}: #{level_controls.length} controls"
end

puts "\nSummary by category:"
controls.group_by { |c| c[:category] }
        .sort.each do |category, cat_controls|
  puts "  #{category}: #{cat_controls.length} controls"
end

if new_keys.empty?
  puts "\nNo new criteria (no future: true entries added)"
else
  puts "\nNew criteria marked future: true (#{new_keys.length}):"
  new_keys.each { |key| puts "  #{key}" }
end

if obsolete_keys.empty?
  puts "\nNo obsolete criteria (no obsolete: true entries added)"
else
  puts "\nObsolete criteria marked obsolete: true (#{obsolete_keys.length}):"
  obsolete_keys.each { |key| puts "  #{key}" }
end

if changed_keys.empty?
  puts "\nNo criteria with changed description or details"
else
  puts "\nCriteria with changed description or details (#{changed_keys.length}):"
  changed_keys.each { |key| puts "  #{key}" }
end

puts "\nFirst 3 controls:"
controls.first(3).each do |control|
  puts "  #{control[:original_id]} (#{control[:field_name]})"
  puts "    Requirement: #{control[:requirement][0..80]}..."
  puts
end

# rubocop:enable Rails/Pluck
