# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Criteria data pipeline — overview
#
# This initializer is the first step in a multi-stage pipeline that makes
# criteria data available both server-side (Ruby) and client-side (JavaScript):
#
# 1. SOURCE  criteria/criteria.yml: metal levels (passing/silver/gold)
#            criteria/baseline_criteria.yml: baseline levels (baseline-1/2/3)
#
# 2. BOOT    THIS FILE: loads both YAML files at Rails boot
#            Produces four constants:
#              FullCriteriaHash: raw merged data (all fields)
#              CriteriaHash: filtered runtime data (i18n fields stripped)
#              YAML_METAL_LEVEL_KEYS: metal level key array used by routing
#              YAML_BASELINE_LEVEL_KEYS: baseline level key array for routing
#            Also consumed by config/initializers/01_section_names.rb, which
#            uses YAML_*_LEVEL_KEYS to build routing constraints and canonical
#            level name mappings.
#
# 3. MODEL   app/models/criteria.rb: wraps CriteriaHash in Criteria objects
#            Criteria.active(level) returns non-future, non-obsolete criteria.
#            Criteria.for_js returns CriteriaHash with
#            locale translations merged.
#
# 4. BRIDGE  app/assets/javascripts/criteria.js.erb
#            Embeds Criteria.for_js as CRITERIA_HASH_FULL (and translations as
#            TRANSLATION_HASH_FULL) into a JavaScript file served to browsers.
#
# 5. CLIENT  app/assets/javascripts/project-form.js
#            Reads CRITERIA_HASH_FULL to compute live badge percentages and
#            drive the form UX. Several functions here mirror methods in
#            app/models/project.rb
#            (e.g. getCriterionResult ↔ get_criterion_result)
#            keep them in sync when changing badge logic.

require 'yaml'
# Load in entire criteria.yml, which keys off the major/minor groups
# NOTE: Using YAML.safe_load_file for security
metal_criteria = YAML.safe_load_file(
  'criteria/criteria.yml',
  permitted_classes: [Symbol],
  aliases: true
)

# Load baseline criteria if file exists
baseline_file = 'criteria/baseline_criteria.yml'
begin
  if File.exist?(baseline_file)
    baseline_criteria = YAML.safe_load_file(
      baseline_file,
      permitted_classes: [Symbol],
      aliases: true
    )
    # Remove metadata key before merging (it's not a criteria level)
    baseline_criteria.delete('_metadata')
    # Merge baseline criteria into metal criteria
    FullCriteriaHash = metal_criteria.merge(baseline_criteria).with_indifferent_access.freeze
  else
    FullCriteriaHash = metal_criteria.with_indifferent_access.freeze
  end
rescue Errno::ENOENT
  # Handle race condition if file is deleted between exist? check and load
  FullCriteriaHash = metal_criteria.with_indifferent_access.freeze
end

criteria_hash = {}.with_indifferent_access
FullCriteriaHash.each do |level, level_value|
  next if level == '_metadata' # Skip metadata entry from baseline criteria

  criteria_hash[level] = {}.with_indifferent_access
  level_value.each do |major, major_value|
    major_value.each do |minor, criteria|
      criteria.each do |criterion_key, criterion_data|
        # For baseline criteria, filter out fields not recognized by Criteria model
        # Description/details/placeholders are loaded from locale files via i18n
        # Baseline-specific metadata fields are also filtered out
        filtered_data = criterion_data.dup
        if level.to_s.start_with?('baseline-')
          # Remove i18n fields (loaded from locale files)
          filtered_data.delete('description')
          filtered_data.delete('details')
          filtered_data.delete('met_placeholder')
          filtered_data.delete('unmet_placeholder')
          filtered_data.delete('na_placeholder')
          # Remove baseline-specific metadata fields
          filtered_data.delete('external_id')
          filtered_data.delete('baseline_id')
          filtered_data.delete('baseline_maturity_levels')
          filtered_data.delete('external_mappings')
          filtered_data.delete('original_id')
        end

        criteria_hash[level][criterion_key] = filtered_data
        criteria_hash[level][criterion_key][:major] = major
        criteria_hash[level][criterion_key][:minor] = minor
      end
    end
  end
end

CriteriaHash = criteria_hash.freeze

# Export level names derived from YAML for use by other initializers
# These are used by routing and validation logic

# Metal criteria uses numeric keys: '0', '1', '2'
YAML_METAL_LEVEL_KEYS = metal_criteria.keys.sort.freeze

# Baseline criteria uses canonical names: 'baseline-1', 'baseline-2', etc.
YAML_BASELINE_LEVEL_KEYS =
  if baseline_criteria.present?
    baseline_criteria.keys.sort.freeze
  else
    [].freeze
  end
