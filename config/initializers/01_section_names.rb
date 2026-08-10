# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# **CANONICAL LISTS** of valid criteria level names and routing constants
#
# This file defines the authoritative list of criteria levels and sections
# used throughout the application. These constants are used by:
# - config/routes.rb - to build routing constraints
# - app/controllers - for validation and redirects
# - config/initializers/cors.rb - to build CORS resource patterns
#
# This file is named with "00_" prefix to ensure it loads early, but AFTER
# 00_criteria_hash.rb which loads the YAML and exports level keys.
#
# IMPORTANT: Level names are DERIVED from the YAML criteria files via
# constants exported from 00_criteria_hash.rb (YAML_METAL_LEVEL_KEYS and
# YAML_BASELINE_LEVEL_KEYS). This ensures YAML is loaded only once.
#
# All constants are in the Sections:: namespace to avoid global pollution
# and provide clear, canonical naming.
#
# When adding new criteria levels:
# 1. Add criteria to the appropriate YAML file
# 2. The level keys will auto-update via 00_criteria_hash.rb
# 3. Update Sections::REDIRECTS if adding obsolete synonyms
# 4. Update Sections::SPECIAL_FORMS if adding non-criteria sections

module Sections
  # Map of obsolete names to their canonical equivalents
  # This mapping is the authoritative source for canonical names
  # NOTE: The YAML files use numeric keys ('0', '1', '2')
  # but we route using canonical names ('passing', 'silver', 'gold').
  # We don't change the YAML file keys because that's entirely internal
  # and changing them would severely impact our long-suffering human
  # translators.
  REDIRECTS = {
    '0' => 'passing',
    '1' => 'silver',
    '2' => 'gold',
    'bronze' => 'passing'
  }.freeze

  # Mapping of synonyms to internal ids.
  SYNONYMS_TO_INTERNAL = { 'bronze' => '0' }.freeze

  # Synonyms for existing levels (obsolete names beyond numeric keys)
  SYNONYMS = SYNONYMS_TO_INTERNAL.keys.freeze

  # Special forms (non-criteria sections not tied to a criteria level)
  SPECIAL_FORMS = %w[permissions].freeze

  # Use level keys exported from 00_criteria_hash.rb (which loaded the YAML)
  # This avoids loading YAML twice - single source of truth

  # Metal badge levels - map numeric YAML keys to canonical names
  # The YAML uses '0', '1', '2' but we want canonical
  # E.g., ['passing', 'silver', 'gold']
  METAL_LEVEL_NAMES = YAML_METAL_LEVEL_KEYS.map { |k| REDIRECTS[k] || k }
                                           .freeze

  # Metal level numbers (obsolete keys still used in YAML)
  # E.g., ['0', '1', '2']
  METAL_LEVEL_NUMBERS = YAML_METAL_LEVEL_KEYS

  # Baseline badge levels (already use canonical names in YAML)
  # E.g., ['baseline-1', 'baseline-2', 'baseline-3']
  BASELINE_LEVEL_NAMES = YAML_BASELINE_LEVEL_KEYS

  # All criteria levels (canonical names only - no obsolete numbers)
  # Built up from canonical level names derived from YAML
  ALL_CRITERIA_LEVEL_NAMES = (METAL_LEVEL_NAMES + BASELINE_LEVEL_NAMES).freeze

  # Map criteria level names to their corresponding *_saved flag names
  # Used for first-edit automation tracking
  # Automatically derived from level names to support new levels easily
  LEVEL_SAVED_FLAGS = {}.tap do |hash|
    METAL_LEVEL_NAMES.each do |level|
      hash[level] = :"#{level}_saved"
    end
    BASELINE_LEVEL_NAMES.each do |level|
      # baseline-1 → baseline_1_saved
      flag_name = level.tr('-', '_') + '_saved'
      hash[level] = flag_name.to_sym
    end
  end.freeze

  # All canonical section names (criteria levels + special sections)
  # These are the preferred names that we redirect to - no obsolete names
  ALL_CANONICAL_NAMES = (ALL_CRITERIA_LEVEL_NAMES + SPECIAL_FORMS).freeze

  # Obsolete section names (deprecated, should redirect to canonical names)
  # Built up from obsolete numeric keys and synonym names
  OBSOLETE_NAMES = (METAL_LEVEL_NUMBERS + SYNONYMS).freeze

  # Valid section names (all names we accept - canonical + obsolete)
  # Used for validation where we accept obsolete names (then redirect to canonical)
  VALID_NAMES = (ALL_CANONICAL_NAMES + OBSOLETE_NAMES).freeze

  # Regex matching only primary/canonical section names
  # Used in controller validation and routes that reject obsolete names
  PRIMARY_SECTION_REGEX = Regexp.union(ALL_CANONICAL_NAMES)

  # Regex matching all valid section names (canonical + obsolete synonyms)
  # Used in routes.rb for :section parameter validation
  # (accepts obsolete for redirect)
  VALID_SECTION_REGEX = Regexp.union(VALID_NAMES)

  # Default section to use when none specified
  DEFAULT_SECTION = 'passing'

  # Valid starting sections for new projects (first level of each series)
  STARTING_SECTIONS = [
    METAL_LEVEL_NAMES.first,
    BASELINE_LEVEL_NAMES.first
  ].freeze

  # Reverse mapping: canonical name -> internal numeric key
  # E.g., 'passing' -> '0', 'silver' -> '1', 'gold' -> '2'
  # Pre-computed once to avoid recalculation on every request
  # Filter out synonyms (like 'bronze') before inverting to avoid ambiguity
  CANONICAL_TO_INTERNAL = REDIRECTS.except(*SYNONYMS).invert.freeze

  # Complete mapping: any valid input -> canonical name
  # Pre-computed for O(1) lookup in normalize_criteria_level
  # Maps obsolete names and canonical names to their canonical form
  INPUT_TO_CANONICAL = REDIRECTS.merge(
    ALL_CANONICAL_NAMES.to_h { |name| [name, name] }
  ).freeze

  # All forms that are already in internal representation (identity mappings)
  # E.g., ['0', '1', '2', 'baseline-1', 'baseline-2', 'baseline-3',
  # 'permissions']
  INTERNAL_FORMS = (METAL_LEVEL_NUMBERS + BASELINE_LEVEL_NAMES + SPECIAL_FORMS).freeze

  # Complete mapping: any valid input -> internal form
  # Pre-computed for O(1) lookup in criteria_level_to_internal
  # Maps canonical, internal, and obsolete names to their internal form
  INPUT_TO_INTERNAL = CANONICAL_TO_INTERNAL.merge(
    INTERNAL_FORMS.to_h { |name| [name, name] }
  ).merge(
    SYNONYMS_TO_INTERNAL
  ).freeze

  # Pre-computed mapping: section name -> type (:metal, :baseline, :special)
  # Used for O(1) lookup in section_type method
  SECTION_TYPE_MAP = METAL_LEVEL_NAMES.index_with(:metal)
                                      .merge(METAL_LEVEL_NUMBERS.index_with(:metal))
                                      .merge(SYNONYMS.index_with(:metal))
                                      .merge(BASELINE_LEVEL_NAMES.index_with(:baseline))
                                      .merge(SPECIAL_FORMS.index_with(:special))
                                      .freeze

  # Returns the type of a section: :metal, :baseline, :special, or nil
  # @param section [String] the section name (canonical, obsolete, or internal)
  # @return [Symbol, nil] :metal, :baseline, :special, or nil if invalid
  def self.section_type(section)
    SECTION_TYPE_MAP[section.to_s]
  end

  # Rank of each badge level for comparison purposes (higher = better).
  # Shared by the controller (gain/loss detection on save) and the model
  # (loss notification in update_all_badge_percentages).
  BADGE_LEVEL_RANK = {
    'in_progress' => 0,
    # Metal series
    'passing' => 1,
    'silver' => 2,
    'gold' => 3,
    # Baseline series
    'baseline-1' => 1,
    'baseline-2' => 2,
    'baseline-3' => 3
  }.freeze

  # Returns true if the change from old_level to new_level is a loss of status.
  # Unknown levels default to rank 0. Cross-series comparisons (e.g. metal to
  # baseline) return false since they are different badge types, not a downgrade.
  # @param old_level [String] previous badge level
  # @param new_level [String] new badge level
  # @return [Boolean]
  def self.badge_level_lost?(old_level, new_level)
    (BADGE_LEVEL_RANK[new_level] || 0) < (BADGE_LEVEL_RANK[old_level] || 0)
  end

  # Authoritative mapping from badge series type to its badge image URL suffix.
  # This is the single source of truth for badge URL path endings
  # (e.g., /projects/1/badge vs /projects/1/baseline).
  # Add an entry here when introducing a new badge series.
  BADGE_URL_SUFFIX = {
    metal: 'badge',
    baseline: 'baseline'
  }.freeze

  # Returns the badge image URL suffix for the given section.
  # @param section [String] the section name (canonical, obsolete, or internal)
  # @return [String] the URL suffix, e.g. 'badge' or 'baseline'
  def self.badge_url_suffix(section)
    BADGE_URL_SUFFIX.fetch(section_type(section), 'badge')
  end
end
