# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'net/http'
require 'json'
require 'yaml'
require 'fileutils'

# Require baseline lib files
require_relative '../baseline_criteria_sync'
require_relative '../baseline_i18n_extractor'
require_relative '../baseline_migration_generator'
require_relative '../baseline_criteria_validator'

namespace :baseline do
  desc 'Download and sync baseline criteria from official source'
  task sync: :environment do
    BaselineCriteriaSync.new.sync
  end

  desc 'Extract i18n strings from baseline_criteria.yml to config/locales/en.yml'
  task extract_i18n: :environment do
    BaselineI18nExtractor.new.extract
  end

  desc 'Show current baseline criteria version'
  task version: :environment do
    metadata = BaselineCriteriaSync.load_sync_metadata
    if metadata
      puts "Current baseline version: #{metadata['version']}"
      puts "Last synced: #{metadata['synced_at']}"
      puts "Source: #{metadata['source_url']}"
    else
      puts 'No baseline criteria synced yet.'
    end
  end

  desc 'Generate migration for new baseline criteria'
  task generate_migration: :environment do
    generator = BaselineMigrationGenerator.new
    generator.generate
  end

  desc 'Validate baseline criteria mapping'
  task validate: :environment do
    validator = BaselineCriteriaValidator.new
    if validator.validate
      puts '✓ Baseline criteria validation passed'
    else
      puts '✗ Baseline criteria validation failed'
      validator.errors.each { |error| puts "  - #{error}" }
      exit 1
    end
  end
end
