#!/usr/bin/env ruby
# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Fix common markdownlint errors in markdown files
#
# USAGE:
#   script/fix_markdown.rb [OPTIONS] FILE [FILE]
#
# EXAMPLES:
#   # Fix a file in-place (overwrites the file):
#   script/fix_markdown.rb docs/myfile.md
#
#   # Fix and write to a different file:
#   script/fix_markdown.rb docs/myfile.md docs/myfile-fixed.md
#
#   # Dry-run to see what would be fixed without changing the file:
#   script/fix_markdown.rb --dry-run docs/myfile.md
#
#   # Quiet mode (only show errors, not each fix):
#   script/fix_markdown.rb --quiet docs/myfile.md
#
# AUTOMATICALLY FIXES:
#   - MD031: Fenced code blocks should be surrounded by blank lines
#   - MD022: Headers should be surrounded by blank lines
#   - MD032: Lists should be surrounded by blank lines
#   - MD023: Headers must start at the beginning of the line
#   - MD012: Multiple consecutive blank lines
#
# DOES NOT FIX (requires manual intervention):
#   - MD001: Header levels should only increment by one level at a time
#   - MD025: Multiple top level headers in the same document
#   - MD005: Inconsistent indentation for list items at the same level
#   - MD046: Code block style (fenced vs indented)
#
# RECOMMENDED WORKFLOW:
#   1. Create or edit markdown file
#   2. Run: script/fix_markdown.rb <file>
#   3. Run: mdl <file>  # Check for remaining errors
#   4. Manually fix any remaining errors that the script couldn't handle
#
# OPTIONS:
#   --dry-run    Show what would be fixed without modifying the file
#   --quiet      Only show summary, not individual fixes
#   --verbose    Show detailed information about fixes (default)
#   --help       Show this help message

require 'optparse'
require 'fileutils'

# Parse command line options
options = {
  dry_run: false,
  verbose: true
}

