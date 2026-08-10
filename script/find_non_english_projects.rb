#!/usr/bin/env ruby
# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# List projects that have non-English justifications or descriptions.
# Reports projects with multiple non-English fields first.
# Usage: rails runner script/find_non_english_projects.rb
#    or: script/find_non_english_projects.rb

# Load Rails environment if not already loaded (e.g., run without rails runner)
require_relative '../config/environment' unless defined?(Rails)

# Simple heuristic: English text uses mostly ASCII letters and commonly
# contains short English articles/prepositions. Text is likely non-English
# if it has significant non-ASCII alphabetic characters OR if it is long
# enough to expect common English words but contains none.
ENGLISH_WORDS = %w[
  the is a an and or for to of in that this it are was be has
  with not but have from by can will if no yes we do should
  must may use all also any each our its been does did had
  using used into only than such when which there their these
  those would could other about how some
].freeze
ENGLISH_WORDS_RE = /\b(#{ENGLISH_WORDS.join('|')})\b/i

# Proportion of non-ASCII alphabetic characters in the text.
# High ratio indicates non-Latin scripts (CJK, Cyrillic, Arabic, etc.)
def non_ascii_letter_ratio(text)
  alpha_chars = text.scan(/\p{L}/)
  return 0.0 if alpha_chars.empty?

  non_ascii = alpha_chars.count { |c| c.bytesize > 1 }
  non_ascii.to_f / alpha_chars.length
end

# Remove URLs (possibly wrapped in angle brackets) — they give no
# language signal and many justifications are just a URL.
def strip_urls(text)
  text.gsub(%r{[<'"]*https?://[^\s<>'"]+[>'"]*}, '').strip
end

def english?(text)
  return true if text.nil? || text.strip.empty?

  # Remove surrounding whitespace and URLs
  stripped = strip_urls(text.strip)

  # After removing URLs, if nothing meaningful remains, assume English
  return true if stripped.length < 20

  # If more than 30% of letters are non-ASCII, it's likely non-English
  return false if non_ascii_letter_ratio(stripped) > 0.3

  # For mostly-ASCII text, check for common English words
  # Only apply this check to text long enough to reasonably contain them
  return true if stripped.length < 60

  ENGLISH_WORDS_RE.match?(stripped)
end

justification_columns =
  Project.column_names.select { |c| c.end_with?('_justification') }
has_description = Project.column_names.include?('description')
all_columns = has_description ? ['description'] + justification_columns : justification_columns

puts "Checking #{all_columns.length} fields across all projects..."

# Collect per-project non-English fields, then filter:
# report if description is non-English OR 2+ justifications are non-English
flagged = {}

Project.find_each do |project|
  non_english_desc = false
  non_english_justifications = []

  all_columns.each do |col|
    text = project.public_send(col)
    next if text.blank?
    next if english?(text)

    if col == 'description'
      non_english_desc = true
    else
      non_english_justifications << { column: col, text: text }
    end
  end

  next unless non_english_desc || non_english_justifications.length >= 2

  fields = non_english_justifications
  if non_english_desc
    desc_entry = { column: 'description', text: project.description }
    fields = [desc_entry] + fields
  end
  flagged[project.id] = { name: project.name, fields: fields }
end

if flagged.empty?
  puts 'No projects with non-English descriptions or multiple ' \
       'non-English justifications found.'
  exit
end

# Sort by number of non-English fields descending (worst offenders first)
sorted = flagged.sort_by { |_id, data| -data[:fields].length }

puts "Found #{flagged.length} project(s) with non-English text.\n\n"

sorted.each do |project_id, data|
  count = data[:fields].length
  puts "Project ##{project_id}: #{data[:name]} (#{count} non-English field#{'s' if count != 1})"
  data[:fields].each do |field|
    preview = field[:text].gsub(/\s+/, ' ').strip
    preview = "#{preview[0, 80]}..." if preview.length > 80
    puts "  #{field[:column]}: #{preview}"
  end
  puts ''
end
