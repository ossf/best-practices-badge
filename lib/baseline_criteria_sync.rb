# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'net/http'
require 'json'
require 'yaml'
require 'fileutils'

# rubocop:disable Rails/Output
# This is a command-line utility script, not Rails code.
# Using puts for user output is appropriate here.

# Synchronizes baseline criteria from official OpenSSF source
class BaselineCriteriaSync
  attr_reader :source_url, :criteria_file, :mapping_file, :cache_dir

  def initialize
    @source_url = BASELINE_CONFIG[:source_url]
    @criteria_file = BASELINE_CONFIG[:criteria_file]
    @mapping_file = BASELINE_CONFIG[:mapping_file]
    @cache_dir = BASELINE_CONFIG[:cache_dir]
    @metadata_file = BASELINE_CONFIG[:sync_metadata_file]
  end

  # Main sync method
  def sync
    puts "NOTE: Full sync from #{source_url} not yet implemented."
    puts 'For Phase 2, create baseline_criteria.yml manually.'
    puts 'See docs/baseline_details.md section 2.2 for stub format.'
  end

  # Class method to load sync metadata
  def self.load_sync_metadata
    metadata_file = BASELINE_CONFIG[:sync_metadata_file]
    return unless File.exist?(metadata_file)

    JSON.parse(File.read(metadata_file))
  rescue JSON::ParserError, Errno::ENOENT
    nil
  end
end

# rubocop:enable Rails/Output
