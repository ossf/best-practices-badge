#!/usr/bin/env ruby
# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Extract all non-empty justification texts from the database
# Usage: rails runner script/extract_justifications.rb [output_file]

output_file = ARGV.first || ',justifications.txt'

# Get all justification column names
justification_columns =
  Project.column_names.select do |col|
    col.end_with?('_justification')
  end

puts "Found #{justification_columns.length} justification columns"
puts "Extracting non-empty justifications to #{output_file}..."

File.open(output_file, 'w') do |f|
  justification_columns.each do |column|
    # Find all non-empty values for this column
    Project.where.not(column => [nil, '']).find_each do |project|
      justification_text = project.public_send(column)
      next if justification_text.blank?

      # Write one justification per line
      f.puts justification_text
    end
  end
end

# Count total lines written
total_count = File.readlines(output_file).count
puts "Extracted #{total_count} non-empty justifications to #{output_file}"
