# Baseline Implementation - Detailed Plan

This document provides a detailed implementation plan for adding support for the OpenSSF Baseline criteria to the Best Practices Badge project, as outlined in `baseline_plan.md`.

Like all plans, we will need to make adjustments as we go. The purpose of creating this plan is to reduce the amount of rework necessary to complete it. This plan was created after giving Claude Code detailed information, combined with later interactions. In particular, Claude originally wanted to change our internal YAML keys, but that would have caused havoc on our poor long-suffering translators (as all their keys would have been renamed), so human review led to intentionally *not* doing that.

## Table of Contents

### Background

1. [Current Architecture Overview](#current-architecture-overview)
2. [Baseline Criteria Sync System](#baseline-criteria-sync-system)

### Implementation Phases

3. [Phase 1: URL and Routing Migration](#phase-1-url-and-routing-migration)
4. [Phase 2: Database Schema for Baseline-1](#phase-2-database-schema-for-baseline-1)
5. [Phase 3: Full Baseline-1 Support](#phase-3-full-baseline-1-support)
6. [Phase 4: Baseline Badge Images](#phase-4-baseline-badge-images)
7. [Phase 5: Baseline-2 and Baseline-3](#phase-5-baseline-2-and-baseline-3)
9. [Phase 6: Translation Support](#phase-7-translation-support)
8. [Phase 7: Trivial Automation](#phase-6-automation)
10. [Phase 8: Project Search and Filtering](#phase-8-project-search-and-filtering)

### Supporting Information

11. [Testing Strategy](#testing-strategy)
12. [Rollback and Safety](#rollback-and-safety)
13. [Implementation Order Summary](#implementation-order-summary)
14. [Files Reference](#files-reference)
15. [Lessons from Code Review](#lessons-from-code-review)
16. [Conclusion](#conclusion)

---

## Current Architecture Overview

### Key Components

1. **Criteria Storage**: `criteria/criteria.yml` - YAML file with structure:
   - Top level: `'0'` (passing), `'1'` (silver), `'2'` (gold)
   - Loaded by `config/initializers/criteria_hash.rb` at Rails startup
   - Flattened into `CriteriaHash` with level->criterion mapping
   - Each level contains major groups, minor groups, and criteria
   - Each criterion has: category (MUST/SHOULD/SUGGESTED), description, details, justification requirements

2. **Database Fields**:
   - Each criterion gets two columns: `{criterion_name}_status` and `{criterion_name}_justification`
   - Badge percentages: `badge_percentage_0`, `badge_percentage_1`, `badge_percentage_2` (MUST stay numeric)
   - Achievement timestamps: `achieved_passing_at`, `achieved_silver_at`, `achieved_gold_at`
   - **CRITICAL**: Database field names use numeric suffixes (_0, _1, _2) and will continue to do so
   - Baseline will add: `badge_percentage_baseline_1`, `badge_percentage_baseline_2`, `badge_percentage_baseline_3`

3. **URL Structure** (current):
   - Routes use `VALID_CRITERIA_LEVEL ||= /[0-2]/` in `config/routes.rb:17`
   - Controllers use `set_criteria_level` to validate and default to '0'
   - URLs: `/projects/{id}/{criteria_level}` where criteria_level is 0, 1, or 2
   - JavaScript (project-form.js) parses criteria_level from URL query params

4. **Models**:
   - `Project` model (app/models/project.rb):
     - `BADGE_LEVELS = %w[in_progress passing silver gold]`
     - `LEVEL_IDS = ['0', '1', '2']` (strings, not integers)
     - `update_badge_percentages` iterates through LEVEL_IDS
     - `calculate_badge_percentage(level)` accepts level and passes to `Criteria.active(level)`
   - `Criteria` model (app/models/criteria.rb): Loads and instantiates criteria from YAML
   - `Badge` model (app/models/badge.rb): Generates SVG badges from static files

5. **Views**:
   - Form partials: `_form_0.html.erb`, `_form_1.html.erb`, `_form_2.html.erb`
   - Each form directly references `project.badge_percentage_0`, etc.
   - Show view (show.html.erb) renders: `render "form_#{@criteria_level}"`
   - `_form_early.html.erb` has hardcoded links: `?criteria_level=1`, `?criteria_level=2`

6. **Badge Generation**:
   - Badge model loads pre-generated SVG files: `app/assets/images/badge_static_{level}.svg`
   - Route: `/projects/{id}/badge` (no locale, for CDN caching)
   - `BADGE_PROJECT_FIELDS` constant lists fields needed for badge queries
   - Supports percentages (0-99) and levels (passing, silver, gold)

### Critical Insight: Three-Layer Mapping

The architecture uses THREE different naming schemes that must be kept in sync:

1. **URL/Route Layer**: `passing`, `silver`, `gold`, `baseline-1`, etc. (user-facing, in URLs)
2. **Data/Internal Layer**: `'0'`, `'1'`, `'2'`, `'baseline-1'`, etc. (YAML keys, I18n keys, internal logic)
3. **Database Layer**: `_0`, `_1`, `_2`, `_baseline_1`, etc. (field name suffixes)

**CRITICAL**: The YAML keys and I18n translation keys MUST remain as `'0'`, `'1'`, `'2'` for the metal series to preserve compatibility with externally-maintained translations. Only URLs are changing to use human-readable names like `passing`, `silver`, `gold`.

**The plan must handle mapping between these layers carefully.**

---

## Baseline Criteria Sync System

**Purpose**: Automatically download, process, and integrate baseline criteria from the official OpenSSF Baseline source, keeping our criteria in sync with upstream changes.

### Why Automated Sync?

The OpenSSF Baseline criteria are:

- Maintained externally by the OpenSSF Security Baseline SIG (part of ORBIT WG)
- Updated periodically (new criteria added, existing ones refined)
- Published in a machine-readable format (JSON/YAML)
- Our source of truth for what baseline criteria projects must meet

**Manual synchronization would be error-prone and time-consuming**. An automated sync system ensures we stay current with baseline updates.

### Hybrid Storage Architecture

**We use a hybrid approach for storing baseline criteria to balance sync simplicity with translation infrastructure:**

1. **Source of Truth**: `criteria/baseline_criteria.yml`
   - Contains ALL baseline criteria fields including `description` and `details`
   - Directly written by the sync process
   - Single file to review when baseline criteria change
   - Has a header comment explaining the hybrid approach

2. **Translation Layer**: `config/locales/en.yml` (and other language files)
   - Contains ONLY `description`, `details`, and placeholder fields for i18n
   - Automatically extracted from `baseline_criteria.yml` via `rake baseline:extract_i18n`
   - Allows baseline criteria to use the same translation workflow as existing criteria
   - Special marker comments (`# BEGIN BASELINE CRITERIA AUTO-GENERATED` and `# END BASELINE CRITERIA AUTO-GENERATED`) delimit the auto-generated section
   - Existing YAML comments outside markers are preserved

3. **Runtime Behavior**:
   - Application loads criteria metadata from `criteria/baseline_criteria.yml`
   - Application loads translatable text from `config/locales/*.yml` (via Rails i18n)
   - Consistent with existing criteria (levels 0, 1, 2)

**Rationale**: This hybrid approach provides:

- Simple sync (writes one file with all data)
- Consistent translation workflow (extracts to locale files like existing criteria)
- Clear separation of concerns (source data vs. localized data)
- Build-time validation (ensures files stay in sync)

### Architecture Overview

The baseline criteria sync system follows this flow:

1. **Source**: OpenSSF Baseline Official Source
   - URL: `https://baseline.openssf.org/versions/YYYY-MM-DD/criteria.json`
   - Published by OpenSSF Security Baseline SIG
   - Machine-readable JSON format

2. **Sync Process**: Rake task `rake baseline:sync`
   - Downloads criteria file from official source
   - Parses content
   - Maps external format to our data model
   - **Intelligently merges** with existing criteria (preserves local customizations)
   - Generates/updates `criteria/baseline_criteria.yml` with ALL fields
   - Only updates requirement/recommendation text from upstream

3. **i18n Extraction**: Rake task `rake baseline:extract_i18n`
   - Reads `description` and `details` from `criteria/baseline_criteria.yml`
   - Updates `config/locales/en.yml` between marker comments
   - Preserves all existing YAML comments and structure
   - Prepares baseline criteria for translation workflow

4. **Generated Outputs**:
   - **`criteria/baseline_criteria.yml`** - Baseline criteria in our YAML format (includes description/details)
   - **`config/locales/en.yml`** - English translations extracted (between markers)
   - **`config/baseline_field_mapping.json`** - Maps baseline IDs to database field names
   - **`.baseline_sync_metadata.json`** - Tracks sync version and timestamp (gitignored)

5. **Optional: Migration Generation**:
   - Rake task `rake baseline:generate_migration`
   - Compares mapping with existing database schema
   - Auto-generates migration for new fields
   - Ensures database stays in sync with criteria

### Baseline Criteria File Structure

**Source URL**: https://baseline.openssf.org/versions/2025-10-10/criteria.json (or latest)

**Expected format** (JSON):

```json

{
  "version": "2025-10-10",
  "levels": {
    "1": {
      "name": "Baseline Level 1",
      "controls": [
        {
          "id": "OSPS-GV-03.01",
          "category": "Governance",
          "subcategory": "Contribution Process",
          "requirement": "While active, the project documentation MUST include an explanation of the contribution process.",
          "recommendation": "Document project participants...",
          "maturity_levels": [1],
          "external_mappings": {
            "bpb": ["B-P-4"]
          }
        }
      ]
    }
  }
}

```

### Sync System Components

#### 1. Baseline Criteria Source Configuration

**New file**: `config/baseline_config.yml`

```yaml

# Configuration for baseline criteria synchronization

baseline:

# Official source URL (can be overridden with environment variable)

  source_url: <%= ENV['BASELINE_CRITERIA_URL'] || 'https://baseline.openssf.org/versions/2025-10-10/criteria.json' %>

# Local cache of downloaded criteria (for comparison/rollback)

  cache_dir: 'tmp/baseline_cache'

# Output locations

  criteria_file: 'criteria/baseline_criteria.yml'
  mapping_file: 'config/baseline_field_mapping.json'

# Field naming rules

  field_prefix: 'baseline_'

# Metadata

  sync_metadata_file: '.baseline_sync_metadata.json'

```

**Load in**: `config/initializers/baseline_config.rb`

```ruby

# frozen_string_literal: true

require 'yaml'
require 'erb'

BASELINE_CONFIG = YAML.safe_load(
  ERB.new(File.read('config/baseline_config.yml')).result,
  aliases: true
).fetch('baseline', {}).with_indifferent_access.freeze

```

#### 2. Rake Task for Syncing

**New file**: `lib/tasks/baseline.rake`

```ruby

# frozen_string_literal: true

# Copyright the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'net/http'
require 'json'
require 'yaml'
require 'fileutils'

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
      puts "No baseline criteria synced yet."
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
      puts "✓ Baseline criteria validation passed"
    else
      puts "✗ Baseline criteria validation failed"
      validator.errors.each { |error| puts "  - #{error}" }
      exit 1
    end
  end
end

```

#### 3. Baseline Criteria Sync Class

**New file**: `lib/baseline_criteria_sync.rb`

```ruby

# frozen_string_literal: true

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
    puts "Syncing baseline criteria from: #{source_url}"

# Download criteria

    criteria_data = download_criteria

# Cache downloaded data

    cache_criteria(criteria_data)

# Parse and transform

    parsed = parse_criteria(criteria_data)

# Check for changes

    if criteria_changed?(parsed)
      puts "Changes detected. Updating local files..."

# Generate our YAML format

      generate_criteria_yaml(parsed)

# Generate field mapping

      generate_field_mapping(parsed)

# Update metadata

      update_sync_metadata(criteria_data)

# Validate

      validate_generated_files

      puts "✓ Sync complete!"
      puts "⚠ Review changes and run: rake baseline:generate_migration"
    else
      puts "✓ No changes detected. Local criteria are up to date."
    end
  end

# Download criteria from official source

  def download_criteria
    uri = URI(source_url)
    response = Net::HTTP.get_response(uri)

    unless response.is_a?(Net::HTTPSuccess)
      raise "Failed to download criteria: #{response.code} #{response.message}"
    end

    response.body
  end

# Cache downloaded data with timestamp

  def cache_criteria(data)
    FileUtils.mkdir_p(cache_dir)
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    cache_file = File.join(cache_dir, "baseline_#{timestamp}.json")
    File.write(cache_file, data)
    puts "Cached to: #{cache_file}"
  end

# Parse JSON/YAML criteria

  def parse_criteria(data)
    JSON.parse(data)
  rescue JSON::ParserError

# Try YAML if JSON fails

    YAML.safe_load(
      data,
      permitted_classes: [Symbol, Date, Time],
      aliases: true
    )
  end

# Transform external format to our criteria structure

  def generate_criteria_yaml(parsed_data)
    criteria = transform_to_our_format(parsed_data)

# Add metadata header

    output = {
      '_metadata' => {
        'source' => 'OpenSSF Baseline',
        'source_url' => source_url,
        'version' => parsed_data['version'],
        'synced_at' => Time.now.iso8601,
        'auto_generated' => true,
        'do_not_edit' => 'This file is auto-generated. Edit source at OpenSSF Baseline.'
      }
    }.merge(criteria)

    File.write(criteria_file, output.to_yaml)
    puts "Generated: #{criteria_file}"
  end

# Transform external format to our internal YAML structure

# IMPORTANT: Preserves local customizations - only updates requirement/recommendation text

  def transform_to_our_format(data)

# Load existing criteria to preserve local customizations

    existing_criteria = load_existing_criteria

    criteria = {}

    data['levels'].each do |level_num, level_data|
      level_key = "baseline-#{level_num}"
      criteria[level_key] = {}

# Group by category

      level_data['controls'].each do |control|
        category = control['category'] || 'General'
        subcategory = control['subcategory'] || 'Requirements'

        criteria[level_key][category] ||= {}
        criteria[level_key][category][subcategory] ||= {}

# Generate field name from control ID

        field_name = generate_field_name(control['id'])

# Check if this criterion already exists locally

        existing_criterion = dig_criterion(existing_criteria, level_key, category, subcategory, field_name)

        if existing_criterion

# MERGE: Preserve existing customizations, only update upstream text

          criteria[level_key][category][subcategory][field_name] = existing_criterion.merge({

# Update from upstream (these change when baseline updates)

            'description' => control['requirement'],
            'details' => control['recommendation'],
            'baseline_maturity_levels' => control['maturity_levels'],
            'external_mappings' => control['external_mappings']

# DO NOT update: category, met_url_required, na_allowed, etc.

# Those may have been customized locally

          })
        else

# NEW CRITERION: Use full defaults

          criteria[level_key][category][subcategory][field_name] = {
            'category' => 'MUST',  # Baseline only has MUST
            'description' => control['requirement'],
            'details' => control['recommendation'],
            'met_url_required' => true,  # Default: most baseline criteria need URLs
            'baseline_id' => control['id'],  # Keep original ID for reference
            'baseline_maturity_levels' => control['maturity_levels'],
            'external_mappings' => control['external_mappings']
          }
        end
      end
    end

    criteria
  end

# Load existing baseline criteria YAML if it exists

  def load_existing_criteria
    return {} unless File.exist?(criteria_file)

    yaml_data = YAML.load_file(criteria_file)

# Remove metadata, keep only criteria

    yaml_data.reject { |k, _v| k == '_metadata' }
  rescue StandardError => e
    puts "Warning: Could not load existing criteria: #{e.message}"
    {}
  end

# Safely dig into nested hash structure

  def dig_criterion(criteria, level, category, subcategory, field_name)
    criteria.dig(level, category, subcategory, field_name)
  end

# Generate database field name from baseline control ID

# Example: "OSPS-GV-03.01" -> "baseline_osps_gv_03_01"

  def generate_field_name(control_id)
    base_name = control_id.downcase.gsub(/[^a-z0-9]+/, '_')
    "#{BASELINE_CONFIG[:field_prefix]}#{base_name}"
  end

# Generate mapping file for reference

  def generate_field_mapping(parsed_data)
    mapping = {
      'version' => parsed_data['version'],
      'generated_at' => Time.now.iso8601,
      'mappings' => []
    }

    parsed_data['levels'].each do |level_num, level_data|
      level_data['controls'].each do |control|
        mapping['mappings'] << {
          'baseline_id' => control['id'],
          'database_field' => generate_field_name(control['id']),
          'level' => "baseline-#{level_num}",
          'category' => control['category'],
          'requirement' => control['requirement'][0..100] + '...'  # Truncate for readability
        }
      end
    end

    File.write(mapping_file, JSON.pretty_generate(mapping))
    puts "Generated: #{mapping_file}"
  end

# Check if criteria have changed since last sync

  def criteria_changed?(parsed_data)
    metadata = self.class.load_sync_metadata
    return true unless metadata

    metadata['version'] != parsed_data['version']
  end

# Update sync metadata

  def update_sync_metadata(data)
    parsed = JSON.parse(data)
    metadata = {
      'version' => parsed['version'],
      'source_url' => source_url,
      'synced_at' => Time.now.iso8601,
      'criteria_count' => count_criteria(parsed)
    }

    File.write(@metadata_file, JSON.pretty_generate(metadata))
  end

# Count total criteria

  def count_criteria(parsed)
    count = 0
    parsed['levels'].each_value do |level_data|
      count += level_data['controls'].size
    end
    count
  end

# Validate generated files

  def validate_generated_files

# Ensure YAML is valid (using safe_load with permitted classes for !!omap)

    YAML.safe_load_file(
      criteria_file,
      permitted_classes: [Symbol],
      aliases: true
    )

# Ensure mapping is valid JSON

    JSON.parse(File.read(mapping_file))

    puts "✓ Generated files validated"
  rescue StandardError => e
    raise "Validation failed: #{e.message}"
  end

# Load sync metadata

  def self.load_sync_metadata
    return nil unless File.exist?(BASELINE_CONFIG[:sync_metadata_file])

    JSON.parse(File.read(BASELINE_CONFIG[:sync_metadata_file]))
  rescue JSON::ParserError
    nil
  end
end

```

#### 3a. Local Customization Preservation

**How Sync Preserves Local Changes:**

The baseline sync system is designed to intelligently merge upstream updates while preserving local customizations. This is critical because you may need to adjust baseline criteria for your specific needs.

**Fields Updated from Upstream** (replaced on each sync):

- `description` - The requirement text from OpenSSF Baseline
- `details` - The recommendation text from OpenSSF Baseline
- `baseline_maturity_levels` - Which maturity levels this control applies to
- `external_mappings` - Mappings to external frameworks (CIS, NIST, etc.)

**Fields Preserved Locally** (never overwritten by sync):

- `category` - MUST/SHOULD/SUGGESTED (usually MUST for baseline)
- `met_url_required` - Whether a URL is required in justification
- `met_justification_required` - Whether justification text is required
- `na_allowed` - Whether N/A is a valid status
- `na_justification_required` - Whether N/A requires justification
- Any other custom fields you add

**Example Workflow:**

1. **Initial Sync**: Download baseline criteria

   ```bash
   rake baseline:sync
   # Creates criteria/baseline_criteria.yml with defaults
   ```

2. **Local Customization**: Edit the YAML to adjust requirements

   ```yaml

   baseline-1:
     Security:
       Vulnerability Management:
         baseline_osps_sm_01_01:
           description: "..." # From upstream
           details: "..." # From upstream
           met_url_required: false  # CUSTOMIZED: Changed from true
           na_allowed: true         # CUSTOMIZED: Added local override

   ```

3. **Upstream Update**: OpenSSF releases new baseline version

   ```bash
   rake baseline:sync
   # Updates description/details if changed
   # PRESERVES met_url_required: false
   # PRESERVES na_allowed: true
   ```

**When to Use Local Customization:**

- **URL requirements too strict**: Some criteria may not need URLs in your context
- **Allow N/A**: Some criteria may not apply to certain project types
- **Adjust validation**: Change what's required for justification
- **Add custom fields**: Track additional metadata specific to your needs

**Important Notes:**

- Customizations are **per-criterion**, not per-level
- If a criterion is **removed** from upstream, your customization is preserved but the criterion won't appear in new installs
- If a criterion is **renamed** upstream (different ID), it's treated as new and you'll need to re-apply customizations
- Always review `git diff` after sync to see what changed

#### 4. Baseline i18n Extractor Class

**New file**: `lib/baseline_i18n_extractor.rb`

**Purpose**: Extracts `description`, `details`, and placeholder fields from `criteria/baseline_criteria.yml` and writes them to `config/locales/en.yml` for translation. This allows baseline criteria to use the same translation workflow as existing criteria.

**Key Requirements**:

- **Preserve existing YAML comments**: Must not destroy comments outside the baseline section
- **Use marker comments**: Section between `# BEGIN BASELINE CRITERIA AUTO-GENERATED` and `# END BASELINE CRITERIA AUTO-GENERATED` is managed automatically
- **Safe YAML parsing/writing**: Must maintain YAML structure and formatting

```ruby

# frozen_string_literal: true

# Extracts i18n strings from baseline_criteria.yml to config/locales/en.yml

class BaselineI18nExtractor
  BEGIN_MARKER = '# BEGIN BASELINE CRITERIA AUTO-GENERATED'.freeze
  END_MARKER = '# END BASELINE CRITERIA AUTO-GENERATED'.freeze
  MARKER_WARNING = '# WARNING: This section is automatically generated from criteria/baseline_criteria.yml'.freeze
  MARKER_DO_NOT_EDIT = '# Do not edit manually. Run: rake baseline:extract_i18n'.freeze

  def initialize
    @baseline_criteria_file = BASELINE_CONFIG[:criteria_file]
    @en_locale_file = Rails.root.join('config', 'locales', 'en.yml')
  end

  def extract
    puts "Extracting i18n strings from #{@baseline_criteria_file}..."

    # Load baseline criteria
    baseline_criteria = load_baseline_criteria

    # Extract translatable fields
    i18n_data = extract_i18n_data(baseline_criteria)

    # Update en.yml preserving existing content
    update_locale_file(i18n_data)

    puts "✓ i18n extraction complete!"
    puts "  Updated: #{@en_locale_file}"
  end

  private

  def load_baseline_criteria
    unless File.exist?(@baseline_criteria_file)
      raise "Baseline criteria file not found: #{@baseline_criteria_file}"
    end

    YAML.safe_load_file(
      @baseline_criteria_file,
      permitted_classes: [Symbol],
      aliases: true
    )
  end

  # Extract description, details, placeholders from criteria
  def extract_i18n_data(criteria)
    i18n_hash = {}

    criteria.each do |level, level_data|
      next if level == '_metadata' # Skip metadata

      i18n_hash[level] = {}

      traverse_criteria(level_data) do |criterion_key, criterion_data|
        fields = {}
        fields['description'] = criterion_data['description'] if criterion_data['description']
        fields['details'] = criterion_data['details'] if criterion_data['details']
        fields['met_placeholder'] = criterion_data['met_placeholder'] if criterion_data['met_placeholder']
        fields['unmet_placeholder'] = criterion_data['unmet_placeholder'] if criterion_data['unmet_placeholder']
        fields['na_placeholder'] = criterion_data['na_placeholder'] if criterion_data['na_placeholder']

        i18n_hash[level][criterion_key] = fields unless fields.empty?
      end
    end

    i18n_hash
  end

  # Recursively traverse nested criteria structure
  def traverse_criteria(data, &block)
    return unless data.is_a?(Hash)

    data.each do |key, value|
      if value.is_a?(Hash)
        # Check if this is a criterion (has 'category' field) or a category/subcategory
        if value.key?('category')
          yield(key, value)
        else
          # Recurse into category/subcategory
          traverse_criteria(value, &block)
        end
      end
    end
  end

  # Update en.yml preserving existing content and comments
  def update_locale_file(i18n_data)
    # Read the entire file
    content = File.read(@en_locale_file)

    # Find marker positions
    begin_pos = content.index(BEGIN_MARKER)
    end_pos = content.index(END_MARKER)

    if begin_pos.nil? || end_pos.nil?
      # Markers not found - add them at the end of criteria section
      insert_markers_and_content(content, i18n_data)
    else
      # Replace content between markers
      replace_between_markers(content, i18n_data, begin_pos, end_pos)
    end
  end

  def insert_markers_and_content(content, i18n_data)
    # Find the criteria: section and insert after existing criteria
    # This is a simplified implementation - may need adjustment based on actual file structure
    raise "Implementation needed: Insert markers into en.yml at appropriate location"
  end

  def replace_between_markers(content, i18n_data, begin_pos, end_pos)
    # Extract content before and after markers
    before_markers = content[0...begin_pos]
    after_end_marker_line = content.index("\n", end_pos) || content.length
    after_markers = content[after_end_marker_line..-1]

    # Generate new content between markers
    generated_content = generate_yaml_content(i18n_data)

    # Combine
    new_content = before_markers + generated_content + after_markers

    # Write back
    File.write(@en_locale_file, new_content)
  end

  def generate_yaml_content(i18n_data)
    lines = []
    lines << "  #{BEGIN_MARKER}"
    lines << "  #{MARKER_WARNING}"
    lines << "  #{MARKER_DO_NOT_EDIT}"

    i18n_data.each do |level, criteria|
      criteria.each do |criterion_key, fields|
        lines << "    #{criterion_key}:"
        fields.each do |field_name, field_value|
          # Format as YAML with proper indentation and escaping
          lines << "      #{field_name}: #{field_value.to_yaml.strip}"
        end
      end
    end

    lines << "  #{END_MARKER}"
    lines.join("\n") + "\n"
  end
end

```

**Usage**:

```bash

# After running baseline:sync, extract i18n strings
rake baseline:extract_i18n

```

**Important**: This task should be run after every `baseline:sync` to keep locale files in sync with baseline criteria.

#### 5. Migration Generator

**New file**: `lib/baseline_migration_generator.rb`

(Note: Section numbers updated - this was previously section 4)

```ruby

# frozen_string_literal: true

# Generates database migrations for baseline criteria

class BaselineMigrationGenerator
  def initialize
    @mapping_file = BASELINE_CONFIG[:mapping_file]
  end

  def generate
    mapping = load_mapping

# Compare with existing schema to find new fields

    new_fields = find_new_fields(mapping)

    if new_fields.empty?
      puts "No new fields to add. Schema is up to date."
      return
    end

    puts "Found #{new_fields.size} new fields to add:"
    new_fields.each { |field| puts "  - #{field[:database_field]}" }

# Generate migration file

    generate_migration_file(new_fields)
  end

  private

  def load_mapping
    JSON.parse(File.read(@mapping_file))
  end

# Find new fields that need to be added to the database

# IMPORTANT: Only returns fields that DON'T already exist in the schema

# This prevents duplicate column errors when re-running after upstream updates

  def find_new_fields(mapping)

# Get existing columns from the database

    existing_columns = Project.column_names.to_set

# Find fields that don't exist yet

    new_fields = []
    skipped_fields = []

    mapping['mappings'].each do |field_map|
      status_field = "#{field_map['database_field']}_status"
      justification_field = "#{field_map['database_field']}_justification"

      if existing_columns.include?(status_field)

# Field already exists - skip it (preserves existing data)

        skipped_fields << field_map['database_field']
      else

# New field - will be added

        new_fields << field_map
      end
    end

# Report what was skipped

    if skipped_fields.any?
      puts "\nSkipping #{skipped_fields.size} existing fields (already in database):"
      skipped_fields.each { |field| puts "  ✓ #{field}" }
    end

    new_fields
  end

  def generate_migration_file(new_fields)
    timestamp = Time.now.strftime('%Y%m%d%H%M%S')
    filename = "db/migrate/#{timestamp}_add_baseline_criteria_sync_#{new_fields.size}_fields.rb"

# Group by level for organization

    by_level = new_fields.group_by { |f| f['level'] }

    migration_content = generate_migration_content(by_level, timestamp)

    File.write(filename, migration_content)
    puts "\n✓ Generated migration: #{filename}"
    puts "Run: rails db:migrate"
  end

  def generate_migration_content(by_level, timestamp)
    class_name = "AddBaselineCriteriaSync#{by_level.keys.size}Levels"

# Get Rails version for migration compatibility

    rails_version = Rails.version.to_f

    <<~RUBY

# frozen_string_literal: true

# Auto-generated migration from baseline criteria sync

# Generated at: #{Time.now.iso8601}

# Source: #{BASELINE_CONFIG[:source_url]}

      class #{class_name} < ActiveRecord::Migration[#{rails_version}]
        def change
      #{generate_field_additions(by_level)}
        end
      end
    RUBY
  end

  def generate_field_additions(by_level)
    output = []

    by_level.each do |level, fields|
      output << "    # #{level} criteria (#{fields.size} fields)"
      fields.each do |field|
        field_name = field['database_field']
        output << "    add_column :projects, :#{field_name}_status, :string, default: '?'"
        output << "    add_column :projects, :#{field_name}_justification, :text"
        output << ""
      end
    end

    output.join("\n")
  end
end

```

#### 6. Validator

**New file**: `lib/baseline_criteria_validator.rb`

```ruby

# frozen_string_literal: true

# Validates baseline criteria integrity

class BaselineCriteriaValidator
  attr_reader :errors

  def initialize
    @errors = []
  end

  def validate
    @errors = []

    validate_files_exist
    validate_yaml_structure
    validate_field_mapping
    validate_database_schema

    @errors.empty?
  end

  private

  def validate_files_exist
    required_files = [
      BASELINE_CONFIG[:criteria_file],
      BASELINE_CONFIG[:mapping_file],
      BASELINE_CONFIG[:sync_metadata_file]
    ]

    required_files.each do |file|
      unless File.exist?(file)
        @errors << "Missing required file: #{file}"
      end
    end
  end

  def validate_yaml_structure
    criteria = YAML.safe_load_file(
      BASELINE_CONFIG[:criteria_file],
      permitted_classes: [Symbol],
      aliases: true
    )

# Check for metadata

    unless criteria['_metadata']
      @errors << "Missing _metadata section in criteria file"
    end

# Check for baseline levels

    %w[baseline-1 baseline-2 baseline-3].each do |level|
      unless criteria[level]
        @errors << "Missing level: #{level}"
      end
    end
  rescue StandardError => e
    @errors << "YAML parsing error: #{e.message}"
  end

  def validate_field_mapping
    mapping = JSON.parse(File.read(BASELINE_CONFIG[:mapping_file]))

# Check each mapping has required fields

    mapping['mappings'].each_with_index do |map, idx|
      unless map['baseline_id'] && map['database_field']
        @errors << "Mapping ##{idx} missing required fields"
      end
    end
  rescue StandardError => e
    @errors << "Mapping validation error: #{e.message}"
  end

  def validate_database_schema

# Check that mapped fields exist in database

    mapping = JSON.parse(File.read(BASELINE_CONFIG[:mapping_file]))
    existing_columns = Project.column_names.to_set

    mapping['mappings'].each do |map|
      status_field = "#{map['database_field']}_status"
      unless existing_columns.include?(status_field)

# This is expected if migration hasn't run yet

# Just note it, don't error

      end
    end
  rescue StandardError => e
    @errors << "Database validation error: #{e.message}"
  end
end

```

### Keeping Baseline Criteria Separate

#### 1. Separate Files

```

criteria/
  ├── criteria.yml              # Metal series (passing, silver, gold)
  └── baseline_criteria.yml     # Baseline series (auto-generated, marked)

```

#### 2. Metadata Markers

**In `criteria/baseline_criteria.yml`**:

```yaml

_metadata:
  source: 'OpenSSF Baseline'
  source_url: 'https://baseline.openssf.org/versions/2025-10-10/criteria.json'
  version: '2025-10-10'
  synced_at: '2025-01-15T10:30:00Z'
  auto_generated: true
  do_not_edit: 'This file is auto-generated. Edit source at OpenSSF Baseline.'

baseline-1:
  Governance:

# ... criteria

```

#### 3. Database Field Naming

All baseline fields use `baseline_` prefix:

- `baseline_osps_gv_03_01_status`
- `baseline_osps_gv_03_01_justification`

This makes them easily identifiable and searchable:

```sql

SELECT column_name FROM information_schema.columns
WHERE table_name = 'projects' AND column_name LIKE 'baseline_%';

```

#### 4. Mapping File

**`config/baseline_field_mapping.json`** tracks the relationship:

```json

{
  "version": "2025-10-10",
  "generated_at": "2025-01-15T10:30:00Z",
  "mappings": [
    {
      "baseline_id": "OSPS-GV-03.01",
      "database_field": "baseline_osps_gv_03_01",
      "level": "baseline-1",
      "category": "Governance",
      "requirement": "The project documentation MUST include..."
    }
  ]
}

```

### Workflow for Using Sync System

#### Initial Setup (Phase 2)

```bash

# 1. Create configuration

vi config/baseline_config.yml

# 2. First sync (downloads and generates files)

rake baseline:sync

# 3. Review generated files

cat criteria/baseline_criteria.yml
cat config/baseline_field_mapping.json

# 4. Generate migration

rake baseline:generate_migration

# 5. Review and edit migration if needed

vi db/migrate/*_add_baseline_criteria_sync_*.rb

# 6. Run migration

rails db:migrate

# 7. Validate

rake baseline:validate

```

#### Ongoing Updates (When Baseline Changes)

```bash

# 1. Sync with latest baseline

rake baseline:sync

# 2. If changes detected, generate migration

rake baseline:generate_migration

# 3. Review migration

git diff db/migrate/

# 4. Test in development

rails db:migrate
rake baseline:validate
rails test

# 5. Commit changes

git add criteria/baseline_criteria.yml
git add config/baseline_field_mapping.json
git add db/migrate/*
git add .baseline_sync_metadata.json
git commit -m "Update baseline criteria to version YYYY-MM-DD"

```

### Handling Baseline Updates

#### Scenario 1: New Criteria Added

When OpenSSF adds new baseline criteria:

1. `rake baseline:sync` downloads and detects new controls
2. Generates new entries in `baseline_criteria.yml` with default settings
3. `rake baseline:generate_migration` creates migration for **only new fields**
4. Migration adds `_status` and `_justification` columns (skips existing columns)
5. Existing projects have default '?' status for new fields
6. **Database columns that already exist are NOT re-added** (prevents errors)

#### Scenario 2: Criteria Modified

When OpenSSF modifies existing criteria text:

1. `rake baseline:sync` updates **only** `description` and `details` in YAML
2. **Preserves local customizations** (met_url_required, na_allowed, etc.)
3. No database migration needed (text only, no schema changes)
4. Restart server to reload criteria
5. Updated requirement/recommendation text appears in forms
6. Your local setting changes (e.g., "URL not required") remain intact

#### Scenario 3: Criteria Removed (Rare)

When OpenSSF deprecates criteria:

1. `rake baseline:sync` detects removal (criterion no longer in upstream)
2. **Database columns remain** (data preservation, no automatic deletion)
3. **YAML entry is removed** (criterion won't appear in forms for new installs)
4. **Manual decision required**:
   - Keep columns for historical data
   - Or create manual migration to drop columns if desired
5. Existing project data for deprecated criteria is preserved

### Integration with Phases

This sync system integrates into the implementation phases:

- **Before Phase 2**: Set up sync infrastructure, initial sync
- **During Phase 2**: Use sync to generate baseline-1 stub
- **During Phase 3**: Use sync to generate full baseline-1 schema
- **During Phase 5**: Use sync to generate baseline-2 and baseline-3 schemas
- **Ongoing**: Regular syncs to stay current with baseline updates

### Benefits

1. **Always Current**: Stay synchronized with official baseline
2. **No Manual Entry**: Eliminate transcription errors
3. **Version Tracking**: Know exactly which baseline version we support
4. **Auditable**: Clear chain from source to database
5. **Rollback Capable**: Cache allows reverting to previous versions
6. **Separate & Marked**: Baseline criteria clearly distinguished from metal series

---

## Phase 1: URL and Routing Migration

**Goal**: Change URL criteria_level from numeric (0,1,2) to named (passing, silver, gold), add permissions form, ensure backward compatibility.

### 1.1: Update Route Constraints

**File**: `config/routes.rb`

**Changes**:

```ruby

# Line 16-17: Replace

VALID_CRITERIA_LEVEL ||= /[0-2]/

# With

VALID_CRITERIA_LEVEL ||= /passing|silver|gold|bronze|permissions|baseline-1|baseline-2|baseline-3|0|1|2/

```

**Rationale**:

- Allow both old numeric (0,1,2) and new named formats (passing, silver, gold)
- Add 'bronze' as common synonym for 'passing' (will be redirected)
- Add 'permissions' form for project permission management
- Add baseline levels (baseline-1, baseline-2, baseline-3) to prepare for Phase 2+
- This constraint validates incoming requests before they reach controllers

### 1.2: Add Permanent Redirects for Old URLs

**File**: `config/routes.rb`

**Add before line 128** (before `resources :projects`):

```ruby

# PERFORMANCE NOTE: These route-level redirects are processed early in the request
# cycle, before controllers/models are loaded, using minimal memory. They return
# 301 Permanent Redirect responses directly from the routing layer.

# Permanent redirects for old numeric criteria levels to new canonical names
# These are single-hop redirects: 0 → passing (not 0 → bronze → passing)

get '/:locale/projects/:id/0(.:format)', to: redirect('/%{locale}/projects/%{id}/passing%{format}', status: 301),
    constraints: { locale: LEGAL_LOCALE, id: VALID_ID }
get '/:locale/projects/:id/1(.:format)', to: redirect('/%{locale}/projects/%{id}/silver%{format}', status: 301),
    constraints: { locale: LEGAL_LOCALE, id: VALID_ID }
get '/:locale/projects/:id/2(.:format)', to: redirect('/%{locale}/projects/%{id}/gold%{format}', status: 301),
    constraints: { locale: LEGAL_LOCALE, id: VALID_ID }
get '/:locale/projects/:id/0/edit(.:format)', to: redirect('/%{locale}/projects/%{id}/passing/edit%{format}', status: 301),
    constraints: { locale: LEGAL_LOCALE, id: VALID_ID }
get '/:locale/projects/:id/1/edit(.:format)', to: redirect('/%{locale}/projects/%{id}/silver/edit%{format}', status: 301),
    constraints: { locale: LEGAL_LOCALE, id: VALID_ID }
get '/:locale/projects/:id/2/edit(.:format)', to: redirect('/%{locale}/projects/%{id}/gold/edit%{format}', status: 301),
    constraints: { locale: LEGAL_LOCALE, id: VALID_ID }

# Redirect "bronze" to "passing" (common synonym)
# Single-hop redirect to canonical form

get '/:locale/projects/:id/bronze(.:format)', to: redirect('/%{locale}/projects/%{id}/passing%{format}', status: 301),
    constraints: { locale: LEGAL_LOCALE, id: VALID_ID }
get '/:locale/projects/:id/bronze/edit(.:format)', to: redirect('/%{locale}/projects/%{id}/passing/edit%{format}', status: 301),
    constraints: { locale: LEGAL_LOCALE, id: VALID_ID }

```

**Rationale**:

- Old URLs (0,1,2) and synonyms (bronze) redirect permanently to canonical names (passing, silver, gold)
- Status 301 (Permanent) ensures search engines and CDNs update their caches
- Route-level redirects are **very fast** and use **minimal memory** (processed before controller instantiation)
- Single-hop redirects avoid multiple redirect chains (e.g., bronze → passing directly, not bronze → 0 → passing)
- Format parameter (.:format) preserved to handle .json, .md requests correctly

### 1.3: Update Controller Criteria Level Validation

**File**: `app/controllers/projects_controller.rb`

**Locate** method `set_criteria_level` (around line 866):

```ruby

def set_criteria_level
  @criteria_level = criteria_level_params[:criteria_level] || '0'
  @criteria_level = '0' unless @criteria_level.match?(/\A[0-2]\Z/)
end

```

**Replace with**:

```ruby

def set_criteria_level

# Accept both URL-friendly names and numeric IDs

  level_param = criteria_level_params[:criteria_level] || '0'
  @criteria_level = normalize_criteria_level(level_param)
end

# Convert criteria level URL parameter to internal format (YAML key format)
# Accepts: '0', '1', '2', 'passing', 'bronze', 'silver', 'gold'
# Returns: '0', '1', or '2' (internal YAML keys, defaults to '0')
# Note: YAML keys remain numeric for translation compatibility
# Note: 'bronze' is a common synonym for 'passing' (level 0)

def normalize_criteria_level(level)
  case level.to_s.downcase
  when '0', 'passing', 'bronze' then '0'
  when '1', 'silver' then '1'
  when '2', 'gold' then '2'
  else '0' # default to passing (level 0) for invalid values
  end
end

```

**File**: `app/controllers/criteria_controller.rb`

**Locate** method `set_criteria_level` (around line 27-30):

```ruby

def set_criteria_level
  @criteria_level = params[:criteria_level] || '0'
  @criteria_level = '0' unless @criteria_level.match?(/\A[0-2]\Z/)
end

```

**Replace with**:

```ruby

def set_criteria_level
  level_param = params[:criteria_level] || '0'
  @criteria_level = normalize_criteria_level(level_param)
end

# Convert criteria level URL parameter to internal format (YAML key format)
# Accepts: '0', '1', '2', 'passing', 'bronze', 'silver', 'gold'
# Returns: '0', '1', or '2' (defaults to '0')

def normalize_criteria_level(level)
  case level.to_s.downcase
  when '0', 'passing', 'bronze' then '0'
  when '1', 'silver' then '1'
  when '2', 'gold' then '2'
  else '0'
  end
end

```

**Rationale**: Controllers convert user-facing URL parameters (passing, bronze, silver, gold) to internal level IDs ('0', '1', '2') which are used throughout the codebase for YAML keys, I18n translation keys, and internal logic. This preserves translation compatibility while allowing clean URLs and common synonyms (bronze = passing).

### 1.4: NO CHANGES to Criteria YAML Structure

**File**: `criteria/criteria.yml`

**IMPORTANT: DO NOT rename the YAML keys**

The YAML file currently has top-level keys `'0'`, `'1'`, `'2'`:

```yaml

--- !!omap

- '0': !!omap
  - Basics: !!omap

```

**These keys MUST remain as `'0'`, `'1'`, `'2'`** for the following critical reasons:

1. **Translation Compatibility**: I18n translation keys are constructed as `criteria.#{level}.#{criterion_name}.description`. If we change the YAML keys from '0' to 'passing', all translation keys change from `criteria.0.*` to `criteria.passing.*`, breaking externally-maintained translations.

2. **Separation of Concerns**: URLs are presentation layer (user-facing). YAML keys are data layer (internal storage). There's no requirement that they match.

3. **Minimal Changes**: Keeping YAML keys numeric means less code needs to change. Only the routing and controller layers need updates.

4. **Backward Compatibility**: Many parts of the codebase already use `'0'`, `'1'`, `'2'` as level identifiers.

**The URL-to-internal mapping will be handled in the controller layer** (see Section 1.3), not by renaming YAML keys.

### 1.5: Update Model Constants

**File**: `app/models/project.rb`

**Locate** (around lines 38-51):

```ruby

BADGE_LEVELS = %w[in_progress passing silver gold].freeze
COMPLETED_BADGE_LEVELS = BADGE_LEVELS.drop(1).freeze
LEVEL_ID_NUMBERS = (0..(COMPLETED_BADGE_LEVELS.length - 1))
LEVEL_IDS = LEVEL_ID_NUMBERS.map(&:to_s)

```

**IMPORTANT**: Keep existing constants as-is for now. `LEVEL_IDS` will continue to be `['0', '1', '2']` because these are used to access database fields (`badge_percentage_0`, etc.).

**Add new mapping constants after the existing ones** (around line 52):

```ruby

# Mapping from URL-friendly names to internal level IDs
# Internal level IDs ('0', '1', '2') are used for:
#   - YAML criteria keys (criteria/criteria.yml)
#   - I18n translation keys (criteria.0.*, criteria.1.*, etc.)
#   - Database field suffixes (badge_percentage_0, badge_percentage_1, etc.)
# URL-friendly names ('passing', 'silver', 'gold') are used for:
#   - User-facing URLs (/projects/123/passing)
#   - Routing and redirects

LEVEL_NAME_TO_NUMBER = {
  'passing' => '0',
  'silver' => '1',
  'gold' => '2'
}.freeze

# Reverse mapping: internal level ID to URL-friendly name

LEVEL_NUMBER_TO_NAME = {
  '0' => 'passing',
  '1' => 'silver',
  '2' => 'gold',
  0 => 'passing',
  1 => 'silver',
  2 => 'gold'
}.freeze

# All user-facing level names (for URLs, display)

METAL_LEVEL_NAMES = %w[passing silver gold].freeze

```

**CRITICAL NOTE**: We are NOT changing `LEVEL_IDS` (stays as `['0', '1', '2']`) because:

1. It's used to construct database field names like `badge_percentage_#{level}`
2. These numeric IDs are the YAML keys in `criteria/criteria.yml`
3. These numeric IDs are used in I18n translation keys (`criteria.0.*`, etc.)
4. Changing would break externally-maintained translations and many existing methods

Instead, we add a mapping layer to convert between URL-friendly names and internal level IDs.

**Rationale**: Separate concerns between presentation layer (URLs with human-readable names) and data layer (internal IDs for YAML, I18n, database). This preserves translation compatibility while allowing clean URLs.

### 1.6: Verify Criteria Hash Initializer (No Changes Needed)

**File**: `config/initializers/criteria_hash.rb`

**NO CHANGES NEEDED** - The `CriteriaHash` initializer loads criteria from `criteria/criteria.yml`. Since we're keeping the YAML keys as `'0'`, `'1'`, `'2'`, the initializer will continue to work as-is.

**Verification**: After Phase 1 changes, verify the initializer still works correctly:

```bash

# Start Rails console

rails console

# Verify criteria keys are still numeric (as they should be)

CriteriaHash.keys

# Should return: ["0", "1", "2"]

# Verify criteria are accessible by numeric key

Criteria['0']

# Should return hash of passing-level criteria (level 0)

Criteria['1']

# Should return hash of silver-level criteria (level 1)

exit

```

**Important**: The YAML keys remain `'0'`, `'1'`, `'2'`. The URL-to-internal mapping happens in controllers, not in the data layer.

### 1.7: Verify Criteria Model (No Changes Needed)

**File**: `app/models/criteria.rb`

**NO CHANGES NEEDED** - Since we're keeping the YAML keys as `'0'`, `'1'`, `'2'`, the Criteria model will continue to work as-is.

**Key points**:

- The Criteria model uses `level` values from the YAML keys (which remain `'0'`, `'1'`, `'2'`)
- I18n translation keys are constructed as `criteria.#{level}.#{criterion}.description`, which will continue to work
- Level comparisons in methods like `get_text_if_exists` will continue to work (they already use string comparisons or `.to_i`)

**Note**: The URL-to-internal-level mapping is handled in controllers (Section 1.3), not in the Criteria model. Controllers convert URL parameters like 'passing' to internal level ID '0' before passing to models.

### 1.8: Update View Templates

**DO NOT rename view template files**

The view template files should **stay as** `_form_0.html.erb`, `_form_1.html.erb`, `_form_2.html.erb` because `@criteria_level` will contain the internal level IDs (`'0'`, `'1'`, `'2'`), not URL-friendly names.

**File**: `app/views/projects/show.html.erb`

**Locate** (line 19):

```ruby

<%= render "form_#{@criteria_level}", project: @project, is_disabled: true %>

```

**No change needed** - this will continue to work as-is, rendering `_form_0`, `_form_1`, or `_form_2` based on `@criteria_level` which contains `'0'`, `'1'`, or `'2'`.

**File**: `app/views/projects/_form_early.html.erb`

**Locate** (lines 39-43) - hardcoded criteria_level parameters:

```erb

<%= t("#{criteria_level}_html", scope: 'projects.form_early.level',
      passing: %{<a href='#{next_level_prefix}' title='#{t('projects.form_early.level.0')}'>#{image_tag('passing.svg', size: '53x20', alt: t('projects.form_early.level.0'))}</a>}.html_safe,
      silver: %{<a href='#{next_level_prefix}?criteria_level=1' title='#{t('projects.form_early.level.1')}'>#{image_tag('silver.svg', size: '41x20', alt: t('projects.form_early.level.1'))}</a>}.html_safe,
      gold: %{<a href='#{next_level_prefix}?criteria_level=2' title='#{t('projects.form_early.level.2')}'>#{image_tag('gold.svg', size: '35x20', alt: t('projects.form_early.level.2'))}</a>}.html_safe,
      ) %>

```

**Replace with** (change URL parameters but keep I18n keys numeric):

```erb

<%= t("#{criteria_level}_html", scope: 'projects.form_early.level',
      passing: %{<a href='#{next_level_prefix}?criteria_level=passing' title='#{t('projects.form_early.level.0')}'>#{image_tag('passing.svg', size: '53x20', alt: t('projects.form_early.level.0'))}</a>}.html_safe,
      silver: %{<a href='#{next_level_prefix}?criteria_level=silver' title='#{t('projects.form_early.level.1')}'>#{image_tag('silver.svg', size: '41x20', alt: t('projects.form_early.level.1'))}</a>}.html_safe,
      gold: %{<a href='#{next_level_prefix}?criteria_level=gold' title='#{t('projects.form_early.level.2')}'>#{image_tag('gold.svg', size: '35x20', alt: t('projects.form_early.level.2'))}</a>}.html_safe,
      ) %>

```

**Key changes**:

- URL parameters: `criteria_level=1` → `criteria_level=silver` (user-facing)
- I18n keys: Stay as `projects.form_early.level.0` (data layer, preserves translations)

**NO changes needed** to `config/locales/en.yml` - the translation keys remain numeric.

**Rationale**: URLs change to user-friendly names (passing, silver, gold) while I18n translation keys remain numeric ('0', '1', '2') to preserve compatibility with externally-maintained translations.

### 1.9: Update JavaScript for Named Levels

**File**: `app/assets/javascripts/project-form.js`

**Locate** the function that parses criteria_level (around line 65):

```javascript

var searchString = location.search.match('criteria_level=([^\#\&]*)');

```

**No changes needed** to this parsing logic - it will work with both numeric and named values.

**However**, search for any hardcoded checks like:

```javascript

if (criteriaLevel === '0' || criteriaLevel === '1' || criteriaLevel === '2')

```

**Replace with**:

```javascript

if (['0', '1', '2', 'passing', 'silver', 'gold'].includes(criteriaLevel))

```

**Verification command**:

```bash

# Search for hardcoded level checks in JavaScript

grep -n "=== '[0-2]'" app/assets/javascripts/*.js
grep -n "criteriaLevel ==\|level ==\|criteria_level ==" app/assets/javascripts/*.js

```

**If no hardcoded checks exist**, no JavaScript changes are needed. The URL param parsing is generic enough to handle named values.

**Rationale**: JavaScript that parses URL parameters needs to accept both numeric (for backward compatibility during transition) and named values.

### 1.10: Remove Full Project Caching

**Problem**: The forms currently cache the entire project form when `is_disabled` (view-only mode). This creates a large cache footprint for entire forms. Now that systems are downloading the entire site, the cache entries become evicted before they can be used, making this useless. In addition, we want to *only* calculate the set of allowed editors when necessary, and we can't do that with the current setup.

**Files**: `app/views/projects/_form_0.html.erb`, `app/views/projects/_form_1.html.erb`, `app/views/projects/_form_2.html.erb`

**Remove the cache_if block** in each file:

#### Identifying the Matching `end` Statement

**Critical**: The cache_if block wraps nearly the **entire file content**. The matching `end` is at the **very last line** of each file.

**Analysis for `_form_0.html.erb`**:

1. **cache_if opens** (lines 24-26):

   ```erb

   cache_if ProjectsController::CACHE_SHOW_PROJECT && is_disabled,
            [project, locale, additional_rights_list],
             expires_in: 12.hours do %>

   ```

2. **Potential end candidates**:
   - Line 602: `<% end %>` - This closes the `<% if is_disabled %>` block (line 594)
   - Line 604: `<% end %>` - This closes the `bootstrap_form_for project ... do |f|` block (line 38)
   - Line 608: `<% end %>` - **THIS closes the cache_if block**

3. **Why line 608 is correct**:
   - The cache_if at line 24-26 has `do %>` which requires a matching `<% end %>`
   - It wraps the `form_early` render (line 27) AND the entire `bootstrap_form_for` block
   - The block structure is:

     ```

     cache_if ... do %>         (line 24-26)
       <%= render form_early %>  (line 27-32)
       <div class="row">         (line 34)
         bootstrap_form_for ... do |f| %>  (line 38)
           ...form content...
         <% end %>               (line 604 - closes form_for)
       </div>                    (line 605-607)
     <% end %>                   (line 608 - closes cache_if)

     ```

   - Line 608 comes after ALL closing `</div>` tags (lines 605-607)
   - It's the ONLY `<% end %>` after the form closes that isn't inside an if/else

**Verification for `_form_1.html.erb` and `_form_2.html.erb`**:

- Both have cache_if at lines 19-20
- Both have the matching `<% end %>` as the **very last line** of the file
- Same structure: cache wraps the entire form content

**Alternative matches ruled out**:

- ❌ Line 602 (`<% end %>` after submit buttons): Closes the `<% if is_disabled %>` conditional (line 594), NOT the cache
- ❌ Line 604 (`<% end %>` after center div): Closes the `bootstrap_form_for` block (line 38), NOT the cache
- ✅ Line 608 (`<% end %>` after all divs): Closes the `cache_if` block - CORRECT

**Performance Benefit**: Removing the cache_if also eliminates the `additional_rights_list` calculation (line 19), which performs a database query (`pluck`) and string join operation on every form render. This variable was **only** used as part of the cache key and serves no other purpose.

**Changes to make**:

**In `_form_0.html.erb`**:

```erb
# DELETE lines 15-26 (the setup and cache_if opening):
<%
   # If the additional rights list changes, invalidate the cache.
   # If the performance is too slow, we could directly expire it instead,
   # but that adds a maintenance headache.
   additional_rights_list = project.additional_rights.pluck(:user_id).join(',')

   # The badge URL has one value for some time after the project entry
   # is edited, and then changes. To handle that gracefully, we
   # expire the cache after a period of time.
   cache_if ProjectsController::CACHE_SHOW_PROJECT && is_disabled,
           [project, locale, additional_rights_list],
            expires_in: 12.hours do %>

# DELETE line 608 (the matching end):
<% end %>
```

**Note**: The `additional_rights_list` variable (line 19) is **only** used in the cache key (line 25). Removing the cache_if eliminates this unnecessary database query and string processing on every view.

**In `_form_1.html.erb`** and **`_form_2.html.erb`**:

```erb

# DELETE lines 19-20 (the cache_if opening):

<% cache_if ProjectsController::CACHE_SHOW_PROJECT && is_disabled,
            [project, locale], expires_in: 12.hours do %>

# DELETE the very last line (the matching end):

<% end %>

```

**After removal**: The files will start directly with the form content (the `render form_early` call) and end with the closing `</div>` tags for the HTML structure.

**Testing**:

- Verify forms still render correctly in both edit and view modes
- Check that removing caching doesn't significantly impact performance (it shouldn't - individual elements may still cache)
- Ensure no syntax errors from mismatched ends

**Rationale**:

- **Performance**: Eliminates unnecessary `additional_rights_list` calculation (database query + string join) on every form render in `_form_0.html.erb`
- **Simplicity**: Removes complex full-page caching logic, making forms easier to understand and modify
- **Flexibility**: Allows more granular caching strategies per-criterion or per-section
- **Baseline preparation**: Different criteria levels (metal vs baseline) may need different caching strategies
- **Maintainability**: Reduces code complexity and potential cache invalidation bugs

### 1.11: Create Permissions Form

**New file**: `app/views/projects/_form_permissions.html.erb`

**Content** (extract permissions sections from `_form_0.html.erb`):

```erb

<div class="row">
  <div class="col-md-12">
    <h2><%= t('.permissions_header') %></h2>
    <p><%= t('.permissions_explanation') %></p>

    <%# Project Ownership Transfer %>
    <% if !is_disabled && (current_user.admin? || current_user.id == project.user_id) %>
      <div class="panel panel-default">
        <div class="panel-heading">
          <h3 class="panel-title"><%= t('projects.edit.transfer_ownership') %></h3>
        </div>
        <div class="panel-body">
          <div class="row">
            <div class="col-xs-12">
              <%= t 'projects.edit.new_owner' %>:
              <%= f.text_field :user_id,
                               hide_label: true, class: "form-control",
                               placeholder: nil,
                               spellcheck: false,
                               disabled: is_disabled %>
            </div>
          </div>
          <div class="row">
            <div class="col-xs-12">
              <%= t 'projects.edit.new_owner_repeat' %>:
              <%# The user must provide the same value here as user_id to cause an ownership change. %>
              <input type="text" name="project[user_id_repeat]"
                     id="project_user_id_repeat" class="form-control"
                     placeholder="<%= t('projects.edit.new_owner_repeat_placeholder') %>"
                     spellcheck="false"
                     <%= 'disabled' if is_disabled %>>
              <%= content_tag(:small, t('projects.edit.new_owner_help'), class: 'form-text text-muted') %>
            </div>
          </div>
        </div>
      </div>
    <% end %>

    <%# Additional Rights (Collaborators) %>
    <% if !is_disabled %>
      <div class="panel panel-default">
        <div class="panel-heading">
          <h3 class="panel-title"><%= t('.additional_rights_header') %></h3>
        </div>
        <div class="panel-body">
          <%= f.fields_for :additional_rights do |rights_form| %>
            <div class="form-group">
              <%= rights_form.label :additional_rights_changes, t('.additional_rights') %>
              <%= rights_form.text_area :additional_rights_changes,
                  class: 'form-control',
                  placeholder: t('.additional_rights_placeholder') %>
              <%= content_tag(:small, t('.additional_rights_help'), class: 'form-text text-muted') %>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
  </div>
</div>

```

**Remove from existing forms**: `app/views/projects/_form_0.html.erb` (and `_form_1.html.erb`, `_form_2.html.erb` if present)

Delete the ownership transfer section (search for `text_field :user_id` and `user_id_repeat`) and the additional_rights section. These are now in the dedicated permissions form.

**Action items**:

1. Create the new `_form_permissions.html.erb` with both ownership and collaborator management
2. Remove the ownership transfer UI from `_form_0.html.erb` (lines with `:user_id` and `user_id_repeat`)
3. Remove the additional_rights UI from `_form_0.html.erb` (lines with `fields_for :additional_rights`)
4. Update `projects_controller.rb` to handle `criteria_level == 'permissions'` in the `edit` and `update` actions
5. Ensure `normalize_criteria_level` handles 'permissions' (already added in Section 1.3)

**Update**: `config/routes.rb`

The routes for `:criteria_level` already exist (around lines 135-137):

```ruby

get ':criteria_level(.:format)' => 'projects#show',
    constraints: { criteria_level: VALID_CRITERIA_LEVEL }
get ':criteria_level/edit(.:format)' => 'projects#edit',
    constraints: { criteria_level: VALID_CRITERIA_LEVEL }

```

**No changes needed here** - the `VALID_CRITERIA_LEVEL` constant was already updated in step 1.1 to include 'permissions'. The existing routes will automatically accept 'permissions' as a valid criteria_level.

**Email Updates**: Update notification emails that reference permissions/ownership changes

**File**: `app/mailers/project_mailer.rb` (or similar)

If emails reference the permissions page, update links from:

- Old: `/projects/123/0/edit` (permissions were in passing form)
- New: `/projects/123/permissions/edit` (permissions in dedicated form)

Example email text update:

```ruby

# Before

"To manage collaborators, edit your project: #{project_url(@project, criteria_level: 0)}"

# After

"To manage collaborators or transfer ownership, visit: #{project_url(@project, criteria_level: 'permissions')}"

```

**Rationale**:

- Consolidate ALL permission-related operations (ownership transfer + collaborator management) in one dedicated form
- Remove permissions UI from criteria forms entirely (cleaner separation of concerns)
- Allow baseline users to manage permissions without viewing metal series criteria
- Provide single location for all access control operations

### 1.12: Update Helper Methods

**File**: `app/helpers/projects_helper.rb`

**Add method** for level display:

```ruby

# Returns user-friendly name for criteria level
# @param level [String] Internal level ID: '0', '1', '2', 'baseline-1', etc.
# @return [String] localized level name

def criteria_level_display_name(level)
  I18n.t("projects.criteria_levels.#{level}", default: level.titleize)
end

# Returns the badge percentage field name for a level
# @param level [String] Level ID (accepts both internal '0'/'1'/'2' and URL 'passing'/'silver'/'gold')
#                      For baseline: 'baseline-1', 'baseline-2', 'baseline-3'
# @return [Symbol] field name like :badge_percentage_0 or :badge_percentage_baseline_1

def badge_percentage_field(level)
  case level.to_s
  when 'passing', '0'
    :badge_percentage_0
  when 'silver', '1'
    :badge_percentage_1
  when 'gold', '2'
    :badge_percentage_2
  when 'baseline-1'
    :badge_percentage_baseline_1
  when 'baseline-2'
    :badge_percentage_baseline_2
  when 'baseline-3'
    :badge_percentage_baseline_3
  else
    :badge_percentage_0 # default to passing
  end
end

```

**Note**: This helper will be extended in Phase 3 to support baseline levels. The initial implementation (Phase 1) only needs to handle metal series.

### 1.13: Add Badge Percentage Field Mapping to Project Model (CRITICAL)

**File**: `app/models/project.rb`

**Problem**: Code like `self[:"badge_percentage_#{level}"]` will break when level contains hyphens (e.g., 'baseline-1' creates invalid symbol `badge_percentage_baseline-1`).

**Locate** method `update_badge_percentage` (around line 383):

```ruby

def update_badge_percentage(level, current_time)
  old_badge_percentage = self[:"badge_percentage_#{level}"]  # ← BREAKS with 'baseline-1'
  update_prereqs(level) if level.to_i.nonzero?
  self[:"badge_percentage_#{level}"] =
    calculate_badge_percentage(level)

# ...

end

```

**Add helper method** (around line 100, near other mapping methods):

```ruby

# Returns the database field name for a level's badge percentage
# Handles mapping from level names (with hyphens) to valid field names
# @param level [String] 'passing', 'silver', 'gold', 'baseline-1', etc.
# @return [Symbol] field name like :badge_percentage_0 or :badge_percentage_baseline_1

def badge_percentage_field_name(level)
  case level.to_s
  when '0', 'passing'
    :badge_percentage_0
  when '1', 'silver'
    :badge_percentage_1
  when '2', 'gold'
    :badge_percentage_2
  when 'baseline-1'
    :badge_percentage_baseline_1
  when 'baseline-2'
    :badge_percentage_baseline_2
  when 'baseline-3'
    :badge_percentage_baseline_3
  else

# Fallback: convert hyphen to underscore for baseline levels

    level_normalized = level.to_s.tr('-', '_')
    "badge_percentage_#{level_normalized}".to_sym
  end
end

# Convenience method to get badge percentage for a level
# @param level [String] criteria level name
# @return [Integer] percentage value

def badge_percentage_for(level)
  self[badge_percentage_field_name(level)] || 0
end

# Convenience method to set badge percentage for a level
# @param level [String] criteria level name
# @param value [Integer] percentage value

def set_badge_percentage(level, value)
  self[badge_percentage_field_name(level)] = value
end

```

**Update** `update_badge_percentage` to use the new method:

```ruby

def update_badge_percentage(level, current_time)
  old_badge_percentage = badge_percentage_for(level)
  update_prereqs(level) if level_to_number(level).nonzero?
  set_badge_percentage(level, calculate_badge_percentage(level))
  update_achievement(level, old_badge_percentage, current_time)
end

private

# Convert level name to number for conditional logic

def level_to_number(level)
  case level.to_s
  when '0', 'passing' then 0
  when '1', 'silver' then 1
  when '2', 'gold' then 2
  when 'baseline-1' then 1
  when 'baseline-2' then 2
  when 'baseline-3' then 3
  else
    level.to_i
  end
end

```

**Search and replace** other instances of `self[:"badge_percentage_#{level}"]`:

```bash

# Find all instances

grep -n 'badge_percentage_#{' app/models/project.rb

# Replace each with badge_percentage_for(level) or set_badge_percentage(level, value)

```

**Rationale**: This abstraction layer handles the mapping from level names (which may contain hyphens) to valid database field names (which use underscores). It prevents symbol syntax errors and makes the code more maintainable.

**CRITICAL**: This must be done before changing to named levels, or field access will fail.

### 1.14: Fix Criteria Model for Named Levels (CRITICAL)

**File**: `app/models/criteria.rb`

**Problem**: The `get_text_if_exists` method uses `.to_i` comparison which breaks with named levels.

**Locate** method `get_text_if_exists` (around line 204-218):

```ruby

def get_text_if_exists(field)
  return unless field.in? LOCALE_ACCESSORS

  Criteria.get_levels(name).reverse_each do |l|
    next if l.to_i > level.to_i  # ← THIS BREAKS with named levels!

    t_key = "criteria.#{l}.#{name}.#{field}"
    return I18n.t(t_key).html_safe if I18n.exists?(t_key)
  end
  nil
end

```

**Replace with**:

```ruby

def get_text_if_exists(field)
  return unless field.in? LOCALE_ACCESSORS

  Criteria.get_levels(name).reverse_each do |l|

# Compare levels using mapping, not .to_i

    next if level_higher?(l, level)

    t_key = "criteria.#{l}.#{name}.#{field}"

# Disable HTML output safety. I18n translations are internal data

# and are considered a trusted source.

# rubocop:disable Rails/OutputSafety

    return I18n.t(t_key).html_safe if I18n.exists?(t_key)

# rubocop:enable Rails/OutputSafety

  end
  nil
end

private

# Returns true if level1 is higher than level2

def level_higher?(level1, level2)
  level_num1 = level_to_number(level1)
  level_num2 = level_to_number(level2)
  level_num1 > level_num2
end

# Convert level name to number for comparison

def level_to_number(level)
  case level.to_s
  when '0', 'passing' then 0
  when '1', 'silver' then 1
  when '2', 'gold' then 2
  when 'baseline-1' then 1  # Baseline-1 roughly equivalent to silver
  when 'baseline-2' then 2  # Baseline-2 roughly equivalent to gold
  when 'baseline-3' then 3  # Baseline-3 is highest
  else
    level.to_i  # Fallback for unknown levels
  end
end

```

**Rationale**: The `.to_i` method converts all non-numeric strings to 0, breaking the comparison logic. This fix adds explicit mapping so named levels work correctly.

**CRITICAL**: This must be fixed in Phase 1 before changing YAML keys, or criterion text lookups will fail silently.

### 1.15: Verify View Helper Compatibility

**File**: `app/helpers/projects_helper.rb`

**Verify** that existing view helpers will work with named levels:

The `render_status` helper (and similar helpers used in forms) should accept the level parameter. If the helper currently hardcodes level lookups, update it:

**Example fix if needed**:

```ruby

# Before (if it exists with hardcoded logic):

def render_status(criterion_name, f, project, level_number, is_disabled, is_last)

# Uses level_number directly as 0, 1, 2

end

# After (make it work with named levels):

def render_status(criterion_name, f, project, criteria_level, is_disabled, is_last)

# Uses criteria_level as 'passing', 'silver', 'gold', or 'baseline-1'

# The helper should work with the level name, not numbers

end

```

**Rationale**: Ensure view helpers accept named levels. Most helpers should work without changes if they pass the level to model methods that already handle named levels.

### 1.16: Verify JavaScript Compatibility (CRITICAL)

**Problem**: JavaScript code may have hardcoded checks for numeric levels ('0', '1', '2') or may parse criteria_level from URLs.

**Search for hardcoded level checks**:

```bash

# Search JavaScript files for level comparisons

grep -rn "=== '[0-2]'" app/assets/javascripts/
grep -rn "=== [0-2]" app/assets/javascripts/
grep -rn "criteria_level" app/assets/javascripts/

# Also check for jQuery selectors that might reference level

grep -rn "level.*[012]" app/assets/javascripts/

```

**Common issues to fix**:

1. **Level comparisons** - Change from numeric to named:

   ```javascript

   // Before
   if (criteria_level === '0' || criteria_level === '1') { ... }

   // After
   if (criteria_level === 'passing' || criteria_level === 'silver') { ... }

   ```

2. **URL building** - Update to use named levels:

   ```javascript

   // Before
   var url = '/projects/' + id + '/' + level_num;

   // After
   var url = '/projects/' + id + '/' + level_name;

   ```

3. **Array indexing** - Replace with mapping:

   ```javascript

   // Before
   var levelIndex = parseInt(criteria_level);
   var percentage = percentages[levelIndex];

   // After
   var levelMap = {'passing': 0, 'silver': 1, 'gold': 2};
   var levelIndex = levelMap[criteria_level] || 0;
   var percentage = percentages[levelIndex];

   ```

**Test JavaScript after changes**:

```bash

# Run JavaScript linter

rake eslint

# Manual testing checklist:
# - Open browser console on project edit page
# - Check for JavaScript errors
# - Test level switching functionality
# - Verify AJAX requests use correct URLs

```

**Rationale**: JavaScript errors can be silent and hard to debug. Proactive verification prevents production issues.

### 1.17: Update Tests

**Files to update**:

- `test/controllers/projects_controller_test.rb`
- `test/integration/project_get_test.rb`
- `test/helpers/sessions_helper_test.rb`

**Changes**:

1. Add tests for redirect from numeric to named URLs
2. Update existing tests to use named levels instead of numeric
3. Add tests for normalize_criteria_level method
4. Ensure backward compatibility tests pass

**Example test additions**:

```ruby

test "should redirect from numeric to named criteria levels" do
  project = projects(:one)
  get "/en/projects/#{project.id}/0"
  assert_redirected_to "/en/projects/#{project.id}/passing"
  assert_response :moved_permanently
end

test "normalize_criteria_level handles all formats" do
  assert_equal 'passing', @controller.send(:normalize_criteria_level, '0')
  assert_equal 'passing', @controller.send(:normalize_criteria_level, 'passing')
  assert_equal 'silver', @controller.send(:normalize_criteria_level, '1')
  assert_equal 'gold', @controller.send(:normalize_criteria_level, 'gold')
end

```

### 1.18: Phase 1 Deployment Steps

**Critical**: Phase 1 changes URL structure. Deploy carefully with monitoring.

**Pre-deployment checklist**:

```bash

# 1. Run all tests

rake default
rails test:all

# 2. Verify YAML loads without errors

rails console
> CriteriaHash.keys
> Criteria['passing']
> exit

# 3. Verify redirects work in development

rails s

# Test in browser: http://localhost:3000/en/projects/1/0
# Should redirect to: http://localhost:3000/en/projects/1/passing

```

**Deployment sequence**:

1. Deploy code changes (controllers, routes, views)
2. Monitor error logs for 15 minutes
3. Verify old URLs redirect correctly
4. Verify new URLs work
5. Check that search engines can access both old and new URLs

**Rollback procedure** if issues arise:

```bash

# Revert to previous version

git revert HEAD

# Or restore from backup

```

**Post-deployment verification**:

```bash

# Test key URLs

curl -I https://www.bestpractices.dev/en/projects/1/0

# Should return: 301 Moved Permanently
# Location: .../projects/1/passing

curl -I https://www.bestpractices.dev/en/projects/1/passing

# Should return: 200 OK

```

### Phase 1 Summary: Baseline Preparation

**How Phase 1 Prepares for Baseline Criteria:**

Phase 1 is specifically designed to make adding baseline criteria easier in subsequent phases:

1. **Route Constraints Already Include Baseline**:
   - `VALID_CRITERIA_LEVEL` regex includes `baseline-1|baseline-2|baseline-3`
   - No route changes needed when baseline criteria are added in Phase 2+

2. **Controller Structure is Flexible**:
   - `normalize_criteria_level` is designed to handle any level name
   - Simply add new `when 'baseline-1'` cases as baseline levels are introduced
   - No architectural changes needed to support new level types

3. **URL Namespace is Clean**:
   - `/projects/123/baseline-1` URLs are already valid routes
   - Baseline levels use descriptive names (not numbers), avoiding confusion with metal series
   - Clear separation between metal (`passing`, `silver`, `gold`) and baseline (`baseline-1`, `baseline-2`, `baseline-3`)

4. **Translation Compatibility Preserved**:
   - Baseline criteria can use `'baseline-1'` as YAML keys (no numeric mapping needed)
   - Metal series keeps `'0'`, `'1'`, `'2'` YAML keys (preserves existing translations)
   - Each series has independent I18n namespace: `criteria.0.*` vs `criteria.baseline-1.*`

5. **Performance-Optimized Redirect System**:
   - Route-level redirects process requests with minimal memory before controller instantiation
   - Single-hop redirects avoid multiple redirect chains
   - Adding baseline redirects (if needed) follows the same pattern

**What Phase 2+ Will Add:**

- Database columns for baseline criteria fields
- Baseline criteria YAML files (separate from metal series)
- Baseline-specific views and view partials
- Baseline badge generation
- Baseline project statistics

**Key Architectural Decision:** Keeping YAML keys numeric for metal series (`'0'`, `'1'`, `'2'`) while using descriptive names for baseline (`'baseline-1'`, etc.) allows both series to coexist cleanly without conflicts in I18n translation keys or data structures.

### Phase 1 Testing Checklist

- [ ] All existing tests pass (`rails test:all`)
- [ ] Linters pass (`rake default`)
- [ ] Old URLs (0,1,2) redirect to new URLs (passing, silver, gold) - single hop, 301 status
- [ ] Bronze URLs redirect to passing - single hop, 301 status
- [ ] Redirects return 301 status code (permanent, not 302)
- [ ] New canonical URLs work correctly (passing, silver, gold)
- [ ] Both numeric and named formats work in controllers (normalize_criteria_level handles all)
- [ ] Bronze synonym works in controllers (maps to '0' internally)
- [ ] Criteria YAML still uses numeric keys ('0', '1', '2') - NOT changed to named keys
- [ ] All three badge forms render correctly (_form_0, _form_1, _form_2)
- [ ] Permissions form accessible at `/projects/{id}/permissions/edit`
- [ ] Permissions form shows ownership transfer (user_id fields) for owner/admin only
- [ ] Permissions form shows collaborator management (additional_rights)
- [ ] Ownership transfer section REMOVED from _form_0, _form_1, _form_2
- [ ] Additional_rights section REMOVED from _form_0, _form_1, _form_2
- [ ] Email notifications link to `/permissions/edit` instead of `/0/edit` for permission changes
- [ ] No broken links in UI
- [ ] Database queries still work (badge_percentage_0, etc.)
- [ ] JavaScript continues to work (no console errors)
- [ ] Level navigation buttons work in forms
- [ ] Translation keys resolve correctly (criteria.0.*, criteria.1.*, criteria.2.*)
- [ ] Baseline route constraints present (baseline-1, baseline-2, baseline-3 accepted but return 404 until Phase 2)

---

## Phase 2: Database Schema for Baseline-1

**Goal**: Set up baseline sync system and add database columns for baseline-1 criteria, ensuring incremental deployment.

**Hybrid Storage Approach**: This phase implements the hybrid architecture where:

- `criteria/baseline_criteria.yml` is the source of truth (includes description/details)
- `config/locales/en.yml` contains extracted translations (between marker comments)
- `rake baseline:extract_i18n` synchronizes between the two files
- See "Hybrid Storage Architecture" section above for rationale

Note that there's no need for a special *additional* prefix of
baseline criteria. All baseline criteria *already* have a special prefix,
and we can build on that.

### 2.1: Set Up Baseline Sync Infrastructure

**Purpose**: Before adding any baseline criteria, set up the automated sync system.

**Steps**:

1. **Create sync configuration**:

```bash

# Create config file

cat > config/baseline_config.yml << 'EOF'

# Configuration for baseline criteria synchronization

baseline:

# Official source URL (can be overridden with environment variable)

  source_url: <%= ENV['BASELINE_CRITERIA_URL'] || 'https://baseline.openssf.org/versions/2025-10-10/criteria.json' %>

# Local cache of downloaded criteria (for comparison/rollback)

  cache_dir: 'tmp/baseline_cache'

# Output locations

  criteria_file: 'criteria/baseline_criteria.yml'
  mapping_file: 'config/baseline_field_mapping.json'

# Metadata

  sync_metadata_file: '.baseline_sync_metadata.json'
EOF

```

2. **Create initializer**:

```bash

cat > config/initializers/baseline_config.rb << 'EOF'

# frozen_string_literal: true

require 'yaml'
require 'erb'

config_file = Rails.root.join('config', 'baseline_config.yml')
BASELINE_CONFIG = YAML.safe_load(
  ERB.new(File.read(config_file)).result,
  aliases: true
).fetch('baseline', {}).with_indifferent_access.freeze
EOF

```

3. **Create lib classes** (see Baseline Criteria Sync System section for full code):
   - `lib/baseline_criteria_sync.rb`
   - `lib/baseline_i18n_extractor.rb` (NEW: extracts i18n to locale files)
   - `lib/baseline_migration_generator.rb`
   - `lib/baseline_criteria_validator.rb`

4. **Create rake tasks**:
   - `lib/tasks/baseline.rake` (see Baseline Criteria Sync System section)

5. **Add to .gitignore**:

```bash

# Add to .gitignore

echo "tmp/baseline_cache/" >> .gitignore
echo ".baseline_sync_metadata.json" >> .gitignore

```

**Verification**:

```bash

# Verify rake tasks are available

rake -T baseline

# Should show:
# rake baseline:extract_i18n        # Extract i18n strings from baseline_criteria.yml to config/locales/en.yml
# rake baseline:generate_migration  # Generate migration for new baseline criteria
# rake baseline:sync                # Download and sync baseline criteria from official source
# rake baseline:validate            # Validate baseline criteria mapping
# rake baseline:version             # Show current baseline criteria version

```

### 2.2: Initial Baseline Sync (Stub for Testing)

**Purpose**: Download baseline criteria, but initially limit to just 2 criteria for testing.

We will use the real baseline but filter.

```ruby

# Temporarily modify lib/baseline_criteria_sync.rb
# In the transform_to_our_format method, add filtering:

def transform_to_our_format(data)
  criteria = {}

# TEMPORARY: Only process first 2 controls for testing

  test_mode = ENV['BASELINE_TEST_MODE'] == 'true'

  data['levels'].each do |level_num, level_data|
    next unless level_num == '1'  # Only baseline-1 for now

    level_key = "baseline-#{level_num}"
    criteria[level_key] = {}

    controls = level_data['controls']
    controls = controls.first(2) if test_mode  # Limit to 2 for testing

    controls.each do |control|

# ... rest of method

    end
  end

  criteria
end

```

**Run sync with test mode**:

```bash

BASELINE_TEST_MODE=true rake baseline:sync

```

Note that we expect `criteria/baseline_criteria.yml`
to eventually look something like this:

```yaml

# Baseline Criteria - Auto-generated from OpenSSF Baseline
#
# This file is the SOURCE OF TRUTH for baseline criteria metadata.
# It contains ALL fields including description and details.
#
# TRANSLATION WORKFLOW:
# - The 'description', 'details', and placeholder fields are automatically
#   extracted to config/locales/en.yml by running: rake baseline:extract_i18n
# - At runtime, the application loads metadata from this file and
#   translatable text from config/locales/*.yml
#
# SYNC PROCESS:
# - This file is generated by: rake baseline:sync
# - After sync, run: rake baseline:extract_i18n
# - Then run: rake baseline:generate_migration (if new criteria were added)
#
# See docs/baseline_details.md for full documentation.

--- !!omap
_metadata:
  source: 'Manual Stub'
  auto_generated: false
  note: 'Temporary stub for testing. Replace with synced criteria from OpenSSF.'

- baseline-1: !!omap
  - Governance: !!omap
    - Project Documentation: !!omap
      - baseline_osps_gv_03_01:

          category: MUST
          description: >
            The project documentation MUST include an explanation of the
            contribution process.
          details: >
            Document how contributors can submit changes, what the review
            process is, and how decisions are made.
          met_url_required: true
          external_id: 'OSPS-GV-03.01'

      - baseline_osps_do_01_01:

          category: MUST
          description: >
            The project documentation MUST include basic information about
            the project's purpose, how to use it, and how to contribute.
          details: >
            This includes README files, contribution guidelines, and
            governance documentation.
          met_url_required: true
          external_id: 'OSPS-DO-01.01'

```

**Rationale**: Start with a minimal set of criteria to validate the architecture before adding all baseline criteria. Field names match the sync system's naming pattern (baseline_osps_XX_YY_ZZ) so the stub can be seamlessly replaced when syncing becomes available.

**Generate migration from stub**:

```bash

rake baseline:generate_migration

```

This creates a migration with ~2-4 database fields (2 criteria × 2 fields each).

### 2.3: Prepare config/locales/en.yml for Auto-Generated Content

**Purpose**: Add marker comments to `config/locales/en.yml` to delimit where baseline criteria translations will be inserted.

**File**: `config/locales/en.yml`

**Add markers** at the end of the `criteria:` section (after existing criteria for levels '0', '1', '2'):

Find the end of the criteria section (search for the line after the last criterion, typically before `headings:` or similar). Insert:

```yaml

  criteria:
    '0':
      # ... existing level 0 criteria ...
    '1':
      # ... existing level 1 criteria ...
    '2':
      # ... existing level 2 criteria ...
    # BEGIN BASELINE CRITERIA AUTO-GENERATED
    # WARNING: This section is automatically generated from criteria/baseline_criteria.yml
    # Do not edit manually. Run: rake baseline:extract_i18n
    # END BASELINE CRITERIA AUTO-GENERATED
  headings:
    # ... rest of file ...

```

**Important Notes**:

- The markers MUST be at the correct indentation level (2 spaces for `#` at the `criteria:` level)
- Content between markers will be completely replaced by `rake baseline:extract_i18n`
- Comments and structure outside the markers are preserved
- Initially the section between markers is empty

**Verification**:

```bash

# Check that markers are present
grep -n "BEGIN BASELINE CRITERIA" config/locales/en.yml
grep -n "END BASELINE CRITERIA" config/locales/en.yml

# Both should return line numbers

```

### 2.4: Extract i18n Strings from Baseline Criteria

**Purpose**: Extract `description`, `details`, and placeholder fields from the baseline criteria stub into the locale file.

**Command**:

```bash

rake baseline:extract_i18n

```

**What this does**:

1. Reads `criteria/baseline_criteria.yml`
2. Extracts translatable fields (description, details, placeholders)
3. Updates content between markers in `config/locales/en.yml`
4. Preserves all existing comments and structure outside markers

**Verify the extraction**:

```bash

# View the extracted content
sed -n '/BEGIN BASELINE CRITERIA/,/END BASELINE CRITERIA/p' config/locales/en.yml

```

Expected output should show the extracted criteria with proper YAML structure:

```yaml

  # BEGIN BASELINE CRITERIA AUTO-GENERATED
  # WARNING: This section is automatically generated from criteria/baseline_criteria.yml
  # Do not edit manually. Run: rake baseline:extract_i18n
    baseline_osps_gv_03_01:
      description: The project documentation MUST include an explanation of the contribution process.
      details: Document how contributors can submit changes, what the review process is, and how decisions are made.
    baseline_osps_do_01_01:
      description: The project documentation MUST include basic information about the project's purpose, how to use it, and how to contribute.
      details: This includes README files, contribution guidelines, and governance documentation.
  # END BASELINE CRITERIA AUTO-GENERATED

```

### 2.5: Update Criteria Loading Logic

**File**: `config/initializers/criteria_hash.rb`

Currently, criteria are loaded from `criteria/criteria.yml` in this initializer. We need to support loading from multiple files.

**Locate** (lines 9-10):

```ruby

FullCriteriaHash =
  YAML.load_file('criteria/criteria.yml').with_indifferent_access.freeze

```

**Replace with** (Option A - Recommended, using safe_load_file):

```ruby

# Load metal series criteria
# NOTE: Upgrading from YAML.load_file to YAML.safe_load_file for security

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

# Merge baseline criteria into metal criteria

    FullCriteriaHash = metal_criteria.merge(baseline_criteria).with_indifferent_access.freeze
  else
    FullCriteriaHash = metal_criteria.with_indifferent_access.freeze
  end
rescue Errno::ENOENT

# Handle race condition if file is deleted between exist? check and load

  FullCriteriaHash = metal_criteria.with_indifferent_access.freeze
end

```

**OR Option B** (Keep existing load_file for consistency):

```ruby

# Load metal series criteria

metal_criteria = YAML.load_file('criteria/criteria.yml')

# Load baseline criteria if file exists

baseline_file = 'criteria/baseline_criteria.yml'
begin
  if File.exist?(baseline_file)
    baseline_criteria = YAML.load_file(baseline_file)

# Merge baseline criteria into metal criteria

    FullCriteriaHash = metal_criteria.merge(baseline_criteria).with_indifferent_access.freeze
  else
    FullCriteriaHash = metal_criteria.with_indifferent_access.freeze
  end
rescue Errno::ENOENT

# Handle race condition if file is deleted between exist? check and load

  FullCriteriaHash = metal_criteria.with_indifferent_access.freeze
end

```

**Note**: The existing codebase uses `YAML.load_file` (deprecated). Option A upgrades to the secure `YAML.safe_load_file` method, which is recommended for new code. Option B maintains consistency with the existing codebase. Both work, but Option A is better for security.

**IMPORTANT**: This initializer only runs at Rails startup. After changing criteria files, you **must restart the server** for changes to take effect.

**Verification command**:

```bash

# Restart Rails server to reload initializer

rails s

# Or in another terminal, test that it loads:

rails console
> FullCriteriaHash.keys

# Should return: ["0", "1", "2"] initially (metal series uses numeric keys)
# After adding baseline: ["0", "1", "2", "baseline-1", ...]

exit

```

**Rationale**: The initializer runs at Rails startup and loads criteria into memory. This approach allows both metal and baseline criteria to coexist.

### 2.6: Generate and Run Migration for Baseline-1 Stub

**Command**:

```bash

# Generate migration using sync system

rake baseline:generate_migration

```

**This creates**: `db/migrate/YYYYMMDDHHMMSS_add_baseline_criteria_sync_2_fields.rb`

**Auto-generated migration looks like**:

```ruby

# frozen_string_literal: true

# Auto-generated migration from baseline criteria sync
# Generated at: 2025-01-15T10:30:00Z
# Source: https://baseline.openssf.org/versions/2025-10-10/criteria.json

class AddBaselineCriteriaSync2Fields < ActiveRecord::Migration[8.0]
  def change

# baseline-1 criteria (2 stub criteria for testing)

    add_column :projects, :baseline_osps_gv_03_01_status, :string, default: '?'
    add_column :projects, :baseline_osps_gv_03_01_justification, :text

    add_column :projects, :baseline_osps_do_01_01_status, :string, default: '?'
    add_column :projects, :baseline_osps_do_01_01_justification, :text
  end
end

```

**Add achievement tracking fields manually** (first time only):

```bash

# Create additional migration for baseline infrastructure

rails generate migration AddBaselineInfrastructure

```

**Edit the generated migration**:

```ruby

# frozen_string_literal: true

class AddBaselineInfrastructure < ActiveRecord::Migration[8.0]
  def change

# Badge percentages for each baseline level

    add_column :projects, :badge_percentage_baseline_1, :integer, default: 0
    add_column :projects, :badge_percentage_baseline_2, :integer, default: 0
    add_column :projects, :badge_percentage_baseline_3, :integer, default: 0

# Achievement timestamps

    add_column :projects, :achieved_baseline_1_at, :datetime
    add_column :projects, :first_achieved_baseline_1_at, :datetime
    add_column :projects, :achieved_baseline_2_at, :datetime
    add_column :projects, :first_achieved_baseline_2_at, :datetime
    add_column :projects, :achieved_baseline_3_at, :datetime
    add_column :projects, :first_achieved_baseline_3_at, :datetime

# Indexes for performance

    add_index :projects, :achieved_baseline_1_at
    add_index :projects, :achieved_baseline_2_at
    add_index :projects, :achieved_baseline_3_at
  end
end

```

**Run migrations**:

```bash

rails db:migrate

```

**Rationale**:

- Sync system generates criteria-specific fields automatically
- Infrastructure fields (badge percentages, timestamps) added manually once
- Field names from sync use official baseline IDs: `baseline_osps_gv_03_01`
- All baseline fields have `baseline_` prefix for easy identification

### 2.7: Update Project Model for Baseline Badge Percentage

**File**: `app/models/project.rb`

**Locate** (around line 38):

```ruby

BADGE_LEVELS = %w[in_progress passing silver gold].freeze

```

**Add after**:

```ruby

# All criteria series (metal and baseline)

CRITERIA_SERIES = {
  metal: %w[passing silver gold],
  baseline: %w[baseline-1 baseline-2 baseline-3]
}.freeze

# All completed badge levels including baseline

ALL_BADGE_LEVELS = (CRITERIA_SERIES[:metal] + CRITERIA_SERIES[:baseline]).freeze

```

**Locate** method `calculate_badge_percentage` (around line 235):

```ruby

def calculate_badge_percentage(level)
  active = Criteria.active(level)
  met = active.count { |criterion| enough?(criterion) }
  to_percentage met, active.size
end

```

**Verify this works** with named levels by checking:

1. `Criteria.active(level)` properly looks up criteria by level name (it does - uses level as hash key)
2. The `enough?(criterion)` method doesn't rely on numeric level comparisons (should be fine)
3. No other methods called within the calculation chain use `.to_i` comparisons

**Note**: The method itself needs no changes, BUT it depends on:

- Criteria model loading baseline criteria into the `@criteria` hash with string keys
- The `get_text_if_exists` fix from Phase 1 section 1.13
- Proper YAML structure with named level keys

**Test after Phase 1 changes**:

```ruby

# In rails console after YAML keys updated:

project = Project.first
project.calculate_badge_percentage('passing')  # Should work
project.calculate_badge_percentage('baseline-1')  # Will work after Phase 3

```

**Add method** to determine preferred series:

```ruby

# Returns the preferred criteria series for this project
# @return [Symbol] :metal or :baseline

def preferred_series

# Default to metal for now; will be user-configurable later

  :metal
end

# Returns the preferred criteria level to display
# @return [String] 'passing', 'silver', 'gold', or 'baseline-1', etc.

def preferred_level
  series = preferred_series
  if series == :metal
    badge_level # existing method
  else
    baseline_badge_level
  end
end

# Returns baseline badge level based on achievement
# @return [String] 'in_progress' or 'baseline-1' (for now)
# NOTE: This initial implementation only handles baseline-1.
# It will be updated in Phase 5 to handle baseline-2 and baseline-3.

def baseline_badge_level
  if achieved_baseline_1_at
    'baseline-1'
  else
    'in_progress'
  end
end

```

### 2.8: Update Schema Validations

**File**: `app/models/project.rb`

**Locate** (around line 197):

```ruby

Criteria.each_value do |criteria|
  criteria.each_value do |criterion|

```

**This code should automatically pick up new baseline criteria** once they're loaded into Criteria class.

Verify that the validation loop works correctly by checking:

1. It iterates through all criteria (including baseline)
2. Adds validations for each criterion's status and justification fields

### 2.7: Update Route Constraints for Baseline-1

**File**: `config/routes.rb`

**Locate** (line 16-17):

```ruby

VALID_CRITERIA_LEVEL ||= /passing|silver|gold|permissions|0|1|2/

```

**Update to**:

```ruby

VALID_CRITERIA_LEVEL ||= /passing|silver|gold|baseline-1|permissions|0|1|2/

```

**Rationale**: Add baseline-1 to valid criteria levels.

### 2.8: Create Baseline-1 View Stub

**New file**: `app/views/projects/_form_baseline-1.html.erb`

```erb

<% # Form for baseline-1 criteria %>
<div class="panel panel-default">
  <div class="panel-heading">
    <h2><%= t('.baseline_1_header') %></h2>
    <p><%= t('.baseline_1_intro') %></p>
  </div>

  <div class="panel-body">
    <%= render(
      partial: 'form_basics',
      locals: { f: f, project: project, is_disabled: is_disabled }
    ) %>

    <h3><%= t('headings.Governance') %></h3>

    <%= render_status(
      :baseline_documentation,
      f, project, 'baseline-1', is_disabled
    ) %>

    <%= render_status(
      :baseline_contribution_process,
      f, project, 'baseline-1', is_disabled, true
    ) %>
  </div>
</div>

```

**Rationale**: Reuse existing rendering infrastructure (render_status helper) for consistency.

### Phase 2 Testing Checklist

- [ ] Migration runs successfully
- [ ] New database columns exist with correct defaults
- [ ] Baseline criteria YAML loads without errors
- [ ] Criteria model includes baseline-1 criteria
- [ ] Project model validations work for baseline fields
- [ ] `/projects/{id}/baseline-1` route works (even if showing stub data)
- [ ] No errors when creating new projects
- [ ] Existing tests still pass

### Phase 2 Workflow Summary

**Complete workflow for adding/updating baseline criteria**:

1. **Sync from upstream**:

   ```bash
   rake baseline:sync
   ```

   - Downloads criteria from OpenSSF
   - Updates `criteria/baseline_criteria.yml` with ALL fields
   - Includes description, details, and metadata

2. **Extract translations**:

   ```bash
   rake baseline:extract_i18n
   ```

   - Reads `criteria/baseline_criteria.yml`
   - Extracts description/details/placeholders
   - Updates `config/locales/en.yml` between markers
   - Preserves existing YAML comments

3. **Generate migration** (if new criteria added):

   ```bash
   rake baseline:generate_migration
   ```

   - Compares criteria with database schema
   - Creates migration for new fields only
   - Skips existing fields

4. **Run migration**:

   ```bash
   rails db:migrate
   ```

5. **Restart server**:

   ```bash
   rails s
   ```

   - Required because initializers load criteria at startup

**Key Files Modified**:

- `criteria/baseline_criteria.yml` - Source of truth (by sync)
- `config/locales/en.yml` - Translations (by extract_i18n)
- `db/migrate/YYYYMMDDHHMMSS_add_baseline_*.rb` - Migration (by generate_migration)

**Important Notes**:

- Always run `extract_i18n` after `sync` to keep locale files updated
- Review `git diff` after sync to see what changed
- Marker comments in `en.yml` must not be edited manually

---

## Phase 3: Full Baseline-1 Support

**Goal**: Add all baseline-1 criteria with full view/edit functionality.

### 3.1: Sync Full Baseline-1 Criteria

**Remove test mode filter** from `lib/baseline_criteria_sync.rb` (if using test mode):

```ruby

# Remove or comment out:
# controls = controls.first(2) if test_mode

```

**Run full sync**:

```bash

# Download all baseline-1 criteria

rake baseline:sync

# Check what was downloaded

rake baseline:version
cat criteria/baseline_criteria.yml | grep -A 1 "baseline-1:"

# Review field mapping

cat config/baseline_field_mapping.json | jq '.mappings | length'

# Should show total number of baseline-1 controls

```

### 3.2: Review Generated Mapping

The sync system automatically creates `config/baseline_field_mapping.json`. Review this file to understand the mapping.

**Example inspection**:

```bash

# Show all baseline-1 criteria

cat config/baseline_field_mapping.json | jq '.mappings[] | select(.level == "baseline-1") | {id: .baseline_id, field: .database_field, category: .category}'

```

**Manual documentation** (optional): Create `docs/baseline_criteria_mapping.md`

Example structure:

```markdown

# Baseline-1 Criteria Database Mapping

## Governance (OSPS-GV)

### OSPS-GV-03.01 - Contribution Process

- **Database field**: `baseline_contribution_process`
- **Category**: MUST
- **Requirements**: URL required
- **BP Badge mapping**: contribution (B-P-4)

### OSPS-GV-01.01 - Project Members List

- **Database field**: `baseline_project_members`
- **Category**: MUST (Level 2-3 only, so baseline-2/baseline-3)
- **Requirements**: URL required
- **BP Badge mapping**: governance (B-S-3)

```

**Action**: Review the baseline specification and create comprehensive mapping for all baseline-1 controls. Estimate ~20-40 controls for baseline-1.

### 3.3: Generate and Run Migration for Full Baseline-1

Now that we have the full baseline-1 criteria synced, generate the migration for all fields:

```bash

# Generate migration for all new baseline-1 fields

rake baseline:generate_migration

# This creates a file like: db/migrate/YYYYMMDDHHMMSS_add_baseline_criteria_sync_N.rb
# The migration includes all baseline-1 fields not yet in the database

```

**Example of auto-generated migration**:

```ruby

# frozen_string_literal: true

# This file was auto-generated by baseline:generate_migration
# DO NOT EDIT - Regenerate if baseline criteria change

class AddBaselineCriteriaSyncN < ActiveRecord::Migration[8.0]
  def change

# Governance (OSPS-GV)

    add_column :projects, :baseline_osps_gv_03_01_status, :string, default: '?'
    add_column :projects, :baseline_osps_gv_03_01_justification, :text

    add_column :projects, :baseline_osps_gv_01_01_status, :string, default: '?'
    add_column :projects, :baseline_osps_gv_01_01_justification, :text

# Security (OSPS-SE)

    add_column :projects, :baseline_osps_se_02_01_status, :string, default: '?'
    add_column :projects, :baseline_osps_se_02_01_justification, :text

# ... continue for all baseline-1 criteria

  end
end

```

**Run the migration**:

```bash

rails db:migrate

# Verify all baseline fields exist

rails console

# > Project.column_names.select { |c| c.start_with?('baseline_') }

```

**Rationale**: The sync system auto-generates migrations based on the field mapping, eliminating manual transcription errors.

### 3.4: Verify Auto-Generated Baseline-1 Criteria YAML

**File**: `criteria/baseline_criteria.yml` (AUTO-GENERATED - DO NOT EDIT)

This file was automatically generated by `rake baseline:sync`. **Do not manually edit this file** - it will be overwritten on the next sync.

**Verify the structure**:

```bash

# Check the file was generated

ls -l criteria/baseline_criteria.yml

# View metadata section

head -20 criteria/baseline_criteria.yml

# Count baseline-1 criteria

grep -c "category: MUST" criteria/baseline_criteria.yml

```

**Expected structure** (example):

```yaml

--- !!omap
_metadata:
  source: 'OpenSSF Baseline'
  version: '2025-10-10'
  synced_at: '2025-11-13T10:30:00Z'
  auto_generated: true
  do_not_edit: 'This file is auto-generated by rake baseline:sync. Do not edit manually.'

- baseline-1: !!omap
  - Governance: !!omap
    - Project Documentation: !!omap
      - baseline_osps_gv_03_01:

          category: MUST
          description: >
            While active, the project documentation MUST include an
            explanation of the contribution process.
          details: >
            Document project participants and their roles through such
            artifacts as members.md, governance.md, maintainers.md, or
            similar file within the source code repository of the project.
          met_url_required: true
          external_id: 'OSPS-GV-03.01'

# ... all other baseline-1 criteria

  - Security: !!omap
    - Vulnerability Disclosure: !!omap
      - baseline_osps_se_02_01:

          category: MUST
          description: >
            The project MUST have a documented vulnerability disclosure
            process.
          met_url_required: true
          external_id: 'OSPS-SE-02.01'

# ... continue for all categories

```

**Key differences from manual creation**:

- `_metadata` section marks it as auto-generated
- `external_id` field preserves original baseline control ID
- Consistent field naming via `baseline_osps_*` pattern
- All descriptions come directly from OpenSSF source

**If you need to customize criteria**: Modify the transformation in `lib/baseline_criteria_sync.rb`, then re-run `rake baseline:sync`.

### 3.5: Create Complete Baseline-1 View

**File**: `app/views/projects/_form_baseline-1.html.erb`

**Structure**:

```erb

<% # Full baseline-1 criteria form %>
<%= render(
  partial: 'form_early',
  locals: { project: project, is_disabled: is_disabled, criteria_level: 'baseline-1' }
) %>

<%= render(
  partial: 'form_basics',
  locals: { f: f, project: project, is_disabled: is_disabled }
) %>

<div class="panel panel-primary">
  <div class="panel-heading">
    <h2><%= t('.baseline_overview') %></h2>
  </div>
  <div class="panel-body">
    <p><%= t('.baseline_1_description') %></p>
    <p>
      <%= link_to t('.baseline_details'), 'https://baseline.openssf.org/versions/2025-10-10',
          target: '_blank', rel: 'noopener noreferrer' %>
    </p>
  </div>
</div>

<% # Iterate through all major categories %>
<% Criteria['baseline-1'].each do |major_category, minor_groups| %>
  <div class="panel panel-default">
    <div class="panel-heading">
      <%= minor_header_html(major_category) %>
    </div>
    <div class="panel-body">
      <% minor_groups.each do |minor_category, criteria| %>
        <h4><%= t(minor_category, scope: [:headings]) %></h4>
        <% criteria.each_with_index do |(criterion_name, _criterion), index| %>
          <% is_last = (index == criteria.size - 1) %>
          <%= render_status(
            criterion_name,
            f, project, 'baseline-1', is_disabled, is_last
          ) %>
        <% end %>
      <% end %>
    </div>
  </div>
<% end %>

```

**Rationale**: Reuse existing helpers and patterns from metal series forms for consistency.

### 3.6: Create Reusable Criteria Section Partial (Optional)

To reduce duplication in baseline-2 and baseline-3 views (Phase 5), optionally create a reusable partial:

**New file**: `app/views/projects/_criteria_section.html.erb`

```erb

<% # Reusable partial for rendering a major category of criteria

# Used by baseline-2 and baseline-3 forms

# locals: major_category, minor_groups, f, project, criteria_level, is_disabled

%>
<div class="panel panel-default">
  <div class="panel-heading">
    <%= minor_header_html(major_category) %>
  </div>
  <div class="panel-body">
    <% minor_groups.each do |minor_category, criteria| %>
      <h4><%= t(minor_category, scope: [:headings]) %></h4>
      <% criteria.each_with_index do |(criterion_name, _criterion), index| %>
        <% is_last = (index == criteria.size - 1) %>
        <%= render_status(
          criterion_name,
          f, project, criteria_level, is_disabled, is_last
        ) %>
      <% end %>
    <% end %>
  </div>
</div>

```

**Note**: This partial is optional for Phase 3. It becomes useful in Phase 5 when you have multiple similar baseline views.

### 3.7: Update Project Model Methods

**File**: `app/models/project.rb`

**Update method** `update_badge_percentages` to include baseline:

**Locate** the existing method (around line 250):

```ruby

def update_badge_percentages
  self.badge_percentage_0 = calculate_badge_percentage('passing')
  self.badge_percentage_1 = calculate_badge_percentage('silver')
  self.badge_percentage_2 = calculate_badge_percentage('gold')
  update_tiered_percentage
end

```

**Replace with**:

```ruby

# Update badge percentages for all levels including baseline
# This is called by before_save callback

def update_badge_percentages

# Metal series

  self.badge_percentage_0 = calculate_badge_percentage('passing')
  self.badge_percentage_1 = calculate_badge_percentage('silver')
  self.badge_percentage_2 = calculate_badge_percentage('gold')

# Baseline series - reuse the same method since Criteria.active(level) works for both

  self.badge_percentage_baseline_1 = calculate_badge_percentage('baseline-1')

# Update tiered percentage to reflect highest achievement

  update_tiered_percentage

# Update achievement timestamps

  update_achievement_timestamps
end

```

**Note**: No need for a separate `calculate_baseline_percentage` method - the existing `calculate_badge_percentage(level)` works for both metal and baseline levels since it just passes the level to `Criteria.active(level)`.

**Add method** for achievement timestamp management:

```ruby

# Update achievement timestamps based on percentages

def update_achievement_timestamps
  update_metal_timestamps
  update_baseline_timestamps
end

# Update baseline achievement timestamps

def update_baseline_timestamps
  update_level_timestamp('baseline-1', badge_percentage_baseline_1)

# Will add baseline-2 and baseline-3 later

end

# Generic method to update achievement timestamp for a level

def update_level_timestamp(level, percentage)
  achieved_field = "achieved_#{level.tr('-', '_')}_at"
  first_achieved_field = "first_#{achieved_field}"

  if percentage >= 100

# Project achieved this level

    self[achieved_field] ||= Time.current
    self[first_achieved_field] ||= Time.current
  else

# Project lost this level

    self[achieved_field] = nil
  end
end

```

### 3.8: Update Controllers for Baseline-1

**File**: `app/controllers/projects_controller.rb`

**Update** `normalize_criteria_level` (if not already updated in Phase 1):

```ruby

def normalize_criteria_level(level)
  case level.to_s.downcase
  when '0', 'passing', 'bronze' then '0'
  when '1', 'silver' then '1'
  when '2', 'gold' then '2'
  when 'baseline-1' then 'baseline-1'
  when 'permissions' then 'permissions'
  else '0' # default to passing (level 0)
  end
end

```

**Update** `show` method to handle baseline-1 similar to other levels (no special changes needed if using @criteria_level variable consistently).

### 3.9: Add Navigation Between Levels

**File**: `app/views/projects/_form_early.html.erb` (or create new partial)

**Add level switcher**:

```erb

<div class="criteria-level-nav">
  <h3><%= t('.select_criteria_level') %></h3>
  <div class="btn-group" role="group">
    <%= link_to t('.passing'),
        project_path(@project, criteria_level: 'passing'),
        class: "btn btn-default #{@criteria_level == '0' ? 'active' : ''}" %>
    <%= link_to t('.silver'),
        project_path(@project, criteria_level: 'silver'),
        class: "btn btn-default #{@criteria_level == '1' ? 'active' : ''}" %>
    <%= link_to t('.gold'),
        project_path(@project, criteria_level: 'gold'),
        class: "btn btn-default #{@criteria_level == '2' ? 'active' : ''}" %>
    <span class="btn-group-separator">|</span>
    <%= link_to t('.baseline_1'),
        project_path(@project, criteria_level: 'baseline-1'),
        class: "btn btn-default #{@criteria_level == 'baseline-1' ? 'active' : ''}" %>
  </div>
</div>

```

### 3.10: Update Permitted Parameters

**File**: `app/controllers/projects_controller.rb`

**Locate** `PROJECT_PERMITTED_FIELDS` constant usage (around line 61-63):

```ruby

ALL_CRITERIA_STATUS = Criteria.all.map(&:status).freeze
ALL_CRITERIA_JUSTIFICATION = Criteria.all.map(&:justification).freeze
PROJECT_PERMITTED_FIELDS = (PROJECT_OTHER_FIELDS + ALL_CRITERIA_STATUS +
                            ALL_CRITERIA_JUSTIFICATION +
                            PROJECT_USER_ID_REPEAT).freeze

```

**No changes needed** - this dynamically includes all criteria from Criteria class, so baseline criteria will be automatically included.

### Phase 3 Testing Checklist

- [ ] All baseline-1 criteria load from YAML
- [ ] All database fields exist for baseline-1
- [ ] Baseline-1 form renders with all criteria
- [ ] Can view baseline-1 page for existing projects
- [ ] Can edit baseline-1 criteria
- [ ] Badge percentage calculates correctly
- [ ] Achievement timestamps update correctly
- [ ] Can save changes to baseline-1 criteria
- [ ] Navigation between levels works
- [ ] No JavaScript errors in browser console
- [ ] Validations work for baseline-1 fields
- [ ] All linters pass (rubocop, rails_best_practices, markdownlint)

---

## Phase 4: Baseline Badge Images

**Goal**: Add `/projects/{id}/baseline` route for baseline series badge images.

### 4.0: Review previous effort

The git branch `baseline_phase4` has the start of a previous effort
to implement phase 4. It started to look unnecessarily complex and
include unrelated changes. Nevertheless, pieces of it may be useful to
bring in, and it will help to identify what needs changing.

You can see what changes were proposed in the branch by running:

~~~~sh
git diff 4f55e826ac37194754e496e4f8b858365a274382 baseline_phase4
~~~~

Then review the rest of the plan for phase 4, and propose updates.

Remember, we want the final code to be as short, simple, and clear as possible.

### 4.1: Design Baseline Badge Images

**Directory**: `app/assets/images/`

**Create new badge images**:

- `badge_baseline_in_progress.svg` - Shows percentage (0-99%)
- `badge_baseline_1.svg` - Shows "Baseline Level 1"
- `badge_baseline_2.svg` - Shows "Baseline Level 2"
- `badge_baseline_3.svg` - Shows "Baseline Level 3"

**Design considerations**:

- Use different color scheme from metal series (e.g., blue instead of green/silver/gold)
- Maintain same width standards for CDN caching
- Include OpenSSF branding
- Clear, readable text

**File**: `app/assets/images/badge_static_widths_baseline.txt`

Document widths of new baseline badges (generated by rake task).

### 4.2: Update Badge Model for Baseline

**File**: `app/models/badge.rb`

**Locate** constants (lines 9-15):

```ruby

ACCEPTABLE_PERCENTAGES = (0..99).to_a.freeze
ACCEPTABLE_LEVELS = %w[passing silver gold].freeze

```

**Add** something link:

```ruby

BASELINE_LEVELS = %w[baseline-1 baseline-2 baseline-3].freeze
ACCEPTABLE_LEVELS = %w[passing silver gold].freeze
ALL_ACCEPTABLE_LEVELS = (ACCEPTABLE_LEVELS + BASELINE_LEVELS).freeze

```

**Update** `ACCEPTABLE_INPUTS`:

```ruby

ACCEPTABLE_INPUTS = (
  ACCEPTABLE_PERCENTAGES + ACCEPTABLE_LEVELS + BASELINE_LEVELS
).to_set.freeze

```

**Update** `BADGE_WIDTHS` hash:

```ruby

BADGE_WIDTHS = {

# Metal series

  'passing': 184,
  'silver': 172,
  'gold': 166,

# Baseline series

  'baseline-1': 200,  # Update with actual width
  'baseline-2': 200,  # Update with actual width
  'baseline-3': 200,  # Update with actual width

# Percentages...

  '0': 228,

# ...

}.freeze

```

**Update** `load_svg` method (around line 201):

```ruby

def load_svg(level)
  return '' unless self.class.valid?(level)

# Baseline levels use different file naming

  if level.to_s.start_with?('baseline')
    File.read("app/assets/images/badge_#{level.tr('-', '_')}.svg")
  else
    File.read("app/assets/images/badge_static_#{level}.svg")
  end
end

```

### 4.3: Add Baseline Badge Route

**File**: `config/routes.rb`

**Add after line 46** (after metal badge route):

```ruby

# Baseline badge image route (no locale, for CDN caching)

get '/projects/:id/baseline' => 'projects#baseline_badge',
    constraints: { id: VALID_ID },
    defaults: { format: 'svg' }

```

### 4.4: Update BADGE_PROJECT_FIELDS Constant

**File**: `app/controllers/projects_controller.rb`

**Locate** (around lines 193-195):

```ruby

BADGE_PROJECT_FIELDS =
  'id, name, updated_at, tiered_percentage, ' \
  'badge_percentage_0, badge_percentage_1, badge_percentage_2'

```

**Replace with**:

```ruby

BADGE_PROJECT_FIELDS =
  'id, name, updated_at, tiered_percentage, ' \
  'badge_percentage_0, badge_percentage_1, badge_percentage_2, ' \
  'badge_percentage_baseline_1, badge_percentage_baseline_2, badge_percentage_baseline_3, ' \
  'achieved_baseline_1_at, achieved_baseline_2_at, achieved_baseline_3_at'

```

**Rationale**: The `badge` and `baseline_badge` actions use this constant to select only necessary fields for performance. Including baseline fields ensures the baseline badge route can access them efficiently.

### 4.5: Add Baseline Badge Controller Action

**File**: `app/controllers/projects_controller.rb`

**Add action** (after `badge` method around line 227):

```ruby

# Generate baseline badge image for project
# Similar to badge action but for baseline series
# @return [void]

def baseline_badge

# Select only fields needed for baseline badge

  @project = Project.select(
    :id, :badge_percentage_baseline_1,
    :achieved_baseline_1_at, :achieved_baseline_2_at, :achieved_baseline_3_at,
    :updated_at
  ).find(params[:id])

# Set CDN surrogate key

  set_surrogate_key_header @project.record_key

  respond_to do |format|
    format.svg do
      send_data Badge[@project.baseline_badge_value],
                type: 'image/svg+xml', disposition: 'inline'
    end
    format.json do
      render json: {
        level: @project.baseline_badge_level,
        percentage: @project.badge_percentage_baseline_1
      }
    end
  end
end

```

**Update** `skip_before_action` (around line 14):

```ruby

skip_before_action :redir_missing_locale, only: %i[badge baseline_badge]

```

**Update** `skip_before_action` and `before_action` for caching (around lines 28-30):

```ruby

skip_before_action :set_default_cache_control, only:
                   %i[badge baseline_badge show_json show_markdown]
before_action :cache_on_cdn, only: %i[badge baseline_badge show_json show_markdown]

```

### 4.6: Add Project Model Method for Baseline Badge Value

**File**: `app/models/project.rb`

**Add method**:

```ruby

# Returns the badge value for baseline series
# Similar to badge_value but for baseline
# @return [String, Integer] badge level name or percentage

def baseline_badge_value
  if badge_percentage_baseline_1 >= 100
    'baseline-1'
  else
    badge_percentage_baseline_1
  end
end

```

### 4.7: Update Badge Display in Views

**File**: `app/views/projects/show.html.erb`

**Add baseline badge display** (around line 15, near existing badge):

```erb

<div class="badge-display">
  <h3><%= t('.metal_series_badge') %></h3>
  <img src="<%= project_path(@project) %>/badge.svg"
       alt="<%= t('.badge_alt', level: @project.badge_level) %>">

  <h3><%= t('.baseline_series_badge') %></h3>
  <img src="<%= project_path(@project) %>/baseline.svg"
       alt="<%= t('.baseline_badge_alt', level: @project.baseline_badge_level) %>">
</div>

```

### 4.8: Update Badge README/Documentation

**File**: Update any documentation about badge URLs

Add information about `/projects/{id}/baseline` route.

### Phase 4 Testing Checklist

- [ ] Baseline badge images created and look good
- [ ] Badge model loads baseline badge SVGs
- [ ] `/projects/{id}/baseline` route works
- [ ] Baseline badge displays correct level/percentage
- [ ] Badge updates when project criteria change
- [ ] CDN caching headers set correctly
- [ ] JSON format returns correct data
- [ ] Both metal and baseline badges display on project page

**Example test** (add to `test/controllers/projects_controller_test.rb`):

```ruby

test "baseline_badge route returns SVG" do
  project = projects(:perfect_passing) # Use appropriate fixture
  get baseline_badge_project_path(project, format: 'svg')
  assert_response :success
  assert_equal 'image/svg+xml', @response.content_type
  assert_match /baseline/, @response.body
end

test "baseline_badge shows percentage when in progress" do
  project = projects(:one)
  project.update(badge_percentage_baseline_1: 50)
  get baseline_badge_project_path(project, format: 'svg')
  assert_response :success
  assert_match /50%/, @response.body
end

test "baseline_badge shows level when achieved" do
  project = projects(:one)
  project.update(
    badge_percentage_baseline_1: 100,
    achieved_baseline_1_at: Time.current
  )
  get baseline_badge_project_path(project, format: 'svg')
  assert_response :success
  assert_match /Baseline.*1/i, @response.body
end

```

---

## Phase 5: Baseline-2 and Baseline-3

**Goal**: Add full support for baseline-2 and baseline-3 levels.

Remember, it's important that the final code be simple, clear, and minimal.
All code must have 100% statement coverage. We expect baseline to
change over time, so the system must be able to adjust as baseline
criteria change. The image displayed by /projects/:id/baseline must
show the correct level (e.g,. baseline level 2 if the level 1 and level 2
criteria were met but level 3 was not).

### 5.1: Sync Baseline-2 and Baseline-3 Criteria

The sync system automatically includes all three baseline levels. Verify baseline-2 and baseline-3 were synced:

```bash

# Check criteria file includes all three levels

grep "^- baseline-" criteria/baseline_criteria.yml

# Should show:
# - baseline-1: !!omap
# - baseline-2: !!omap
# - baseline-3: !!omap

# Review field mapping for baseline-2 and baseline-3

cat config/baseline_field_mapping.json | jq '.mappings[] | select(.level == "baseline-2" or .level == "baseline-3") | {id: .baseline_id, field: .database_field, level: .level}'

```

**Key differences between levels**:

- Baseline-1 includes foundational controls (MUST requirements for all projects)
- Baseline-2 includes baseline-1 controls plus additional maturity level 2 requirements
- Baseline-3 includes baseline-1 and baseline-2 controls plus maturity level 3 requirements
- Some controls appear across multiple levels (indicated in field mapping)

**Verify infrastructure fields from Phase 2.4**:

The infrastructure fields (badge_percentage_baseline_*, achieved_baseline_*_at) for **all three** baseline levels should already exist from Phase 2.4. These were created once to support all three levels.

```bash

rails console

# > Project.column_names.grep(/baseline_[123]/)
# Should show:
# - badge_percentage_baseline_1, badge_percentage_baseline_2, badge_percentage_baseline_3
# - achieved_baseline_*_at and first_achieved_baseline_*_at for all three levels

```

**Note**: If you skipped Phase 2 or the infrastructure migration failed, you'll need to create and run the AddBaselineInfrastructure migration shown in Phase 2.4. However, in normal sequential execution, these fields already exist.

### 5.2: Generate and Run Migrations for Baseline-2 and Baseline-3

Since the sync system already downloaded all three levels, generate migrations for any new fields from baseline-2 and baseline-3:

```bash

# Generate migration for all new baseline fields not yet in database

rake baseline:generate_migration

# This will create fields for baseline-2 and baseline-3 controls that weren't
# already added in baseline-1

```

**Note**: The migration generator is smart - it only creates fields for criteria that don't already exist in the database. Since we already ran migrations for baseline-1 in Phase 3.3, this will only add baseline-2 and baseline-3 specific fields.

**Example of auto-generated migration**:

```ruby

# frozen_string_literal: true

# This file was auto-generated by baseline:generate_migration
# DO NOT EDIT - Regenerate if baseline criteria change

class AddBaselineCriteriaSyncN < ActiveRecord::Migration[8.0]
  def change

# Baseline-2 specific controls

    add_column :projects, :baseline_osps_gv_01_01_status, :string, default: '?'
    add_column :projects, :baseline_osps_gv_01_01_justification, :text

    add_column :projects, :baseline_osps_se_04_02_status, :string, default: '?'
    add_column :projects, :baseline_osps_se_04_02_justification, :text

# Baseline-3 specific controls

    add_column :projects, :baseline_osps_cc_05_01_status, :string, default: '?'
    add_column :projects, :baseline_osps_cc_05_01_justification, :text

# ... all other baseline-2 and baseline-3 fields

  end
end

```

**Run the migration**:

```bash

rails db:migrate

# Verify all baseline fields exist

rails console

# > Project.column_names.select { |c| c.start_with?('baseline_') }.count
# Should show total number of baseline fields (status + justification for each control)

```

**Important**: The infrastructure fields (badge_percentage_baseline_*, achieved_baseline_*_at) were already added in Phase 2.4. This migration only adds the criteria-specific fields.

### 5.3: Verify Auto-Generated Baseline Criteria YAML

**File**: `criteria/baseline_criteria.yml` (AUTO-GENERATED - DO NOT EDIT)

This file was automatically generated by `rake baseline:sync` and includes all three baseline levels.

**Verify all three levels are present**:

```bash

# Check structure

cat criteria/baseline_criteria.yml | grep "^- baseline-"

# Count criteria in each level

echo "Baseline-1 controls:"
yq '.["baseline-1"] | .. | select(has("category")) | .category' criteria/baseline_criteria.yml | wc -l

echo "Baseline-2 controls:"
yq '.["baseline-2"] | .. | select(has("category")) | .category' criteria/baseline_criteria.yml | wc -l

echo "Baseline-3 controls:"
yq '.["baseline-3"] | .. | select(has("category")) | .category' criteria/baseline_criteria.yml | wc -l

```

**Expected structure** (partial example):

```yaml

--- !!omap
_metadata:
  source: 'OpenSSF Baseline'
  version: '2025-10-10'
  synced_at: '2025-11-13T10:30:00Z'
  auto_generated: true

- baseline-1: !!omap

# ... all baseline-1 criteria (see Phase 3.4)

- baseline-2: !!omap
  - Governance: !!omap
    - Project Members List: !!omap
      - baseline_osps_gv_01_01:

          category: MUST
          description: >
            While active, the project documentation MUST include a list
            of project members with access to sensitive resources.
          details: >
            Document project participants and their roles through such
            artifacts as members.md, governance.md, maintainers.md, or
            similar file within the source code repository of the project.
          met_url_required: true
          external_id: 'OSPS-GV-01.01'
          maturity_level: [2, 3]

# ... all baseline-2 criteria

- baseline-3: !!omap
  - Code Review: !!omap
    - Required Review: !!omap
      - baseline_osps_cc_05_01:

          category: MUST
          description: >
            The project MUST require code review before merging changes
            to the main branch.
          met_url_required: true
          external_id: 'OSPS-CC-05.01'
          maturity_level: [3]

# ... all baseline-3 criteria

```

**Key attributes**:

- `external_id`: Original OpenSSF Baseline control ID
- `maturity_level`: Array showing which baseline levels include this control
- All text comes directly from OpenSSF source

**To update criteria**: Run `rake baseline:sync` - do not manually edit this file.

### 5.4: Create Views for Baseline-2 and Baseline-3

In file `app/controllers/projects_controller.rb` ensure that
`badge_level_lost?` handles multiple baseline levels.

**New file**: `app/views/projects/_form_baseline-2.html.erb`

```erb

<% # Form for baseline-2 criteria %>
<%= render(
  partial: 'form_early',
  locals: { project: project, is_disabled: is_disabled, criteria_level: 'baseline-2' }
) %>

<%= render(
  partial: 'form_basics',
  locals: { f: f, project: project, is_disabled: is_disabled }
) %>

<div class="panel panel-primary">
  <div class="panel-heading">
    <h2><%= t('.baseline_2_header') %></h2>
  </div>
  <div class="panel-body">
    <p><%= t('.baseline_2_description') %></p>
  </div>
</div>

<% # Iterate through all baseline-2 criteria %>
<% Criteria['baseline-2'].each do |major_category, minor_groups| %>
  <%= render partial: 'criteria_section',
      locals: {
        major_category: major_category,
        minor_groups: minor_groups,
        f: f,
        project: project,
        criteria_level: 'baseline-2',
        is_disabled: is_disabled
      } %>
<% end %>

```

**New file**: `app/views/projects/_form_baseline-3.html.erb`

Similar structure to baseline-2 but for baseline-3.

### 5.5: Update Route Constraints

**File**: `config/routes.rb`

**Update** (line 16-17):

```ruby

VALID_CRITERIA_LEVEL ||= /passing|silver|gold|baseline-1|baseline-2|baseline-3|permissions|0|1|2/

```

### 5.6: Update Controllers

**File**: `app/controllers/projects_controller.rb`

**Update** `normalize_criteria_level`:

```ruby

def normalize_criteria_level(level)
  case level.to_s.downcase
  when '0', 'passing', 'bronze' then '0'
  when '1', 'silver' then '1'
  when '2', 'gold' then '2'
  when 'baseline-1' then 'baseline-1'
  when 'baseline-2' then 'baseline-2'
  when 'baseline-3' then 'baseline-3'
  when 'permissions' then 'permissions'
  else '0' # default to passing (level 0)
  end
end

```

### 5.7: Update Project Model

**File**: `app/models/project.rb`

**Update** `update_badge_percentages` to include all three baseline levels:

```ruby

def update_badge_percentages

# Metal series

  self.badge_percentage_0 = calculate_badge_percentage('passing')
  self.badge_percentage_1 = calculate_badge_percentage('silver')
  self.badge_percentage_2 = calculate_badge_percentage('gold')

# Baseline series - all three levels

  self.badge_percentage_baseline_1 = calculate_badge_percentage('baseline-1')
  self.badge_percentage_baseline_2 = calculate_badge_percentage('baseline-2')
  self.badge_percentage_baseline_3 = calculate_badge_percentage('baseline-3')

  update_tiered_percentage
  update_achievement_timestamps
end

```

**Rationale**: Extends the Phase 3 implementation to calculate percentages for all three baseline levels.

**Update** `update_baseline_timestamps`:

```ruby

def update_baseline_timestamps
  update_level_timestamp('baseline-1', badge_percentage_baseline_1)
  update_level_timestamp('baseline-2', badge_percentage_baseline_2)
  update_level_timestamp('baseline-3', badge_percentage_baseline_3)
end

```

**Update** `baseline_badge_level` to handle all three levels:

**Replace** the Phase 2 implementation with:

```ruby

def baseline_badge_level

# Check highest achieved level (baseline-3 takes precedence)

  if badge_percentage_baseline_3 >= 100 || achieved_baseline_3_at
    'baseline-3'
  elsif badge_percentage_baseline_2 >= 100 || achieved_baseline_2_at
    'baseline-2'
  elsif badge_percentage_baseline_1 >= 100 || achieved_baseline_1_at
    'baseline-1'
  else
    'in_progress'
  end
end

```

**Rationale**: Extends the Phase 2 implementation to check all three baseline levels and also considers badge percentage (not just achievement timestamps).

**Update** `baseline_badge_value`:

```ruby

def baseline_badge_value
  level = baseline_badge_level
  if level == 'in_progress'

# Return percentage of highest baseline level being worked on

    badge_percentage_baseline_1
  else
    level
  end
end

```

### 5.8: Update Navigation

**File**: `app/views/projects/_form_early.html.erb`

**Update level switcher** to include baseline-2 and baseline-3:

```erb

<div class="criteria-level-nav">
  <h3><%= t('.select_criteria_level') %></h3>

  <h4><%= t('.metal_series') %></h4>
  <div class="btn-group" role="group">
    <%= link_to t('.passing'), project_path(@project, criteria_level: 'passing'),
        class: "btn btn-default #{@criteria_level == '0' ? 'active' : ''}" %>
    <%= link_to t('.silver'), project_path(@project, criteria_level: 'silver'),
        class: "btn btn-default #{@criteria_level == '1' ? 'active' : ''}" %>
    <%= link_to t('.gold'), project_path(@project, criteria_level: 'gold'),
        class: "btn btn-default #{@criteria_level == '2' ? 'active' : ''}" %>
  </div>

  <h4><%= t('.baseline_series') %></h4>
  <div class="btn-group" role="group">
    <%= link_to t('.baseline_1'), project_path(@project, criteria_level: 'baseline-1'),
        class: "btn btn-default #{@criteria_level == 'baseline-1' ? 'active' : ''}" %>
    <%= link_to t('.baseline_2'), project_path(@project, criteria_level: 'baseline-2'),
        class: "btn btn-default #{@criteria_level == 'baseline-2' ? 'active' : ''}" %>
    <%= link_to t('.baseline_3'), project_path(@project, criteria_level: 'baseline-3'),
        class: "btn btn-default #{@criteria_level == 'baseline-3' ? 'active' : ''}" %>
  </div>
</div>

```

### Phase 5 Testing Checklist

- [ ] All baseline-2 and baseline-3 migrations run successfully
- [ ] All criteria load from YAML
- [ ] Forms render for all baseline levels
- [ ] Can edit all baseline levels
- [ ] Badge percentages calculate correctly for all levels
- [ ] Achievement timestamps update correctly
- [ ] Baseline badge displays correct level (1, 2, or 3)
- [ ] Navigation works between all levels
- [ ] All tests pass including new baseline levels

---

## Phase 6: Translation Support

**Goal**: Add default natural language translations where they're not given.

Adding baseline adds a *massive* number of natural language text strings that
need translations to other human languages.
The plan is to add machine translations that will be used *only*
if there is no human translation available.

We currently use `rake translation:sync` to send updated English keys and
text from `config/locales/en.yml` to the `translation.io` site and receive
back translations that are stored in `config/locales/translation.*.yml`
(one for each language). Humans provide the translations on translation.io.
The translation.io system has an API documented at
<https://translation.io/docs/api>.
A `GET https://translation.io/api/v1/segments(.json)` will get all segments,
and this can be filtered by parameters such as `target_language`
or `tag` (including the tag `source changed`, indicating that the translation
is for an older version of the original text).

[Rails' I18n system](https://guides.rubyonrails.org/i18n.html)
supports `load_path` that lets us add paths to find translations.
When the same key has multiple definitions,
[the last value set is used](https://stackoverflow.com/questions/1840027/rails-how-to-dynamically-add-override-wording-to-i18n-yaml).
The plan is to create a new `config/machine_translation/` directory
and modify the I18n configuration with something like this:

~~~ruby
config.i18n.load_path +=
  Dir[Rails.root.join("config", "machine_translation", "*.yml")]
~~~

Every `config/locales/translation.*.yml` file *may* have a corresponding
`config/machine_translation/translation.*.yml` file, where the machine
translation of untranslated text will be placed. As a result, any
machine translation *available* will be used.

Every time translation:sync completes, the files in `machine_translation`
will be consulted, and every key that is *defined* with a non-empty
value in the updated `config/locales/*.yml` files will be *removed*
from the corresponding file in `machine_translation` (by loading it,
removing those keys, and storing the result). This means that human
translations will always be given precedence.
In the future we might choose to *not* remove segments if
"source changed" (basically, de-prioritize a human translation if it
was a translation of an older different string).
There should also be a
rake task that lets you specify keys to delete from all the
machine translations (so that if a value is changed, we can remove
and later update the machine translations).

A new rake process will be created to do machine translation of
"N" keys not currently translated, as follows:

* First, ensure we have a reasonably current list of translation segments
  tagged with "source change" (these are translations we shouldn't use
  as examples). If we have a cached file less than a day old, just use it.
  Otherwise, if we have a key allowing us to do it,
  load the list of segments where their tag is
  "source changed" into a cached file using the API documented in
  <https://translation.io/docs/api>.
* Walk through language by language, starting with French
  (because David A. Wheeler can read some French) and then German,
  Japanese, Simplified Chinese, and then the other languages we support.
  Do Swahili last (we don't have human backing any more, and LLMs are
  likely to do Swahili translations relatively poorly).
* It will identify up to N untranslated values, that is, the value is in
  en.yml but it's not translated in its corresponding translation file
  for that language.
  A value isn't present if its key isn't present or its value is empty.
  (In the future we could also consider a value isn't present if its
  translation is tagged 'source changed'; make that easy to enable later.)
  If there are 0 untranslated values, it will try the next language until
  we find a case where at least 1 value is untranslated or we run out of
  languages to translate.
* Generate YAML file with those keys and values that need translating.
  Use YAML's folded scalar
  style (`>-`) for multiline text to keep the format compact and readable.
* Increase the likelihood that we'll use the same translated terms
  for the same words in our translation.
  We'll do this by using our existing translations
  like an automatically-created glossary.
  Identify keys and values that are *already* translated in that language
  and are *not* marked as "source changed"
  (that is, the translations are current).
  Walk through the values selected for translating, find acronyms and unusual
  words in what's to be translated, and select at least one example where
  possible from the set of already used translations.
  Identify unusual words using these patterns:
  (1) acronyms: 2+ consecutive capitals like MFA, VCS, CI/CD;
  (2) proper nouns: capitalized words like GitHub, OpenSSF, Passkeys;
  (3) technical compounds: hyphenated terms like multi-factor, version-control;
  (4) long technical words: words longer than 12 characters like
  authentication, vulnerability.
  We could also load Google's 10K most common English words in
  <https://github.com/first20hours/google-10000-english>
  and add other words not in this list.
  Select only a limited number so we're not overwhelming the translator.
  Generate a pair of "demo" YAML files in English and the language we're
  translating to show what a translation looks like.
* Ask an LLM (the current plan is copilot with its "-p" option)
  to read the generated YAML file of values to be translated,
  and to generate a new YAML file
  (with a given name) that translates the file's values. Include in the
  instructions pointers to the YAML examples. Instruct the LLM
  to *never* translate keys, only values. Ask it to be careful to
  not change template stubs, but that if there are references to a URL
  path beginning with /en (English)
  to change "en" to the corresponding locale name (e.g., "zh_CH" or
  "de"). Emphasize preserving proper YAML indentation and using `>-`
  for multiline values.
* Once there's a result, instruct the
  LLM to review the translated result, compare it to the original,
  to ensure it's correct
  and fix any issues. In particular, ask the LLM to ensure that all
  translated results aren't simply some error return from the translation
  process like "Translation process failed", but are instead valid translations.
* If the LLM appears to succeed in both steps,
  read and validate the YAML.
  At the least, verify that all keys that were supposed to be translated
  are in the final result and that the values aren't empty
  (unless the English value is empty).
  If this succeeds, update the corresponding
  YAML machine translation for that language
  using the data from this YAML file.
* These updated YAML files can then be checked in to the repository.

We do *not* want to overwhelm the LLMs with too much translation work.
The plan is to repeatedly ask an LLM to do a little over a period of time.

Note that we do *not* want to use ActiveRecord to store translations.
That's not usually how it's done in Rails, and doing that would create
a lot of unnecessary overhead.

Obviously an LLM can make mistakes in translation. We'll partly compensate by
asking the LLM to review its work, and verifying that at least the
YAML has proper format (valid syntax, all keys present, no empty values).
Using YAML directly is more token-efficient than JSON (20-30% fewer tokens)
and is already our target format, avoiding conversion overhead.
More importantly, we'll always prefer the human translations,
and use machine translations only when a human translation isn't available.

This approach does mean that obsolete human translations (human
translations of older versions of text) will have precedence over machine
translations of current text. It's not clear what *should* be done in
such cases, so this seems acceptable.

### Phase 6 Testing Checklist

- [ ] All baseline criteria have English translations
- [ ] Machine translations available for all supported languages
- [ ] Human translations override machine translations
- [ ] Translation keys resolve correctly
- [ ] No missing translation warnings
- [ ] All languages display baseline criteria

---

## Phase 7: Trivial Automation

**Goal**: Add trivial automated checking for baseline criteria, leveraging existing automation where possible.

### 6.1: Analyze Existing Automation

**File**: `app/lib/chief.rb` (or wherever autofill logic lives)

**Review**:

- Which metal criteria have automation
- What external services are used (GitHub API, etc.)
- How can we map those to baseline criteria (e.g., for OSS licenses)

**Example mappings**:

- Metal `repo_public` → Baseline `baseline_version_control`
- Metal `vulnerability_report_process` → Baseline `baseline_vulnerability_disclosure`
- Metal `contribution` → Baseline `baseline_contribution_process`

### 6.2: Create Baseline Autofill Strategy

**Document**: Create `docs/baseline_automation.md`

Map each baseline criterion to:

1. **Direct mapping**: Can reuse existing metal criterion check
2. **Partial mapping**: Can use existing check with modifications
3. **New check needed**: Requires new automation
4. **Manual only**: Cannot be automated

### 6.3: Extend Autofill Logic for Baseline

**File**: `app/lib/chief.rb` (or similar)

**Add method**:

```ruby

# Autofill baseline criteria based on existing project data

def autofill_baseline
  autofill_baseline_from_metal
  autofill_baseline_from_github

# More autofill methods as needed

end

# Copy applicable data from metal criteria to baseline

def autofill_baseline_from_metal

# Example: if project has filled in contribution URL,

# use it for baseline_contribution_process

  if @project.contribution_status == 'Met' &&
     @project.contribution_justification.present?
    @project.baseline_contribution_process_status = 'Met'
    @project.baseline_contribution_process_justification =
      @project.contribution_justification
  end

# More mappings...

end

# Check GitHub API for baseline-relevant information

def autofill_baseline_from_github
  return unless github_repo?

# Check for security policy

  if repo_has_security_policy?
    @project.baseline_vulnerability_disclosure_status = 'Met'
    @project.baseline_vulnerability_disclosure_justification =
      "Security policy found at #{security_policy_url}"
  end

# More checks...

end

```

### 6.4: Add Baseline Suggestions

Similar to how the metal series provides suggestions, add hints for baseline criteria.

**File**: Extend views to show suggestions based on available data.

### 6.5: Summarize Automation Status

**Optional**: Create summary showing:

- Which baseline criteria have automation
- Success rate of automated checks
- Common failure patterns

### Phase 7 Testing Checklist

- [ ] Autofill populates baseline criteria where possible
- [ ] Automation doesn't incorrectly mark criteria as met
- [ ] Manual review still possible for all criteria
- [ ] Suggestions appear appropriately
- [ ] No false positives in automated checks

---

## Phase 8: Project Search and Filtering

**Goal**: Update project search and filtering to support baseline badge levels, allowing users to search for projects that have achieved baseline-1, baseline-2, or baseline-3.

**Note**: This phase should be implemented AFTER all other phases are complete and stable, as it depends on baseline data existing in the database.

### 8.1: Analyze Current Search System

**Current implementation** (from Project model and ProjectsController):

1. **Status filtering**: Projects can be filtered by `status` parameter:
   - `in_progress`: Projects with tiered_percentage < 100
   - `passing`: Projects with tiered_percentage >= 100

2. **Sorting**: Projects can be sorted by various fields including:
   - `achieved_passing_at`, `achieved_silver_at`, `achieved_gold_at`
   - `tiered_percentage`

3. **Scopes** (in `app/models/project.rb` around lines 68-76):

   ```ruby

   scope :in_progress, -> { lteq(99) }
   scope :passing, -> { gteq(100) }

   ```

**Issue**: The current system is tightly coupled to the "metal series" (passing, silver, gold) via the `tiered_percentage` field, which only considers badge_percentage_0, badge_percentage_1, and badge_percentage_2.

### 8.2: Extend ALLOWED_STATUS Values

**File**: `app/controllers/projects_controller.rb`

**Locate** (line 46):

```ruby

ALLOWED_STATUS = %w[in_progress passing].freeze

```

**Replace with**:

```ruby

ALLOWED_STATUS = %w[
  in_progress passing
  baseline_in_progress baseline_achieved
  baseline-1 baseline-2 baseline-3
].freeze

```

**Rationale**: Add new status values for baseline filtering. Users can now filter by specific baseline levels or by any baseline achievement.

### 8.3: Add Baseline Scopes to Project Model

**File**: `app/models/project.rb`

**Add after existing scopes** (after line 76):

```ruby

# Baseline series scopes
# SECURITY NOTE: String-style where clauses below use only literal field names
# (no user input). If adding scopes with user input, use hash-style conditions
# or parameterized queries to prevent SQL injection.

scope :baseline_in_progress, -> {
  where('badge_percentage_baseline_1 < 100 AND achieved_baseline_1_at IS NULL')
}

scope :baseline_achieved, -> {
  where('achieved_baseline_1_at IS NOT NULL OR ' \
        'achieved_baseline_2_at IS NOT NULL OR ' \
        'achieved_baseline_3_at IS NOT NULL')
}

# Preferred hash-style conditions (safer):

scope :baseline_1, -> { where.not(achieved_baseline_1_at: nil) }
scope :baseline_2, -> { where.not(achieved_baseline_2_at: nil) }
scope :baseline_3, -> { where.not(achieved_baseline_3_at: nil) }

```

**Rationale**: Provide scope methods for filtering baseline projects similar to metal series scopes.

### 8.4: Update Project Filtering Logic

**File**: `app/controllers/projects_controller.rb`

**Locate** method `select_data_subset` (search for "def select_data_subset"):

**Add baseline filtering** within the status case statement:

```ruby

def select_data_subset

# ... existing code ...

  if params[:status].present? && ALLOWED_STATUS.include?(params[:status])
    case params[:status]
    when 'in_progress'
      @projects = @projects.in_progress
    when 'passing'
      @projects = @projects.passing
    when 'baseline_in_progress'
      @projects = @projects.baseline_in_progress
    when 'baseline_achieved'
      @projects = @projects.baseline_achieved
    when 'baseline-1'
      @projects = @projects.baseline_1
    when 'baseline-2'
      @projects = @projects.baseline_2
    when 'baseline-3'
      @projects = @projects.baseline_3
    end
  end

# ... rest of method ...

end

```

**Command to find the method**:

```bash

grep -n "def select_data_subset" app/controllers/projects_controller.rb

```

### 8.5: Update ALLOWED_SORT Fields

**File**: `app/controllers/projects_controller.rb`

**Locate** (around lines 38-43):

```ruby

ALLOWED_SORT =
  %w[
    id name tiered_percentage
    achieved_passing_at achieved_silver_at achieved_gold_at
    homepage_url repo_url updated_at user_id created_at
  ].freeze

```

**Replace with**:

```ruby

ALLOWED_SORT =
  %w[
    id name tiered_percentage
    achieved_passing_at achieved_silver_at achieved_gold_at
    achieved_baseline_1_at achieved_baseline_2_at achieved_baseline_3_at
    badge_percentage_baseline_1 badge_percentage_baseline_2 badge_percentage_baseline_3
    homepage_url repo_url updated_at user_id created_at
  ].freeze

```

**Rationale**: Allow sorting by baseline achievement timestamps and percentages.

### 8.6: Update Project Index View

**File**: `app/views/projects/index.html.erb`

**Add baseline filter options** to the status dropdown (find the status filter section):

```erb

<div class="form-group">
  <%= label_tag :status, t('.filter_by_status') %>
  <%= select_tag :status,
      options_for_select([
        [t('.all_projects'), ''],
        [t('.in_progress'), 'in_progress'],
        [t('.passing'), 'passing'],
        ['---', '', disabled: true],
        [t('.baseline_in_progress'), 'baseline_in_progress'],
        [t('.baseline_achieved'), 'baseline_achieved'],
        [t('.baseline_1'), 'baseline-1'],
        [t('.baseline_2'), 'baseline-2'],
        [t('.baseline_3'), 'baseline-3']
      ], params[:status]),
      class: 'form-control' %>
</div>

```

**Command to locate the status filter**:

```bash

grep -n "filter_by_status\|select_tag :status" app/views/projects/index.html.erb

```

### 8.7: Add Baseline Sort Options

**File**: `app/views/projects/index.html.erb`

**Update sort dropdown** to include baseline fields:

```erb

<%= select_tag :sort,
    options_for_select([

# ... existing options ...

      ['---', '', disabled: true],
      [t('.sort_baseline_1_achieved'), 'achieved_baseline_1_at'],
      [t('.sort_baseline_2_achieved'), 'achieved_baseline_2_at'],
      [t('.sort_baseline_3_achieved'), 'achieved_baseline_3_at']
    ], params[:sort]),
    class: 'form-control' %>

```

### 8.8: Update Project Stats

**File**: `app/controllers/project_stats_controller.rb`

**Add methods** for baseline statistics:

```ruby

# GET /project_stats/baseline_1

def baseline_1
  render json: Project.baseline_1.count
end

# GET /project_stats/baseline_2

def baseline_2
  render json: Project.baseline_2.count
end

# GET /project_stats/baseline_3

def baseline_3
  render json: Project.baseline_3.count
end

```

**File**: `config/routes.rb`

**Add routes** (within the scope block, after existing project_stats routes):

```ruby

get '/project_stats/baseline_1', to: 'project_stats#baseline_1',
  as: 'baseline_1_project_stats',
  constraints: ->(req) { req.format == :json }
get '/project_stats/baseline_2', to: 'project_stats#baseline_2',
  as: 'baseline_2_project_stats',
  constraints: ->(req) { req.format == :json }
get '/project_stats/baseline_3', to: 'project_stats#baseline_3',
  as: 'baseline_3_project_stats',
  constraints: ->(req) { req.format == :json }

```

**Verification commands**:

```bash

# Test the new routes

rails routes | grep baseline

# Test in console

rails console
> Project.baseline_1.count
> Project.baseline_achieved.count
exit

```

### 8.9: Update JSON/API Responses

**File**: `app/views/projects/show.json.jbuilder` (or similar)

**Add baseline fields** to project JSON responses:

```ruby

json.baseline_levels do
  json.baseline_1 do
    json.percentage @project.badge_percentage_baseline_1
    json.achieved @project.achieved_baseline_1_at
  end
  json.baseline_2 do
    json.percentage @project.badge_percentage_baseline_2
    json.achieved @project.achieved_baseline_2_at
  end
  json.baseline_3 do
    json.percentage @project.badge_percentage_baseline_3
    json.achieved @project.achieved_baseline_3_at
  end
end

```

**Command to find JSON views**:

```bash

find app/views/projects -name "*.json*"

```

### 8.10: Add Translations for Search UI

**File**: `config/locales/en.yml`

**Add under** `projects.index`:

```yaml

en:
  projects:
    index:
      filter_by_status: "Filter by Status"
      all_projects: "All Projects"
      in_progress: "In Progress (Metal)"
      passing: "Passing (Metal)"
      baseline_in_progress: "Baseline In Progress"
      baseline_achieved: "Any Baseline Achieved"
      baseline_1: "Baseline Level 1"
      baseline_2: "Baseline Level 2"
      baseline_3: "Baseline Level 3"
      sort_baseline_1_achieved: "Baseline 1 Achievement Date"
      sort_baseline_2_achieved: "Baseline 2 Achievement Date"
      sort_baseline_3_achieved: "Baseline 3 Achievement Date"

```

### 8.11: Update Project Statistics Dashboard

**File**: `app/views/project_stats/index.html.erb`

**Add baseline statistics section**:

```erb

<h3><%= t('.baseline_statistics') %></h3>
<div class="row">
  <div class="col-md-4">
    <div class="panel panel-info">
      <div class="panel-heading"><%= t('.baseline_1_count') %></div>
      <div class="panel-body">
        <span id="baseline-1-count">Loading...</span>
      </div>
    </div>
  </div>
  <div class="col-md-4">
    <div class="panel panel-info">
      <div class="panel-heading"><%= t('.baseline_2_count') %></div>
      <div class="panel-body">
        <span id="baseline-2-count">Loading...</span>
      </div>
    </div>
  </div>
  <div class="col-md-4">
    <div class="panel panel-info">
      <div class="panel-heading"><%= t('.baseline_3_count') %></div>
      <div class="panel-body">
        <span id="baseline-3-count">Loading...</span>
      </div>
    </div>
  </div>
</div>

<script>
  // Fetch baseline statistics via AJAX
  fetch('/project_stats/baseline_1', { headers: { 'Accept': 'application/json' } })
    .then(r => r.json())
    .then(data => document.getElementById('baseline-1-count').textContent = data);

  fetch('/project_stats/baseline_2', { headers: { 'Accept': 'application/json' } })
    .then(r => r.json())
    .then(data => document.getElementById('baseline-2-count').textContent = data);

  fetch('/project_stats/baseline_3', { headers: { 'Accept': 'application/json' } })
    .then(r => r.json())
    .then(data => document.getElementById('baseline-3-count').textContent = data);
</script>

```

### 8.12: Add Database Indexes for Search Performance

**New file**: `db/migrate/YYYYMMDDHHMMSS_add_baseline_search_indexes.rb`

```ruby

# frozen_string_literal: true

class AddBaselineSearchIndexes < ActiveRecord::Migration[8.0]
  def change

# Add composite index for common baseline queries

    add_index :projects, [:badge_percentage_baseline_1, :updated_at],
              name: 'index_projects_on_baseline_1_pct_and_updated'

# Indexes for sorting by baseline achievement (if not already added)

# Note: These may already exist from Phase 2/5 migrations

# add_index :projects, :achieved_baseline_1_at (already added in Phase 2)

# add_index :projects, :achieved_baseline_2_at (already added in Phase 5)

# add_index :projects, :achieved_baseline_3_at (already added in Phase 5)

# Composite index for baseline filtering

    add_index :projects,
              [:achieved_baseline_1_at, :achieved_baseline_2_at, :achieved_baseline_3_at],
              name: 'index_projects_on_all_baseline_achievements'
  end
end

```

**Command to generate migration**:

```bash

rails generate migration AddBaselineSearchIndexes

# Then edit the generated file as shown above

```

**Run migration**:

```bash

rails db:migrate

```

### Phase 8 Testing Checklist

- [ ] Can filter projects by baseline_in_progress status
- [ ] Can filter projects by baseline_achieved status
- [ ] Can filter projects by specific baseline levels (1, 2, 3)
- [ ] Can sort projects by baseline achievement dates
- [ ] Can sort projects by baseline percentages
- [ ] Baseline statistics display correctly on stats page
- [ ] JSON responses include baseline data
- [ ] Database indexes improve query performance
- [ ] Translations appear correctly for all filter options
- [ ] URL parameters work correctly (e.g., `?status=baseline-1`)
- [ ] Mixed filters work (e.g., baseline status + text search)
- [ ] No performance regression with additional queries

### Phase 8 Performance Verification

**Commands to test query performance**:

```bash

rails console

# Enable query logging

ActiveRecord::Base.logger = Logger.new(STDOUT)

# Test baseline filter performance

Project.baseline_achieved.limit(10).to_a

# Test sorting performance

Project.baseline_1.order(achieved_baseline_1_at: :desc).limit(10).to_a

# Check that indexes are being used

Project.baseline_1.explain

exit

```

**Expected outcome**: Queries should use indexes and execute in < 100ms for typical database sizes.

---

## Testing Strategy

### Unit Tests

**Files to create/update**:

- `test/models/project_test.rb` - Test baseline badge calculations
- `test/models/criteria_test.rb` - Test baseline criteria loading
- `test/models/badge_test.rb` - Test baseline badge generation

**Key test cases**:

1. Baseline criteria load correctly from YAML
2. Badge percentages calculate correctly
3. Achievement timestamps update appropriately
4. Baseline badge value returns correct level
5. Level normalization works for all formats

### Integration Tests

**Files to create/update**:

- `test/integration/project_get_test.rb` - Test baseline routes
- `test/integration/baseline_badge_test.rb` - Test baseline badge routes

**Key test cases**:

1. Can view baseline-1, baseline-2, baseline-3 pages
2. Can edit baseline criteria
3. Changes save correctly
4. Badge image route works
5. Redirects work for old numeric URLs

### System Tests

**Files to create/update**:

- `test/system/baseline_entry_test.rb` - Test full baseline workflow

**Key test cases**:

1. User can navigate to baseline forms
2. User can fill in baseline criteria
3. User can achieve baseline-1 badge
4. Badge displays correctly
5. Can switch between metal and baseline series

### Performance Tests

**Considerations**:

- Ensure database queries don't explode with additional criteria
- CDN caching works correctly for baseline badges
- Page load times acceptable with larger forms

### Backward Compatibility Tests

**Critical tests**:

1. Old URLs redirect correctly
2. Existing projects load without errors
3. Metal series still works as before
4. No data loss during migration
5. API responses remain compatible

---

## Rollback and Safety

### Database Rollback Plan

Each migration should have a corresponding `down` method:

```ruby

class AddBaseline1Stub < ActiveRecord::Migration[8.0]
  def up

# ... columns added

  end

  def down

# Remove in reverse order

    remove_column :projects, :first_achieved_baseline_1_at
    remove_column :projects, :achieved_baseline_1_at
    remove_column :projects, :baseline_contribution_process_justification
    remove_column :projects, :baseline_contribution_process_status
    remove_column :projects, :baseline_documentation_justification
    remove_column :projects, :baseline_documentation_status
    remove_column :projects, :badge_percentage_baseline_1
  end
end

```

### Feature Flags

Consider adding feature flags for:

- Baseline forms visibility
- Baseline badge generation
- Baseline automation

**Implementation**:

```ruby

# config/initializers/feature_flags.rb

BASELINE_ENABLED = ENV.fetch('BASELINE_ENABLED', 'false') == 'true'
BASELINE_BADGE_ENABLED = ENV.fetch('BASELINE_BADGE_ENABLED', 'false') == 'true'

```

**Usage in views**:

```erb

<% if BASELINE_ENABLED %>
  <%= link_to t('.baseline_1'), project_path(@project, criteria_level: 'baseline-1') %>
<% end %>

```

### Incremental Deployment Strategy

1. **Deploy Phase 1**: URL changes, redirects (low risk)
2. **Monitor**: Check redirect logs, error rates
3. **Deploy Phase 2**: Database schema, stub criteria
4. **Monitor**: Check database performance, no errors
5. **Deploy Phase 3**: Full baseline-1 forms
6. **Monitor**: User engagement, form submissions
7. **Deploy Phase 4**: Baseline badges
8. **Monitor**: Badge generation, CDN performance
9. **Deploy Phases 5-7**: Remaining levels, automation, translations

### Monitoring

**Metrics to track**:

- Error rates for baseline routes
- Badge generation success rate
- Form submission rates for baseline
- Database query performance
- CDN cache hit rates for baseline badges
- User engagement with baseline vs metal

### Emergency Rollback Procedure

If critical issues arise:

1. **Disable feature flag**: Set `BASELINE_ENABLED=false`
2. **Revert routes**: Remove baseline from `VALID_CRITERIA_LEVEL`
3. **Database**: Keep columns (don't drop data), but stop using them
4. **Monitor**: Ensure metal series works correctly
5. **Debug**: Fix issues in staging environment
6. **Re-deploy**: Once fixed, re-enable carefully

---

## Implementation Order Summary

### Recommended Incremental Approach

**Week 1-2**: Phase 1 (URL Migration)

- Low risk, foundational changes
- Can deploy and test thoroughly before adding baseline

**Week 3-4**: Phase 2 (Baseline-1 Stub)

- Add database support
- Load 2-3 criteria for testing
- Validate architecture works

**Week 5-7**: Phase 3 (Full Baseline-1)

- Complete baseline-1 criteria
- Full forms and editing
- Thorough testing

**Week 8**: Phase 4 (Baseline Badges)

- Badge generation
- CDN setup
- Badge display

**Week 9-11**: Phase 5 (Baseline-2 and 3)

- Repeat process for remaining levels
- Can be done in parallel by multiple developers

**Week 15-18**: Phase 6 (Translations)

- Machine translations
- Human review
- Ongoing process

**Week 12-14**: Phase 7 (Automation)

- Autofill logic
- Automated suggestions
- Refinement based on user feedback

**Week 19-21**: Phase 8 (Search and Filtering)

- Add baseline filtering to project search
- Update project statistics
- Add database indexes
- **Only after phases 1-7 are stable**

---

## Files Reference

### Files to Create

1. `criteria/baseline_criteria.yml` - Baseline criteria definitions
2. `app/views/projects/_form_baseline-1.html.erb` - Baseline-1 form
3. `app/views/projects/_form_baseline-2.html.erb` - Baseline-2 form
4. `app/views/projects/_form_baseline-3.html.erb` - Baseline-3 form
5. `app/views/projects/_form_permissions.html.erb` - Permissions form
6. `app/assets/images/badge_baseline_*.svg` - Baseline badge images
7. `docs/baseline_criteria_mapping.md` - Criteria to field mapping
8. `docs/baseline_automation.md` - Automation strategy
9. `db/migrate/*_add_baseline_1_stub.rb` - Initial baseline migration
10. `db/migrate/*_add_baseline_1_full.rb` - Full baseline-1 migration
11. `db/migrate/*_add_baseline_2.rb` - Baseline-2 migration
12. `db/migrate/*_add_baseline_3.rb` - Baseline-3 migration
13. `db/migrate/*_add_baseline_search_indexes.rb` - Search performance indexes
14. `test/integration/baseline_badge_test.rb` - Baseline badge tests
15. `test/system/baseline_entry_test.rb` - Baseline system tests

### Files to Modify

1. `config/routes.rb` - Add baseline routes, redirects, stats routes
2. `app/models/project.rb` - Add baseline methods, constants, scopes
3. `app/models/criteria.rb` - Add helper methods for level conversion
4. `app/models/badge.rb` - Support baseline badges
5. `app/controllers/projects_controller.rb` - Handle baseline levels, filtering
6. `app/controllers/criteria_controller.rb` - Handle baseline levels
7. `app/controllers/project_stats_controller.rb` - Add baseline statistics
8. `app/helpers/projects_helper.rb` - Helper methods for baseline
9. `app/views/projects/show.html.erb` - Display baseline info
10. `app/views/projects/index.html.erb` - Add baseline filters
11. `app/views/project_stats/index.html.erb` - Add baseline statistics
12. `app/views/projects/_form_0.html.erb` - REMOVE ownership transfer and additional_rights sections
13. `app/views/projects/_form_1.html.erb` - REMOVE ownership transfer and additional_rights sections (if present)
14. `app/views/projects/_form_2.html.erb` - REMOVE ownership transfer and additional_rights sections (if present)
15. `app/views/projects/_form_permissions.html.erb` - CREATE new form with ownership + collaborator management
16. `app/mailers/project_mailer.rb` - Update links to use `/permissions/edit` for permission changes
17. `criteria/criteria.yml` - NO CHANGES (keys stay as '0', '1', '2' for translation compatibility)
18. `config/initializers/criteria_hash.rb` - Support loading multiple criteria files
19. `config/locales/en.yml` - Add baseline translations
20. `config/locales/translation.*.yml` - Add baseline translations (all languages)
21. `test/models/project_test.rb` - Add baseline tests
22. `test/controllers/projects_controller_test.rb` - Add baseline tests
23. `test/integration/project_get_test.rb` - Add baseline route tests

### Note on View Template Files

**DO NOT rename** `_form_0.html.erb`, `_form_1.html.erb`, `_form_2.html.erb` - these files stay as-is because `@criteria_level` will contain internal level IDs ('0', '1', '2'), not URL-friendly names.

---

## Lessons from Code Review

This section documents critical insights learned from comparing the plan to the actual codebase.

### 1. Database Field Names MUST Stay Numeric

**Why**: The codebase extensively uses `badge_percentage_#{level}` pattern where `level` is '0', '1', or '2'. Changing these would require:

- Updating 50+ references across models, controllers, views
- Migrating data to renamed columns (risky)
- Updating JavaScript that constructs field names

**Solution**: Keep numeric suffixes for metal series (_0, _1, _2) and use descriptive names for baseline (_baseline_1, _baseline_2, _baseline_3).

### 2. Three-Layer Architecture Requires Careful Mapping

**Layers identified**:

1. **URL/Route**: User-facing names (passing, silver, gold, baseline-1)
2. **Data/Internal**: Internal level IDs ('0', '1', '2', 'baseline-1') used for:
   - YAML criteria keys in `criteria/criteria.yml`
   - I18n translation keys (`criteria.0.*`, `criteria.1.*`, etc.)
   - Internal logic and comparisons
3. **Database**: Field suffixes (_0, _1, _2, _baseline_1)

**CRITICAL**: YAML keys and I18n translation keys MUST stay as `'0'`, `'1'`, `'2'` for the metal series to preserve compatibility with externally-maintained translations.

**Key insight**: Changing YAML keys from '0' to 'passing' would change all I18n translation keys from `criteria.0.criterion_name.description` to `criteria.passing.criterion_name.description`, breaking externally-maintained translations.

**Critical methods** that need updates:

- `normalize_criteria_level`: Converts URL names → internal level IDs (e.g., 'passing' → '0')
- `badge_percentage_field`: Maps level IDs → database field symbols
- Controller methods: Accept URL params, convert to internal IDs before use

### 3. LEVEL_IDS Cannot Change

**Current**: `LEVEL_IDS = ['0', '1', '2']` (strings)

**Why it can't change**:

```ruby

Project::LEVEL_IDS.each do |level|
  update_badge_percentage(level, current_time)
end

def update_badge_percentage(level, current_time)
  self[:"badge_percentage_#{level}"] = calculate_badge_percentage(level)
end

```

Changing LEVEL_IDS would break `badge_percentage_#{level}` field access.

**Solution**: Keep LEVEL_IDS as-is, add separate constants for baseline levels.

### 4. Route-Level Redirects for Performance

**Requirement**: Project data requests must be processed quickly with minimal memory use.

**Why route-level redirects**:

```ruby

# In routes.rb - FAST, minimal memory

get '/:locale/projects/:id/0', to: redirect('/%{locale}/projects/%{id}/passing', status: 301)

# vs in controller - SLOW, loads full Rails stack

def show
  redirect_to(...) if params[:criteria_level] == '0'  # Too late, already loaded everything
end

```

**Performance benefits**:

- Route-level redirects execute **before** controller instantiation
- No ActiveRecord models loaded
- No session processing
- No CSRF token verification
- Response sent directly from routing layer
- **Minimal memory footprint** (<1MB vs 50MB+ for full Rails request)

**Common synonyms support**:

- Users commonly request "bronze" instead of "passing"
- Single-hop redirect: `/projects/123/bronze` → `/projects/123/passing` (301)
- NOT chained: `/projects/123/bronze` → `/projects/123/0` → `/projects/123/passing` ❌
- Controller also handles bronze via `normalize_criteria_level` (defense in depth)

**Solution**: Use route-level redirects for ALL legacy/synonym URLs. Keep controller normalization for edge cases.

### 5. Views Have Hardcoded Level References

**Found in** `app/views/projects/_form_early.html.erb`:

```erb

?criteria_level=1
?criteria_level=2

```

**Must update** these to use named parameters or they'll break with new routing.

### 6. JavaScript Needs Compatibility

**File**: `app/assets/javascripts/project-form.js`

Parses `criteria_level` from URL. Current implementation is generic enough, but verify no hardcoded checks exist.

### 7. BADGE_PROJECT_FIELDS Needs Baseline Columns

**Critical for performance**: The badge route uses:

```ruby

Project.select(BADGE_PROJECT_FIELDS).find(params[:id])

```

Must add baseline fields to this constant or baseline badge route will fail.

### 8. Tests Use Numeric Levels Extensively

**Pattern found**:

```ruby

get "/en/projects/#{@project.id}?criteria_level=2"

```

Tests need updates to use named levels, plus new tests for redirect behavior.

### 9. Translation Keys Should NOT Have Dual Support

**IMPORTANT CORRECTION**: After reviewing translation compatibility:

- Translation keys should remain **numeric only**: `projects.form_early.level.0` (not changing)
- Do NOT add new keys like `projects.form_early.level.passing`
- Changing translation keys would break externally-maintained translations
- URLs change, but translation keys stay the same

### 10. The Criteria.active Method is Central

```ruby

def calculate_badge_percentage(level)
  active = Criteria.active(level)
  met = active.count { |criterion| enough?(criterion) }
  to_percentage met, active.size
end

```

`Criteria.active(level)` must accept:

- Numeric strings: '0', '1', '2' (internal level IDs after normalize_criteria_level conversion)
- Baseline strings: 'baseline-1', 'baseline-2', 'baseline-3'

**Note**: Controllers convert URL params ('passing', 'bronze', 'silver', 'gold') to internal IDs ('0', '1', '2') before calling `Criteria.active`, so this method doesn't need to handle URL-friendly names directly.

### 11. Model Validations Auto-Generate from Criteria

**Pattern in Project model**:

```ruby

Criteria.each_value do |criteria|
  criteria.each_value do |criterion|
    validates criterion.name.status, inclusion: { in: STATUS_CHOICE }
    validates criterion.name.justification, length: { maximum: MAX_TEXT_LENGTH }
  end
end

```

This automatically picks up new baseline criteria once loaded into Criteria class. No manual updates needed.

### 12. CDN Caching is Critical

Badge routes must have:

- No locale (single canonical URL)
- Surrogate key headers for cache invalidation
- Minimal database queries (via SELECT specific fields)

Baseline badge route must follow same pattern.

### 13. Incremental Migration is Non-Optional

**Cannot do**:

- Big bang migration of all URLs at once
- Breaking backward compatibility
- Changing database schema without careful testing

**Must do**:

- Permanent redirects (301) from old to new URLs
- Support both formats during transition
- Monitor error rates after each phase
- Test with real traffic before proceeding

---

## Conclusion

This detailed plan provides a comprehensive, incremental approach to implementing baseline support. Key principles:

1. **Incremental**: Each phase can be deployed and tested independently
2. **Backward compatible**: Old URLs redirect, no data loss
3. **Obviously correct**: Clear separation between metal and baseline series
4. **Testable**: Comprehensive testing at each phase
5. **Rollback-friendly**: Each phase can be disabled or reverted if needed
6. **Maintainable**: Clear naming conventions and documentation

The implementation will take approximately 19-21 weeks with proper testing and refinement, but can be accelerated with multiple developers working in parallel on different phases (particularly Phases 5, 6, and 7).

### Critical Success Factors

1. **Phase 1 must be rock-solid** before proceeding - URL changes affect all existing links
2. **Phase 2 validates the architecture** - don't rush to Phase 3 until convinced it works
3. **Complete testing at each phase** - catching issues early saves time later
4. **Monitor performance** throughout - baseline adds significant database columns
5. **Engage translators early** (Phase 6) - translation is time-consuming
6. **Phase 8 is optional but recommended** - search is valuable but can wait if needed

### Next Steps

1. Review this plan with the development team
2. Verify access to OpenSSF Baseline criteria source and test sync system (Phase 2)
3. Coordinate with translation team about workload (Phase 6)
4. Set up feature flags for safe deployment
5. Create tracking issues for each phase
6. Begin Phase 1 implementation

### Ongoing Maintenance

Once baseline support is implemented, maintain criteria synchronization:

**Regular Sync Schedule**:

```bash

# Run monthly or when OpenSSF Baseline publishes updates

rake baseline:sync

# Review changes

git diff criteria/baseline_criteria.yml config/baseline_field_mapping.json

# Generate migrations for any new criteria

rake baseline:generate_migration

# Review and run migrations

rails db:migrate

# Commit changes

git add criteria/baseline_criteria.yml config/baseline_field_mapping.json db/migrate/
git commit -m "Update baseline criteria to version YYYY-MM-DD"

```

**Monitor for Baseline Updates**:

- Subscribe to OpenSSF Baseline announcements
- Check https://baseline.openssf.org/versions/ for new versions
- Test sync system on staging before production

**Handle Deprecated Criteria**:
If OpenSSF deprecates or removes criteria, the sync system will:

1. Keep existing database fields (never drop data)
2. Mark criteria as deprecated in YAML metadata
3. Hide from new projects but preserve for existing projects
