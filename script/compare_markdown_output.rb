#!/usr/bin/env ruby
# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Compare actual markdown processing vs simple HTML escape
# Only justifications that produce identical output are truly safe

require_relative '../config/environment'

# Use the same configuration as the actual helper
MARKDOWN_RENDERER_OPTIONS = {
  filter_html: true, no_images: true,
  no_styles: true, safe_links_only: true,
  link_attributes: { rel: 'nofollow ugc' }
}.freeze
MARKDOWN_PROCESSOR_OPTIONS = {
  no_intra_emphasis: true, autolink: true,
  space_after_headers: true, fenced_code_blocks: true
}.freeze

MARKDOWN_PREFIX = '<p>'
MARKDOWN_SUFFIX = "</p>\n"

renderer = Redcarpet::Render::HTML.new(MARKDOWN_RENDERER_OPTIONS)
processor = Redcarpet::Markdown.new(renderer, MARKDOWN_PROCESSOR_OPTIONS)

input_file = ',justifications.txt'
ok_output_file = ',justifications.truly-ok'
not_ok_output_file = ',justifications.not-ok'

puts "Reading #{input_file}..."
justifications = File.readlines(input_file, chomp: true)

# Count occurrences
counts = Hash.new(0)
justifications.each { |j| counts[j] += 1 }

puts "Total justifications: #{justifications.size}"
puts "Unique justifications: #{counts.size}"
puts
puts 'Testing each unique justification...'
puts

truly_safe = {}
needs_markdown = {}

counts.each_with_index do |(text, count), index|
  next if text.blank?

  # CHANGE! We'll strip the input text (we'll need to do this on the
  # real system). Many people add initial spaces or whatever, which is
  # odd. We don't want that to impact the output.
  text = text.strip

  # Process with markdown
  markdown_output = processor.render(text.to_s)

  # Process with simple HTML escape (the workaround)
  simple_output = MARKDOWN_PREFIX + ERB::Util.html_escape(text).to_s + MARKDOWN_SUFFIX

  if markdown_output == simple_output
    truly_safe[text] = count
  else
    needs_markdown[text] = count
  end

  # Progress indicator
  puts "Processed #{index + 1} / #{counts.size}" if (index + 1) % 10_000 == 0
end

puts
puts 'Analysis complete!'
puts '=' * 70
puts "Truly safe (same output): #{truly_safe.size} unique (#{truly_safe.values.sum} total instances)"
puts "Needs markdown: #{needs_markdown.size} unique (#{needs_markdown.values.sum} total instances)"
puts

# Write truly safe justifications to file (one per line)
File.open(ok_output_file, 'w') do |f|
  truly_safe.sort_by { |_text, count| -count }
            .each do |text, _count|
    f.puts text
  end
end

# Write justifications that need markdown to file (one per line)
File.open(not_ok_output_file, 'w') do |f|
  needs_markdown.sort_by { |_text, count| -count }
                .each do |text, _count|
    f.puts text
  end
end

puts "Wrote #{truly_safe.size} truly safe justifications to #{ok_output_file}"
puts "Wrote #{needs_markdown.size} justifications needing markdown to #{not_ok_output_file}"
puts

# Show some examples of justifications that NEED markdown
puts '=' * 70
puts 'Examples that NEED markdown processing (output differs):'
puts
needs_markdown.sort_by { |_text, count| -count }
              .first(10).each do |text, count|
  display_text = text.length > 80 ? "#{text[0, 80]}..." : text
  puts "Count: #{count}"
  puts "  Text: #{display_text}"
  puts "  Simple: #{MARKDOWN_PREFIX + ERB::Util.html_escape(text)[0, 100]}..."
  puts "  Markdown: #{processor.render(text)[0, 100]}..."
  puts
end
