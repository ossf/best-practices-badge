#!/usr/bin/env ruby
# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Update # Target: comment blocks in criteria/security_insights_map.yml
# to match the current criterion text from config/locales/en.yml.
#
# # Source: blocks (which describe security-insights.yml spec fields) are
# written by hand and are NOT touched by this script.
#
# Each replaced # Target: block includes both the 'description' and 'details'
# fields from en.yml, formatted as:
#
#   # Target:
#   #   description: "The project MUST..."
#   #   details: "Detailed guidance..."
#
# USAGE:
#   ruby script/update_security_insights_comments.rb
#
# This script is standalone Ruby (no Rails required).
# rubocop:disable Rails/Blank, Rails/Present

require 'cgi'
require 'yaml'

RAILS_ROOT   = File.expand_path('..', __dir__)
EN_YML       = File.join(RAILS_ROOT, 'config/locales/en.yml')
MAPPING_FILE = File.join(RAILS_ROOT, 'criteria/security_insights_map.yml')

# Target width for comment lines (characters)
MAX_LINE_WIDTH = 79

# Remove HTML tags and entities from criterion text; collapse whitespace.
#
# SECURITY NOTE: This method processes ONLY trusted, developer-controlled
# content read from config/locales/en.yml.  The output is written into YAML
# comment blocks — it is never rendered as HTML, inserted into a database, or
# returned in an HTTP response.
def strip_html(text)
  return '' if text.nil? || text.empty?

  CGI.unescapeHTML(text).gsub(/<[^>]+>/, '').gsub(/\s+/, ' ').strip
end

# Build a lookup hash: criterion_id => { description:, details: }
# Covers both metal levels ('0','1','2') and OSPS Baseline levels
# ('baseline-1','baseline-2','baseline-3').
# rubocop:disable Metrics/MethodLength
def build_criteria_lookup(en_yml_path)
  data = YAML.safe_load_file(en_yml_path, aliases: true)
  all_criteria = data.dig('en', 'criteria')
  raise KeyError, "Could not find en.criteria in #{en_yml_path}" unless all_criteria

  lookup = {}
  all_criteria.each_value do |level_criteria|
    next unless level_criteria.is_a?(Hash)

    level_criteria.each do |criterion_id, attrs|
      next unless attrs.is_a?(Hash)

      desc    = strip_html(attrs['description'].to_s)
      details = strip_html(attrs['details'].to_s)
      lookup[criterion_id] = { description: desc, details: details }
    end
  end
  lookup
end
# rubocop:enable Metrics/MethodLength

# Wrap text into comment lines for a labeled sub-block.
# First line:    {indent}#   {label}: "{words...}
# Continuation:  {indent}#     {words...}"  (5 spaces after # to align)
#
# Returns an array of strings (without trailing newlines).
# rubocop:disable Metrics/AbcSize, Metrics/MethodLength
def wrap_labeled_block(label, text, indent)
  prefix_first = "#{indent}#   #{label}: \""
  prefix_cont  = "#{indent}#     "
  avail_first  = MAX_LINE_WIDTH - prefix_first.length
  avail_cont   = MAX_LINE_WIDTH - prefix_cont.length

  words = text.split
  return [] if words.empty?

  segments = []
  current  = ''
  first    = true

  words.each do |word|
    avail = first ? avail_first : avail_cont
    if current.empty?
      current = word
    elsif (current.length + 1 + word.length) <= avail
      current += " #{word}"
    else
      segments << [current, first]
      current = word
      first   = false
    end
  end
  segments << [current, first] unless current.empty?

  segments.each_with_index.map do |(seg, is_first), idx|
    prefix = is_first ? prefix_first : prefix_cont
    suffix = idx == segments.length - 1 ? '"' : ''
    "#{prefix}#{seg}#{suffix}"
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength

# Build the full replacement # Target: block for a criterion.
# Returns an array of strings (without trailing newlines).
# rubocop:disable Metrics/MethodLength
def build_target_block(criterion_id, lookup, indent)
  unless criterion_id
    warn 'WARNING: # Target: block found with no tracked target_criterion'
    return ["#{indent}# Target: (unknown criterion)"]
  end

  entry = lookup[criterion_id]
  unless entry
    warn "WARNING: No en.yml entry found for criterion '#{criterion_id}'"
    return ["#{indent}# Target: (criterion not found: #{criterion_id})"]
  end

  lines = ["#{indent}# Target:"]

  desc = entry[:description]
  lines.concat(wrap_labeled_block('description', desc, indent)) unless desc.nil? || desc.empty?

  details = entry[:details]
  lines.concat(wrap_labeled_block('details', details, indent)) unless details.nil? || details.empty?

  lines
end
# rubocop:enable Metrics/MethodLength

# Process the mapping file, replacing # Target: blocks with current text.
# # Source: blocks and free-form section header comments are left unchanged.
# Returns the updated file content as a string.
# rubocop:disable Metrics/AbcSize, Metrics/MethodLength
def process_file(filepath, lookup)
  input_lines  = File.readlines(filepath)
  output_lines = []

  current_target = nil
  i = 0

  while i < input_lines.length
    line     = input_lines[i]
    stripped = line.chomp

    # Track the most recent target_criterion line.
    if (m = line.match(/\btarget_criterion:\s+(\S+)/))
      current_target = m[1]
    end

    # Detect the start of a # Target: block.
    if (m = stripped.match(/^(\s*)# Target:/))
      indent = m[1]

      # Emit replacement lines for the block.
      build_target_block(current_target, lookup, indent).each do |comment_line|
        output_lines << "#{comment_line}\n"
      end

      # Skip the original block header and any continuation comment lines.
      # Continuation lines match: same indent + "# " + two or more spaces.
      cont_re = /^#{Regexp.escape(indent)}#  /
      i += 1
      i += 1 while i < input_lines.length && input_lines[i].chomp.match?(cont_re)

      next # skip the i += 1 at the bottom
    end

    output_lines << line
    i += 1
  end

  output_lines.join
end
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength

def main
  puts "Loading #{EN_YML}..."
  lookup = build_criteria_lookup(EN_YML)
  puts "  Loaded #{lookup.size} criterion entries."

  puts "Processing #{File.basename(MAPPING_FILE)}..."
  updated = process_file(MAPPING_FILE, lookup)
  File.write(MAPPING_FILE, updated)
  puts '  Done.'
end

# rubocop:enable Rails/Blank, Rails/Present
main