option_parser =
  OptionParser.new do |opts|
    opts.on('--dry-run', 'Show what would be fixed without modifying files') do
      options[:dry_run] = true
    end

    opts.on('--quiet', 'Only show summary, not individual fixes') do
      options[:verbose] = false
    end

    opts.on('--verbose', 'Show detailed information (default)') do
      options[:verbose] = true
    end

    opts.on('--help', 'Show this help message') do
      help_lines = File.read(__FILE__).split("\n")[7..45].map { |l| l.sub(/^# ?/, '') }
      puts help_lines.join("\n")
      exit 0
    end
  end
option_parser.parse!

# rubocop:disable Metrics/AbcSize, Metrics/MethodLength
def fix_markdown(input_file, output_file, dry_run: false, verbose: true)
  lines = File.readlines(input_file)
  fixed_lines = []
  fixes_made = 0
  i = 0
  in_code_fence = false # Track whether we're inside a code block

  while i < lines.length
    line = lines[i]
    prev_line = i.positive? ? lines[i - 1] : nil
    next_line = i < lines.length - 1 ? lines[i + 1] : nil

    # Check if current line is a code fence (before any other processing)
    # Markdown supports both ``` (backticks) and ~~~ (tildes)
    is_code_fence = line.strip.start_with?('```', '~~~')

    # Track if we're entering or exiting a code fence
    # This must be done BEFORE toggling the state
    entering_code_fence = is_code_fence && !in_code_fence
    exiting_code_fence = is_code_fence && in_code_fence

    # Toggle code fence state
    if is_code_fence
      in_code_fence = !in_code_fence
    end

    # Skip processing content inside code fences (except for fence lines themselves)
    unless in_code_fence && !is_code_fence
      # MD023: Remove leading spaces from headers (only outside code blocks)
      if line =~ /^\s+(#+\s+.+)$/
        line = "#{Regexp.last_match(1)}\n"
        fixes_made += 1
        warn "Fixed MD023 at line #{i + 1}: removed leading spaces from header" if verbose
      end
    end

    # Check if current line is a header (only when not in code fence)
    is_header = !in_code_fence && line =~ /^#+\s+.+/

    # Check if current line starts a list
    # For ordered lists, require non-whitespace after the period (not just newline)
    is_list_start = line =~ /^(\s*)[-*+]\s+/ || line =~ /^(\s*)\d+\.\s+\S/

    # Check if current line is a list continuation (indented text, not a list marker)
    is_list_continuation = line =~ /^\s+\S/ && !is_list_start && !is_header && !is_code_fence

    # Check if previous line is blank
    prev_blank = prev_line.nil? || prev_line.strip.empty?

    # Check if next line is blank
    next_blank = next_line.nil? || next_line.strip.empty?

    # Check if previous line is part of a list (item or continuation)
    prev_is_list = prev_line && (prev_line =~ /^(\s*)[-*+]\s+/ || prev_line =~ /^(\s*)\d+\.\s+\S/ ||
                                 (prev_line =~ /^\s+\S/ && !prev_blank))

    # Check if next line is part of a list (item or continuation)
    next_is_list = next_line && (next_line =~ /^(\s*)[-*+]\s+/ || next_line =~ /^(\s*)\d+\.\s+\S/ ||
                                 (next_line =~ /^\s+\S/ && !next_blank))

    # MD031: Add blank line before code fence if missing
    # Only add before OPENING fence (entering a code block)
    if entering_code_fence && !prev_blank && prev_line
      # Don't add if previous line is also a code fence (closing then opening)
      unless prev_line.strip.start_with?('```', '~~~')
        fixed_lines << "\n"
        fixes_made += 1
        warn "Fixed MD031 at line #{i + 1}: added blank before code fence" if verbose
      end
    end

    # MD022: Add blank line before header if missing
    if is_header && !prev_blank && prev_line
      # Don't add if we're right after another header or horizontal rule
      unless prev_line =~ /^#+\s+/ || prev_line.strip == '---'
        fixed_lines << "\n"
        fixes_made += 1
        warn "Fixed MD022 at line #{i + 1}: added blank before header" if verbose
      end
    end

    # MD032: Add blank line before list if missing
    # Only add if transitioning FROM non-list TO list (and not inside code block)
    if is_list_start && !in_code_fence && !prev_blank && prev_line && !prev_is_list
      fixed_lines << "\n"
      fixes_made += 1
      warn "Fixed MD032 at line #{i + 1}: added blank before list" if verbose
    end

    # Add the current line
    fixed_lines << line

    # MD031: Add blank line after code fence if missing
    # Only add after CLOSING fence (exiting a code block)
    if exiting_code_fence && !next_blank && next_line
      # Don't add if next line is also a code fence
      unless next_line.strip.start_with?('```', '~~~')
        fixed_lines << "\n"
        fixes_made += 1
        warn "Fixed MD031 at line #{i + 2}: added blank after code fence" if verbose
      end
    end

    # MD022: Add blank line after header if missing
    if is_header && !next_blank && next_line
      # Don't add if next line is another header, horizontal rule, or code fence
      unless next_line =~ /^#+\s+/ || next_line.strip == '---' ||
             next_line.strip.start_with?('```') || next_line.strip.start_with?('~~~')
        fixed_lines << "\n"
        fixes_made += 1
        warn "Fixed MD022 at line #{i + 2}: added blank after header" if verbose
      end
    end

    # MD032: Add blank line after list if transitioning FROM list TO non-list
    # Current line is a list item/continuation AND next line is NOT part of the list
    # (and not inside code block)
    if (is_list_start || is_list_continuation) && !in_code_fence && next_line && !next_blank && !next_is_list
      fixed_lines << "\n"
      fixes_made += 1
      warn "Fixed MD032 at line #{i + 2}: added blank after list" if verbose
    end

    i += 1
  end

  # Post-processing: Remove consecutive blank lines (MD012)
  final_lines = []
  prev_was_blank = false

  fixed_lines.each do |current_line|
    is_blank = current_line.strip.empty?

    # Skip if this is a blank line and previous was also blank
    if is_blank && prev_was_blank
      fixes_made += 1
      warn 'Fixed MD012: removed consecutive blank line' if verbose
      next
    end

    final_lines << current_line
    prev_was_blank = is_blank
  end

  # Write fixed content (unless dry-run)
  if dry_run
    puts "\n[DRY RUN] Would make #{fixes_made} fixes to: #{output_file}"
    puts '  Run without --dry-run to apply changes'
  else
    File.write(output_file, final_lines.join)
    puts "\n✓ Fixed #{fixes_made} markdown issues in: #{output_file}"
    puts "  Review changes with: git diff #{output_file}" if output_file == input_file
  end

  fixes_made
rescue Errno::ENOENT => e
  warn "Error: File not found - #{e.message}"
  exit 1
rescue Errno::EACCES => e
  warn "Error: Permission denied - #{e.message}"
  exit 1
rescue StandardError => e
  warn "Error: #{e.class} - #{e.message}"
  warn e.backtrace.join("\n") if verbose
  exit 1
end
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength

# Main execution
if ARGV.empty?
  puts "Usage: #{$PROGRAM_NAME} [OPTIONS] FILE [FILE]"
  puts 'Run with --help for detailed usage information'
  exit 1
end

# Separate file arguments from options
file_args = ARGV.reject { |arg| arg.start_with?('--') }

if file_args.empty?
  puts 'Error: No input file specified'
  puts "Usage: #{$PROGRAM_NAME} [OPTIONS] FILE [FILE]"
  exit 1
end

input_file = file_args.first
output_file = file_args[1] || input_file

unless File.exist?(input_file)
  puts "Error: Input file not found: #{input_file}"
  exit 1
end

unless File.readable?(input_file)
  puts "Error: Cannot read input file: #{input_file}"
  exit 1
end

puts "Fixing markdown errors in: #{input_file}" if options[:verbose]
fix_markdown(input_file, output_file, **options)
