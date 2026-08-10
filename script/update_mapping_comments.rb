#!/usr/bin/env ruby
# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Update # Source: and # Target: comment blocks in criteria/*_to_*_map.yml
# files to match the current criterion text from config/locales/en.yml.
#
# Each replaced block includes both the 'description' and 'details' fields
# from en.yml, labeled as such:
#
#   # Source:
#   #   description: "The project MUST..."
#   #   details: "Detailed guidance..."
#
# USAGE:
#   ruby script/update_mapping_comments.rb
#
# This script is standalone Ruby (no Rails required).
# rubocop:disable Rails/Blank, Rails/Present

require 'cgi'
require 'yaml'

RAILS_ROOT = File.expand_path('..', __dir__)
EN_YML = File.join(RAILS_ROOT, 'config/locales/en.yml')
MAPPING_FILES = [
  File.join(RAILS_ROOT, 'criteria/metal_to_baseline_map.yml'),
  File.join(RAILS_ROOT, 'criteria/baseline_to_metal_map.yml')
].freeze

# Target width for comment lines (characters)
MAX_LINE_WIDTH = 79

# Remove HTML tags and entities from criterion text; collapse whitespace.
#
# SECURITY NOTE: This method processes ONLY trusted, developer-controlled
# content read from config/locales/en.yml.  The output is written into YAML
# comment blocks — it is never rendered as HTML, inserted into a database, or
# returned in an HTTP response.  This is NOT a security boundary; there is no
# untrusted input and no injection risk.
#
# CGI.unescapeHTML decodes all HTML entities in one call (far more complete
# than a hand-rolled list), and decoding happens before tag-stripping so any
# entity-encoded tags (e.g. &lt;b&gt;) are also removed.
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

# Wrap text into comment lines for a labeled sub-block within a Source/Target block.
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

  segments = [] # [text_segment, is_first_line]
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

# Build the full replacement comment block for a Source or Target entry.
# Returns an array of strings (without trailing newlines).
# rubocop:disable Metrics/MethodLength
def build_comment_block(kind, criterion_id, lookup, indent)
  unless criterion_id
    warn "WARNING: #{kind}: block found with no tracked criterion ID"
    return ["#{indent}# #{kind}: (unknown criterion)"]
  end

  entry = lookup[criterion_id]
  unless entry
    warn "WARNING: No en.yml entry found for criterion '#{criterion_id}'"
    return ["#{indent}# #{kind}: (criterion not found: #{criterion_id})"]
  end

  lines = ["#{indent}# #{kind}:"]

  desc = entry[:description]
  lines.concat(wrap_labeled_block('description', desc, indent)) unless desc.nil? || desc.empty?

  details = entry[:details]
  lines.concat(wrap_labeled_block('details', details, indent)) unless details.nil? || details.empty?

  lines
end
# rubocop:enable Metrics/MethodLength

# Process a single mapping file, replacing # Source: and # Target: blocks.
# Returns the updated file content as a string.
# rubocop:disable Metrics/AbcSize, Metrics/MethodLength
def process_file(filepath, lookup)
  input_lines = File.readlines(filepath)
  output_lines = []

  current_source = nil
  current_target = nil
  i = 0

  while i < input_lines.length
    line     = input_lines[i]
    stripped = line.chomp

    # Track which criterion is currently active.
    # source_criterion lines look like "  - source_criterion: foo" (with "- "),
    # while target_criterion lines look like "    target_criterion: bar" (no "-").
    # Use a simple substring match without a leading-anchor to cover both.
    if (m = line.match(/\bsource_criterion:\s+(\S+)/))
      current_source = m[1]
    elsif (m = line.match(/\btarget_criterion:\s+(\S+)/))
      current_target = m[1]
    end

    # Detect start of a # Source: or # Target: block
    if (m = stripped.match(/^(\s+)# (Source|Target):/))
      indent       = m[1]
      kind         = m[2]
      criterion_id = kind == 'Source' ? current_source : current_target

      # Emit replacement lines
      build_comment_block(kind, criterion_id, lookup, indent).each do |comment_line|
        output_lines << "#{comment_line}\n"
      end

      # Skip the original block: the start line (already consumed) plus all
      # continuation lines (any line at the same indent whose # is followed
      # by 2 or more spaces, covering the old 3-space and new 5-space styles).
      cont_re = /^#{Regexp.escape(indent)}#  /
      i += 1
      i += 1 while i < input_lines.length && input_lines[i].chomp.match?(cont_re)

      next # skip the i += 1 at the bottom of the loop
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

  MAPPING_FILES.each do |filepath|
    puts "Processing #{File.basename(filepath)}..."
    updated = process_file(filepath, lookup)
    File.write(filepath, updated)
    puts '  Done.'
  end

  puts 'All mapping files updated.'
end

# rubocop:enable Rails/Blank, Rails/Present
main
