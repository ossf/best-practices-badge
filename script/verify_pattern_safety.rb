#!/usr/bin/env ruby
# frozen_string_literal: true

# Verify pattern doesn't match URLs

# To use this:
# get the database
# Use rails runner script/xtract_justifications.rb
# - This generates ,justifications.txt (1 justification/line)
# Use: rails runner compare_markdown_output.rb
# - Generates ,justifications.truly-ok which don't need Markdown processing
# - Generates ,justifications.not-ok which DOES need Markdown processing
# Run this script to determine if `pattern`

# MARKDOWN_UNNECESSARY = %r{\A
#   (?!(\d+\.|\-|\*|\+|\#+)\s) # numbered lists, un-numbered lists, headings
#   (?!\-\-\-) # Horizontal lines
#   (//\040)? # Allow our comment marker at the start
#   ([A-Za-z0-9\040\,\;\'\"\!\(\)\-\?\%\+\@]|\.\040|\:\040|\&\040)+
#   \.? # Optional final period
#   \n?\z}x

# ============================================================
# The following pattern is designed to *only* match
# a line that we KNOW cannot require markdown processing.
# MODIFY THIS PATTERN TO TEST!

# This pattern matches text that we KNOW does not require markdown processing.
# We do this check as an optimization to skip calling the markdown
# processor in most cases when it's clearly unnecessary.
# In particular, note that we have to handle period and colon specially,
# because www.foo.com and http://foo.com *do* need to be processed
# as markdown.

# In our measures this matches 83.87% of the justification text in our system.
# That's a pretty good optimization that is not *too* hard to read and verify.
# It's *okay* to pass something to the markdown processor, we just try
# to ensure that most such requests are needed.

# IMPORTANT CONSTRAINTS:
# - Must NOT match numbered lists (e.g., "1. Item")
#   markdown formats them as <ol><li>.
# - Must NOT match un-numbered lists (e.g., "* Item")
# - Must NOT match headings ("# foo")
# - Must NOT match URLs (e.g., "https://github.com/foo") because
#   markdown auto-links them (autolink: true option).
# - Must NOT match implied domain names like www.foo.com or email addresses.
#   (autolink: true option).
#   We avoid matching possible domain names and URLs and email addresses
#   by only allowing a period or colon if it's followed by a space, and
#   only allowing "/" if it's followed by an alphanumeric or a "slash space".
#   We also don't accept "@".
# - Must NOT require HTML escaping, e.g., no "<" or ">".
#   We can allow "&" followed by a space, as modern HTML knows that can't
#   be an entity. We can allow single-quotes and double-quotes since
#   this is not in an attribute and we aren't implementing smarty quotes.

MARKDOWN_UNNECESSARY = %r{\A
  (?!(\d+\.|\-|\*|\+|\#+)\s) # numbered lists, un-numbered lists, headings
  (?!\-\-\-) # Horizontal lines
  ([A-Za-z0-9\040\,\;\'\"\!\(\)\-\?\%\+]|
   \.\040|\:\040|\&\040|/(/\040|[A-Za-z0-9]))+
  \.? # Optional final period
  \z}x
# ============================================================

dangerous_examples = [
  'git://sourceware.org/git',
  'https://github.com/foo',
  'http://example.com',
  'file:///home/test',
  'ftp://files.example.org',
  '1. Numbered List',
  '* Bullet list',
  '- Bullet list',
  '# Header',
  '## Header',
  'www.foo.com',
  'For more info see www.foo.com'
]

safe_examples = [
  'Given only https: URLs.',
  'The MIT license is approved.',
  'No release notes file found.',
  '// Given an http: URL.',
  'Note: this is important.'
]

puts "Pattern: #{MARKDOWN_UNNECESSARY.inspect}"
puts

# Track overall failure status
pattern_failed = false

puts '=' * 70
puts 'Testing URLs and markdown (should NOT match):'
dangerous_examples.each do |text|
  matches = text.match?(MARKDOWN_UNNECESSARY)
  if matches
    pattern_failed = true
    puts "  #{text.inspect}: ❌ MATCHES (BAD!)"
  else
    puts "  #{text.inspect}: ✅ no match (good)"
  end
end

puts
puts '=' * 70
puts 'Testing safe text (should match):'
safe_examples.each do |text|
  matches = text.match?(MARKDOWN_UNNECESSARY)
  status = matches ? '✅ MATCHES (good)' : '❌ no match (missed opportunity)'
  puts "  #{text.inspect}: #{status}"
end

# Load and test against actual justifications
puts
puts '=' * 70
puts 'Testing against actual justifications:'
puts

ok_file = ',justifications.truly-ok'
not_ok_file = ',justifications.not-ok'

if File.exist?(ok_file) && File.exist?(not_ok_file)
  ok_lines = File.readlines(ok_file, chomp: true)
  not_ok_lines = File.readlines(not_ok_file, chomp: true)

  puts "Loaded #{ok_lines.size} truly-ok justifications"
  puts "Loaded #{not_ok_lines.size} not-ok justifications"
  puts

  # Test not-ok lines (should NOT match - these need markdown processing)
  not_ok_matches = not_ok_lines.grep(MARKDOWN_UNNECESSARY)

  if not_ok_matches.any?
    pattern_failed = true
    puts "❌ FAILURE: Pattern matched #{not_ok_matches.size} not-ok justifications!"
    puts '   These require markdown processing and should NOT match:'
    not_ok_matches.first(5).each do |line|
      display = line.length > 60 ? "#{line[0, 60]}..." : line
      puts "   - #{display.inspect}"
    end
    puts "   (showing first 5 of #{not_ok_matches.size})" if not_ok_matches.size > 5
  else
    puts '✅ Good: Pattern matched 0 not-ok justifications'
  end

  puts

  # Test ok lines (should match - more is better)
  ok_matches = ok_lines.grep(MARKDOWN_UNNECESSARY)
  ok_percentage = (ok_matches.size.to_f / ok_lines.size * 100).round(2)

  puts "Pattern matched #{ok_matches.size} / #{ok_lines.size} truly-ok justifications"
  puts "Coverage: #{ok_percentage}% (higher is better)"

  if ok_percentage < 50
    puts '⚠️  Warning: Low coverage - pattern may be too restrictive'
  elsif ok_percentage >= 80
    puts '✅ Good coverage!'
  end

  # Show most common non-matching text to help identify improvements
  ok_non_matches = ok_lines.grep_v(MARKDOWN_UNNECESSARY)
  if ok_non_matches.any?
    puts
    puts 'Most common missed opportunities (top 10):'
    frequency = ok_non_matches.tally
    frequency.sort_by { |_line, count| -count }
             .first(40).each do |line, count|
      display = line.length > 70 ? "#{line[0, 70]}..." : line
      puts "  #{count}x: #{display.inspect}"
    end
    puts "  (#{ok_non_matches.size} unique non-matches total)"
  end
else
  puts '⚠️  Files not found. Run compare_markdown_output.rb first to generate:'
  puts "   #{ok_file}"
  puts "   #{not_ok_file}"
end

# Final verdict
puts
puts '=' * 70
puts '=' * 70
if pattern_failed
  puts '❌❌❌ PATTERN FAILED ❌❌❌'
  puts 'Pattern matched content that should NOT match!'
  puts 'This pattern is UNSAFE and must not be used.'
else
  puts '✅✅✅ PATTERN PASSED ✅✅✅'
  puts 'Pattern did not match any content that requires markdown processing.'
  puts 'This pattern is safe to use.'
end
puts '=' * 70
puts '=' * 70
