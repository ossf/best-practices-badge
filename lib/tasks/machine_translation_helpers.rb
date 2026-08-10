# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require_relative 'translation_instructions_template'

# Helper methods for machine translation rake tasks.
# Extracted to a module to keep rake tasks clean and testable.
#
# Metrics cops disabled: this is a rake task helper module where slightly
# longer methods improve readability over excessive decomposition.
# rubocop:disable Rails/Output, Metrics/ModuleLength, Metrics/ClassLength
# rubocop:disable Metrics/AbcSize, Metrics/MethodLength
module MachineTranslationHelpers
  # Languages in priority order:
  # French first (reviewer knows some), then German, Japanese, Chinese,
  # Portuguese, Spanish, Russian, and Swahili last (limited LLM support)
  TRANSLATION_PRIORITY = %w[fr de ja zh-CN pt-BR es ru sw].freeze

  # Keys to exclude from translation (test keys, internal-only, etc.)
  KEYS_TO_IGNORE = %w[
    do_not_translate_this
    test_pluralization_only_one.one
  ].freeze

  # Human-readable language names for prompts
  LANGUAGE_NAMES = {
    'fr' => 'French', 'de' => 'German', 'ja' => 'Japanese',
    'zh-CN' => 'Simplified Chinese', 'pt-BR' => 'Brazilian Portuguese',
    'es' => 'Spanish', 'ru' => 'Russian', 'sw' => 'Swahili'
  }.freeze

  # Default batch size for Copilot translations (balance speed vs accuracy)
  COPILOT_BATCH_SIZE = 20

  # Translation example counts for consistency and quality
  MIN_TRANSLATION_EXAMPLES = 20 # Minimum examples to provide (if available)
  MAX_TRANSLATION_EXAMPLES = 30 # Maximum examples to avoid overwhelming

  class << self
    def validate_locale!(locale)
      return if I18n.available_locales.map(&:to_s).include?(locale)

      raise ArgumentError,
            "Invalid locale: #{locale}. Available: #{I18n.available_locales.join(', ')}"
    end

    def machine_translation_path(locale)
      Rails.root.join('config', 'machine_translations', "#{locale}.yml")
    end

    def source_tracking_path(locale)
      Rails.root.join('config', 'machine_translations', "src_en_#{locale}.yml")
    end

    def find_untranslated_keys(locale)
      english = load_flat_translations('en')
      translated = load_flat_translations(locale)
      human_translated = load_flat_translations(locale, human_only: true)
      source_tracking = load_source_tracking(locale)

      english.keys.select do |key|
        # Skip test/internal keys that should never be translated
        next false if KEYS_TO_IGNORE.include?(key)

        english_value = english[key]

        # Skip keys where English value is blank - nothing to translate
        next false if english_value.nil? || english_value.to_s.strip.empty?

        value = translated[key]
        # Key is untranslated if:
        # 1. No translation exists or is empty, OR
        # 2. English source has changed since machine translation (and no human translation)
        next true if value.nil? || value.to_s.strip.empty?
        next false if human_translated.key?(key) # Has human translation - ignore source changes

        # Check if English source has changed since machine translation
        source_tracking.key?(key) && source_tracking[key] != english_value
      end
    end

    def next_locale_needing_translation
      TRANSLATION_PRIORITY.find do |locale|
        find_untranslated_keys(locale).any?
      end || TRANSLATION_PRIORITY.first
    end

    def export_keys_for_translation(locale, keys)
      english = load_flat_translations('en')
      # Export English text under 'en' key (source language)
      # Translator will change 'en' to target locale and translate values
      output = { 'en' => {} }

      keys.each do |key|
        set_nested_key(output['en'], key, english[key])
      end

      timestamp = Time.zone.now.strftime('%Y%m%d_%H%M%S')
      filename = "translate_to_#{locale}_#{timestamp}.yml"
      filepath = Rails.root.join('tmp', filename)
      File.write(filepath, yaml_dump(output))

      result = { filepath: filepath, timestamp: timestamp, keys: keys, locale: locale }

      # Always generate translation examples for consistency (helps both AI and humans)
      examples = generate_translation_examples_files(locale, keys, english, timestamp)
      result[:examples] = examples if examples

      # Generate comprehensive instructions file for translators
      instructions_file = generate_translation_instructions(locale, timestamp, examples)
      result[:instructions] = instructions_file

      result
    end

    # Generate example translation files showing how technical terms were translated
    # Returns hash with file paths and metadata, or nil if no examples available
    def generate_translation_examples_files(locale, keys_to_translate, english, timestamp)
      # Find technical terms in the text to be translated
      technical_terms = extract_technical_terms(keys_to_translate, english)

      # Find existing translations containing these terms
      example_keys = []
      example_keys = find_example_translations(locale, technical_terms, english) if technical_terms.any?

      # Try to add general style examples (target MIN-MAX, but use what we have)
      if example_keys.length < MIN_TRANSLATION_EXAMPLES
        general_examples = find_general_style_examples(locale, english, exclude: example_keys)
        needed = MIN_TRANSLATION_EXAMPLES - example_keys.length
        example_keys += general_examples.take(needed)
      end

      # Return nil if we have no examples at all
      return if example_keys.empty?

      # Limit to maximum to avoid overwhelming
      example_keys = example_keys.take(MAX_TRANSLATION_EXAMPLES)

      tmp_dir = Rails.root.join('tmp')

      # Create example source file (English)
      example_source = { 'en' => {} }
      example_keys.each { |key| set_nested_key(example_source['en'], key, english[key]) }
      example_source_name = "examples_en_#{locale}_#{timestamp}.yml"
      en_filepath = tmp_dir.join(example_source_name)
      File.write(en_filepath, yaml_dump(example_source))

      # Create example target file (existing translations)
      existing_translations = load_flat_translations(locale)
      example_target = { locale => {} }
      example_keys.each do |key|
        set_nested_key(example_target[locale], key, existing_translations[key])
      end
      example_target_name = "examples_#{locale}_#{timestamp}.yml"
      locale_filepath = tmp_dir.join(example_target_name)
      File.write(locale_filepath, yaml_dump(example_target))

      puts "Generated #{example_keys.length} translation examples for #{language_name(locale)}"
      {
        en_filepath: en_filepath,
        locale_filepath: locale_filepath,
        source_name: example_source_name,
        target_name: example_target_name,
        term_count: technical_terms.length,
        example_count: example_keys.length
      }
    end

    # Generate translation instructions file (uses template)
    # Only writes if file doesn't exist or content changed (preserves mtime for caching)
    def generate_translation_instructions(locale, _timestamp, examples)
      instructions_file = Rails.root.join('tmp', "TRANSLATION_INSTRUCTIONS_#{locale}.txt")
      instructions = TranslationInstructionsTemplate.generate(
        locale: locale,
        lang: language_name(locale),
        examples: examples
      )

      # Only write if file doesn't exist or content differs
      if !File.exist?(instructions_file) || File.read(instructions_file) != instructions
        File.write(instructions_file, instructions)
      end

      instructions_file
    end

    def print_export_instructions(locale, filepath, examples = nil, instructions = nil)
      lang = language_name(locale)

      puts '=' * 80
      puts "TRANSLATION TASK: English → #{lang} (#{locale})"
      puts '=' * 80
      puts ''
      puts 'FILE TO TRANSLATE:'
      puts "  #{filepath}"
      puts ''
      puts 'REQUIRED FORMAT:'
      puts "  Root key must be: #{locale}:"
      puts "  (The file currently has 'en:' - change it to '#{locale}:')"
      puts ''
      puts 'STEPS:'
      puts "  1. Change root key from 'en:' to '#{locale}:'"
      puts "  2. Translate all English VALUES to #{lang}"
      puts '  3. Keep all KEYS unchanged (in English)'
      puts '  4. Preserve ALL placeholders like %<variable>s EXACTLY'
      puts "  5. Import: rake translation:import[#{locale},#{filepath}]"
      puts ''

      if examples
        puts 'TRANSLATION EXAMPLES PROVIDED:'
        puts "  English:  #{examples[:en_filepath]}"
        puts "            ↑ Has 'en:' root key with English values"
        puts "  #{lang}: #{examples[:locale_filepath]}"
        puts "            ↑ Has '#{locale}:' root key with #{lang} values"
        puts "  (#{examples[:example_count]} examples showing correct format, style, and terminology)"
        puts ''
      end

      if instructions
        puts 'DETAILED INSTRUCTIONS:'
        puts "  #{instructions}"
        puts ''
      end

      puts 'CRITICAL RULES:'
      puts "  • Root key MUST be '#{locale}:' (not 'en:')"
      puts '  • Translate ONLY values, NEVER keys'
      puts '  • Keep %<name>s, %<count>s placeholders EXACTLY'
      puts '  • Keep HTML tags like <a>, <em>, <strong> unchanged'
      puts '  • Same YAML structure (indentation, nesting)'
      puts ''
      puts '=' * 80
    end

    # Import translated YAML file with validation and source tracking
    # Returns count of imported keys on success, false on failure
    # Automatically repairs common YAML formatting issues (helps both AI and humans)
    # rubocop:disable Naming/PredicateName
    def import_translations(locale, file, expected_keys: nil)
      # Handle both string paths and Pathname objects
      filepath = Pathname.new(file).absolute? ? Pathname.new(file) : Rails.root.join(file)

      unless File.exist?(filepath)
        puts "File not found: #{filepath}"
        return false
      end

      # Load YAML with automatic repair for common issues
      translated = load_yaml_with_fallback(filepath, locale)
      return false unless translated

      unless translated.is_a?(Hash) && translated[locale].is_a?(Hash)
        puts "Invalid YAML structure. Expected: { '#{locale}' => { ... } }"
        return false
      end

      # Write back repaired YAML if it was fixed
      File.write(filepath, yaml_dump(translated))

      # Always validate against English keys
      english = load_flat_translations('en')
      validation_keys = expected_keys || english.keys
      translated[locale] = validate_and_filter_keys(
        translated[locale], validation_keys, locale
      )

      if translated[locale].empty?
        puts 'No valid keys to import after validation'
        return false
      end

      existing = load_existing_machine_translations(locale)
      deep_merge!(existing[locale], translated[locale])

      machine_file = machine_translation_path(locale)
      File.write(machine_file, yaml_dump(existing))
      imported_count = count_keys(translated[locale])
      puts "Imported #{imported_count} keys to #{machine_file}"

      # Always track source English text for stale translation detection
      update_source_tracking(locale, translated[locale])

      imported_count
    end

    def cleanup_machine_translations
      cleaned_total = 0

      TRANSLATION_PRIORITY.each do |locale|
        cleaned = cleanup_locale(locale)
        cleaned_total += cleaned
      end

      puts "Total cleaned: #{cleaned_total} keys"
    end

    def print_status
      english = load_flat_translations('en')
      # Only count English keys that have non-blank values (actually need translation)
      translatable_keys =
        english.keys.select do |key|
          value = english[key]
          !value.nil? && !value.to_s.strip.empty? && !KEYS_TO_IGNORE.include?(key)
        end

      # Collect per-locale stats first, then display in two passes
      locale_stats =
        TRANSLATION_PRIORITY.map do |locale|
          compute_locale_status(locale, translatable_keys)
        end

      # Pass 1: summary table
      puts 'Translation Status:'
      puts '-' * 60
      locale_stats.each do |stats|
        puts format(
          '%-8<loc>s Human: %4<human>d  Machine: %4<machine>d  Missing: %4<miss>d',
          loc: stats[:locale], human: stats[:human_count],
          machine: stats[:machine_only_count], miss: stats[:missing_keys].length
        )
      end

      # Pass 2: sample missing keys
      locales_with_missing = locale_stats.select { |s| s[:missing_keys].any? }
      return if locales_with_missing.empty?

      puts ''
      puts 'Sample missing keys (up to 10 per locale):'
      puts '-' * 60
      locales_with_missing.each do |stats|
        puts "#{stats[:locale]}:"
        stats[:missing_keys].first(10).each { |key| puts "  #{key}" }
        remaining = stats[:missing_keys].length - 10
        puts "  ... (#{remaining} more)" if remaining.positive?
      end
    end

    # Copilot integration methods

    def copilot_lock_path
      Rails.root.join('tmp', 'copilot_translation.lock')
    end

    # rubocop:disable Naming/PredicateMethod
    def acquire_copilot_lock
      lockfile = copilot_lock_path

      # Check if lock exists and handle stale locks
      if File.exist?(lockfile)
        age = Time.zone.now - File.mtime(lockfile)
        return false if age <= 1800 # Lock is fresh (< 30 minutes)

        puts "Removing stale lock (#{(age / 60).round} minutes old)"
        FileUtils.rm_f(lockfile)
      end

      File.write(lockfile, "#{Process.pid}\n#{Time.zone.now.iso8601}")
      true
    end
    # rubocop:enable Naming/PredicateMethod

    def release_copilot_lock
      FileUtils.rm_f(copilot_lock_path)
    end

    def language_name(locale)
      LANGUAGE_NAMES[locale] || locale
    end

    # Print file contents with a description header for debugging/insight
    # @param description [String] what this file contains
    # @param filename [String, Pathname] path to the file to print
    def print_file(description, filename)
      puts "+++ #{description} #{filename}"
      puts File.read(filename)
      puts
    end

    # Copilot-specific: Create empty target file for Copilot to fill
    # Copilot needs an empty structure showing what keys to translate
    def export_for_copilot(locale, keys)
      # Use generic export which creates source file and examples
      export_result = export_keys_for_translation(locale, keys)

      # Create empty target file with just the key structure for Copilot
      tmp_dir = Rails.root.join('tmp')
      timestamp = export_result[:timestamp]
      target_output = { locale => {} }
      keys.each { |key| set_nested_key(target_output[locale], key, '') }
      target_name = "copilot_target_#{locale}_#{timestamp}.yml"
      target_file = tmp_dir.join(target_name)
      File.write(target_file, yaml_dump(target_output))

      # Return combined result for Copilot
      {
        source: export_result[:filepath],         # Source English text
        target: target_file,                      # Empty target structure
        source_name: File.basename(export_result[:filepath]),
        target_name: target_name,
        instructions: export_result[:instructions], # Instructions file
        instructions_name: File.basename(export_result[:instructions]),
        examples: export_result[:examples], # May be nil
        timestamp: timestamp,
        keys: keys
      }
    end

    # Extract technical terms from English text that should use consistent translation
    def extract_technical_terms(keys, english)
      terms = Set.new
      keys.each do |key|
        text = english[key].to_s
        next if text.empty?

        # Pattern 1: Acronyms (2+ consecutive capitals, possibly with slashes)
        text.scan(%r{\b[A-Z]{2,}(?:/[A-Z]+)*\b}) { |match| terms << match }

        # Pattern 2: Proper nouns (capitalized words, excluding sentence starts)
        text.scan(/(?<!^|\. )\b[A-Z][a-z]+(?:[A-Z][a-z]+)*\b/) { |match| terms << match }

        # Pattern 3: Technical compounds (hyphenated terms)
        text.scan(/\b[a-z]+-[a-z]+(?:-[a-z]+)*\b/i) { |match| terms << match }

        # Pattern 4: Long technical words (12+ characters)
        text.scan(/\b[a-z]{12,}\b/i) { |match| terms << match }
      end
      terms.to_a
    end

    # Find existing translations that contain the technical terms
    def find_example_translations(locale, terms, english)
      return [] if terms.empty?

      existing_translations = load_flat_translations(locale)
      human_translations = load_flat_translations(locale, human_only: true)

      example_keys = []
      terms.each do |term|
        # Find keys where English contains this term
        matching_keys =
          english.keys.select do |key|
            text = english[key].to_s
            text.include?(term) && human_translations.key?(key) &&
              !existing_translations[key].to_s.strip.empty?
          end

        # Add first match for this term (if any)
        example_keys << matching_keys.first if matching_keys.any?
      end

      example_keys.compact.uniq
    end

    # Find general style examples from existing human translations
    # Prefers shorter, clearer examples that demonstrate style
    # Excludes keys already in the exclude list
    def find_general_style_examples(locale, english, exclude: [])
      human_translations = load_flat_translations(locale, human_only: true)
      existing_translations = load_flat_translations(locale)

      # Get all available human translation keys
      available_keys =
        human_translations.keys.reject do |key|
          exclude.include?(key) || existing_translations[key].to_s.strip.empty?
        end

      # Sort by text length (prefer shorter, clearer examples)
      # but prioritize those with common patterns (buttons, labels, messages)
      available_keys.sort_by do |key|
        text = english[key].to_s
        length = text.length

        # Boost priority for common UI patterns (lower score = higher priority)
        priority_boost = 0
        priority_boost -= 500 if key.match?(/\.(name|title|label|button|link|submit|header)$/)
        priority_boost -= 300 if key.match?(/\.(description|help|message|notice)$/)
        priority_boost -= 200 if text.include?('%{') # Has placeholders - good for learning

        length + priority_boost
      end
    end

    # Copilot-specific: Build prompt that references the instructions file
    def build_copilot_prompt(locale, source_name, target_name, instructions_name)
      lang = language_name(locale)

      <<~PROMPT
        You are a professional translator for the OpenSSF Best Practices Badge web application.

        TASK: Translate the English YAML file #{source_name} into #{lang}.

        INPUT FILE: #{source_name} (English text with 'en:' root key - DO NOT MODIFY)
        OUTPUT FILE: #{target_name} (write #{lang} translations here with '#{locale}:' root key)

        CRITICAL YAML RULES:
        1. ALWAYS wrap ALL values in double quotes
        2. ESCAPE internal double quotes as \\" (e.g., "The \\"term\\" means...")
        - Correct:   key: "translated text here"
        - WRONG:     key: translated text here
        - Correct:   key: "The \\"term\\" means..."
        - WRONG:     key: "The "term" means..."  (unescaped quotes BREAK YAML!)

        INSTRUCTIONS: Read #{instructions_name} for complete translation guidelines.
        Your translation will be automatically validated. Any errors cause REJECTION.

        WORKFLOW:
        1. Read #{source_name} to get the English text
        2. Read #{instructions_name} for formatting rules and examples
        3. Write your #{lang} translations to #{target_name}
        4. The output file must have '#{locale}:' as the root key (not 'en:')
        5. ENSURE every value is wrapped in double quotes

        After completing the translation, output ONLY the text "TRANSLATION_COMPLETE" on a line by itself.
      PROMPT
    end

    def run_copilot_translation(locale, batch_size: COPILOT_BATCH_SIZE)
      missing_keys = find_untranslated_keys(locale)
      if missing_keys.empty?
        puts "No untranslated keys for #{locale}!"
        return { success: true, translated: 0, locale: locale }
      end

      keys_to_translate = missing_keys.first(batch_size)
      puts "Translating #{keys_to_translate.length} keys to #{language_name(locale)}..."

      files = export_for_copilot(locale, keys_to_translate)
      # Use basenames in prompt (copilot runs from tmp/ directory)
      prompt = build_copilot_prompt(
        locale,
        files[:source_name],
        files[:target_name],
        files[:instructions_name]
      )
      prompt_file = Rails.root.join('tmp', "copilot_prompt_#{locale}_#{files[:timestamp]}.txt")
      File.write(prompt_file, prompt)

      # Print all inputs for insight into copilot translation
      if files[:examples]
        print_file('Sample English translations (YAML)', files[:examples][:en_filepath])
        print_file("Sample #{language_name(locale)} translations (YAML)",
                   files[:examples][:locale_filepath])
      end
      print_file('English to translate (YAML)', files[:source])
      print_file('Translation instructions', files[:instructions])

      copilot_success = execute_copilot(prompt, files[:target])

      # Print resulting translation for insight
      if File.exist?(files[:target])
        print_file("Resulting #{language_name(locale)} translation (YAML)", files[:target])
      end

      # Try to import translations even if copilot had issues - use what we can
      imported_count = false
      if copilot_success && File.exist?(files[:target])
        imported_count = import_translations(locale, files[:target], expected_keys: keys_to_translate)
      end

      # Accept partial success - if we imported any translations, count it as success
      if imported_count && imported_count > 0
        if imported_count < keys_to_translate.length
          puts "Partial success: imported #{imported_count}/#{keys_to_translate.length} translations"
        end
        { success: true, translated: imported_count, locale: locale }
      else
        puts 'Translation failed completely. Files preserved for debugging:'
        puts "  Source: #{files[:source]}"
        puts "  Target: #{files[:target]}"
        puts "  Prompt: #{prompt_file}"
        { success: false, translated: 0, locale: locale }
      end
    end

    private

    # Partition translatable keys into human, machine-only, and missing.
    # Returns a hash with counts and the list of missing keys.
    def compute_locale_status(locale, translatable_keys)
      human = load_flat_translations(locale, human_only: true)
      machine = load_flat_translations(locale, machine_only: true)

      human_count = 0
      machine_only_count = 0
      missing_keys = []

      translatable_keys.each do |key|
        if non_empty_value?(human[key])
          human_count += 1
        elsif non_empty_value?(machine[key])
          machine_only_count += 1
        else
          missing_keys << key
        end
      end

      {
        locale: locale, human_count: human_count,
        machine_only_count: machine_only_count, missing_keys: missing_keys
      }
    end

    def non_empty_value?(value)
      !value.nil? && !value.to_s.strip.empty?
    end

    def load_flat_translations(locale, human_only: false, machine_only: false)
      result = {}

      load_human_translations_into(result, locale) unless machine_only
      load_machine_translations_into(result, locale) unless human_only
      load_english_if_needed(result, locale)

      result
    end

    def load_human_translations_into(result, locale)
      Rails.root.glob("config/locales/*.#{locale}.yml").each do |file|
        merge_flat!(result, YAML.load_file(file)&.dig(locale) || {})
      end

      translation_file = Rails.root.join('config', 'locales', "translation.#{locale}.yml")
      return unless File.exist?(translation_file)

      merge_flat!(result, YAML.load_file(translation_file)&.dig(locale) || {})
    end

    def load_machine_translations_into(result, locale)
      machine_file = machine_translation_path(locale)
      return unless File.exist?(machine_file)

      merge_flat!(result, YAML.load_file(machine_file)&.dig(locale) || {})
    end

    def load_english_if_needed(result, locale)
      return unless locale == 'en'

      en_file = Rails.root.join('config', 'locales', 'en.yml')
      return unless File.exist?(en_file)

      merge_flat!(result, YAML.load_file(en_file)&.dig('en') || {})
    end

    def load_existing_machine_translations(locale)
      machine_file = machine_translation_path(locale)
      existing = File.exist?(machine_file) ? YAML.load_file(machine_file) : {}
      existing ||= {}
      existing[locale] ||= {}
      existing
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    def cleanup_locale(locale)
      machine_file = machine_translation_path(locale)
      source_file = source_tracking_path(locale)
      return 0 unless File.exist?(machine_file)

      machine = YAML.load_file(machine_file)
      return 0 unless machine&.dig(locale)

      human = load_flat_translations(locale, human_only: true)
      original_count = count_keys(machine[locale])

      remove_keys_present_in!(machine[locale], human)

      new_count = count_keys(machine[locale])
      cleaned = original_count - new_count

      if cleaned.positive?
        File.write(machine_file, yaml_dump(machine))
        puts "#{locale}: Removed #{cleaned} keys (now #{new_count} machine translations)"

        # Also clean up source tracking
        if File.exist?(source_file)
          source = YAML.load_file(source_file)
          if source&.dig('en')
            remove_keys_present_in!(source['en'], human)
            File.write(source_file, yaml_dump(source))
          end
        end
      end

      cleaned
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    def merge_flat!(target, source, prefix = '')
      source.each do |key, value|
        full_key = prefix.empty? ? key.to_s : "#{prefix}.#{key}"
        if value.is_a?(Hash)
          merge_flat!(target, value, full_key)
        else
          target[full_key] = value
        end
      end
    end

    def set_nested_key(hash, dotted_key, value)
      keys = dotted_key.split('.')
      current = hash
      keys[0..-2].each do |key|
        current[key] ||= {}
        current = current[key]
      end
      current[keys.last] = value
    end

    def count_keys(hash, count = 0)
      return count unless hash.is_a?(Hash)

      hash.each_value do |value|
        count = value.is_a?(Hash) ? count_keys(value, count) : count + 1
      end
      count
    end

    def deep_merge!(target, source)
      source.each do |key, value|
        if value.is_a?(Hash) && target[key].is_a?(Hash)
          deep_merge!(target[key], value)
        else
          target[key] = value
        end
      end
    end

    def remove_keys_present_in!(hash, flat_keys, prefix = '')
      hash.each_key.to_a.each do |key|
        full_key = prefix.empty? ? key.to_s : "#{prefix}.#{key}"
        if hash[key].is_a?(Hash)
          remove_keys_present_in!(hash[key], flat_keys, full_key)
          hash.delete(key) if hash[key].empty?
        elsif flat_keys.key?(full_key) && !flat_keys[full_key].to_s.strip.empty?
          hash.delete(key)
        end
      end
    end

    def yaml_dump(data)
      data.to_yaml(line_width: -1)
    end

    # Load the source tracking file (English text that was translated)
    def load_source_tracking(locale)
      source_file = source_tracking_path(locale)
      return {} unless File.exist?(source_file)

      data = YAML.load_file(source_file)
      return {} unless data.is_a?(Hash) && data['en'].is_a?(Hash)

      result = {}
      merge_flat!(result, data['en'])
      result
    end

    # Update source tracking with current English text for translated keys
    def update_source_tracking(locale, translated_nested)
      english = load_flat_translations('en')
      translated_flat = {}
      merge_flat!(translated_flat, translated_nested)

      # Load existing source tracking
      source_file = source_tracking_path(locale)
      existing =
        if File.exist?(source_file)
          YAML.load_file(source_file) || {}
        else
          {}
        end
      existing['en'] ||= {}

      # For each translated key, store the current English text
      translated_flat.each_key do |key|
        next unless english.key?(key)

        set_nested_key(existing['en'], key, english[key])
      end

      File.write(source_file, yaml_dump(existing))
      puts "Updated source tracking: #{source_file}"
    end

    # Validate that translated keys match expected keys, filtering out extras
    # Returns filtered nested hash with only expected keys
    def validate_and_filter_keys(translated_nested, expected_keys, _locale)
      translated_flat = {}
      merge_flat!(translated_flat, translated_nested)

      # Report key differences
      report_key_differences(translated_flat.keys, expected_keys)

      # Build filtered result with validation
      build_filtered_translations(expected_keys, translated_flat)
    end

    def report_key_differences(translated_keys, expected_keys)
      unexpected = translated_keys - expected_keys
      missing = expected_keys - translated_keys

      if unexpected.any?
        puts "Warning: #{unexpected.length} unexpected keys (will be removed)"
        unexpected.first(5).each { |key| puts "  - #{key}" }
        puts "  ... (#{unexpected.length - 5} more)" if unexpected.length > 5
      end

      puts "Note: #{missing.length} keys not translated" if missing.any?
    end

    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/BlockLength
    def build_filtered_translations(expected_keys, translated_flat)
      english = load_flat_translations('en')
      filtered = {}
      validation_failures = []

      expected_keys.each do |key|
        next unless translated_flat.key?(key)

        value = translated_flat[key]
        english_value = english[key]

        # Skip blank translations (nil, empty, or whitespace-only)
        # This rejects translations that failed or returned blank
        if value.nil? || value.to_s.strip.empty?
          validation_failures << {
            key: key,
            english: english_value,
            translated: value,
            reason: 'Translation is blank or empty'
          }
          next
        end

        # Validate placeholders
        unless valid_placeholders?(english_value, value)
          validation_failures << {
            key: key,
            english: english_value,
            translated: value,
            reason: placeholder_failure_reason(english_value, value)
          }
          next
        end

        # Validate HTML tags
        unless valid_html_tags?(english_value, value)
          validation_failures << {
            key: key,
            english: english_value,
            translated: value,
            reason: html_failure_reason(english_value, value)
          }
          next
        end

        # Validate URL count
        unless valid_url_count?(english_value, value)
          validation_failures << {
            key: key,
            english: english_value,
            translated: value,
            reason: url_failure_reason(english_value, value)
          }
          next
        end

        set_nested_key(filtered, key, value)
      end

      report_validation_failures(validation_failures) if validation_failures.any?
      filtered
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/BlockLength

    def report_validation_failures(failures)
      puts ''
      puts '=' * 80
      puts "VALIDATION FAILURES: #{failures.length} translation(s) rejected"
      puts '=' * 80

      failures.each_with_index do |failure, i|
        puts ''
        puts "#{i + 1}. Key: #{failure[:key]}"
        puts "   Reason: #{failure[:reason]}"
        puts "   English:    #{failure[:english].to_s[0, 100]}#{'...' if failure[:english].to_s.length > 100}"
        puts "   Translated: #{failure[:translated].to_s[0, 100]}#{'...' if failure[:translated].to_s.length > 100}"
      end

      puts ''
      puts '=' * 80
    end

    def placeholder_failure_reason(english, translated)
      english_ph = extract_placeholders(english.to_s)
      translated_ph = extract_placeholders(translated.to_s)
      missing = english_ph - translated_ph
      "Missing placeholders: #{missing.join(', ')}"
    end

    def html_failure_reason(english, translated)
      english_tags = extract_html_tags(english.to_s)
      translated_tags = extract_html_tags(translated.to_s)
      missing = english_tags - translated_tags
      "Missing HTML tags: #{missing.map { |t| "<#{t}>" }
.join(', ')}"
    end

    def url_failure_reason(english, translated)
      english_count = count_urls(english.to_s)
      translated_count = count_urls(translated.to_s)
      "URL count mismatch: English has #{english_count}, translation has #{translated_count}"
    end

    # Check if translation preserves all placeholders from source
    # Placeholders are in format %{variable_name}
    def valid_placeholders?(source_text, translated_text)
      return true if source_text.nil? || translated_text.nil?

      source_placeholders = extract_placeholders(source_text.to_s)
      translated_placeholders = extract_placeholders(translated_text.to_s)

      # All source placeholders must appear in translation
      source_placeholders.all? { |ph| translated_placeholders.include?(ph) }
    end

    # Extract all placeholder variables from text
    # Returns array of placeholder strings like ["%{name}", "%{count}"]
    def extract_placeholders(text)
      text.scan(/%\{[A-Za-z0-9_]+\}/)
    end

    # Check if translation preserves critical HTML tags from source
    # Tags like <a href=, <em>, <strong>, etc. must be preserved
    def valid_html_tags?(source_text, translated_text)
      return true if source_text.nil? || translated_text.nil?

      source_tags = extract_html_tags(source_text.to_s)
      translated_tags = extract_html_tags(translated_text.to_s)

      # All source tags must appear in translation
      source_tags.all? { |tag| translated_tags.include?(tag) }
    end

    # Extract critical HTML tags from text
    # Returns array of tag names like ["a", "em", "strong"]
    def extract_html_tags(text)
      # Match opening tags: <tag> or <tag attr="...">
      # Extract just the tag name
      text.scan(/<([a-z]+)[\s>]/).flatten.uniq.sort
    end

    # Check if translation has same number of URLs as source
    def valid_url_count?(source_text, translated_text)
      return true if source_text.nil? || translated_text.nil?

      source_urls = count_urls(source_text.to_s)
      translated_urls = count_urls(translated_text.to_s)

      source_urls == translated_urls
    end

    # Count URLs in text (http://, https://, www.)
    def count_urls(text)
      text.scan(%r{https?://|www\.}).length
    end

    # Copilot execution helpers

    # rubocop:disable Naming/PredicateMethod
    def execute_copilot(prompt, target_file)
      # Build copilot command with minimal permissions (read + write only)
      # Runs from tmp/ directory so copilot can only access files there
      cmd = [
        'copilot',
        '-p', prompt,
        '--allow-tool', 'read',
        '--allow-tool', 'write',
        '--silent',
        '--no-ask-user'
      ]

      puts 'Running Copilot translation...'
      # Run from tmp/ directory to restrict file access to only that directory
      result = Dir.chdir(Rails.root.join('tmp')) { system(*cmd) }

      # Check if target file was created/modified
      if result && File.exist?(target_file)
        content = File.read(target_file)
        # Verify it's not empty or just the template
        return content.length > 50 && !content.include?(": ''")
      end

      false
    end
    # rubocop:enable Naming/PredicateMethod

    # Load YAML file, attempting to fix common issues if normal parsing fails
    def load_yaml_with_fallback(file, locale)
      # First try: load normally
      begin
        return YAML.load_file(file)
      rescue Psych::SyntaxError => e
        puts "Initial YAML parse failed: #{e.message}"
        puts 'Attempting to repair YAML formatting...'
      end

      # Second try: fix common quoting issues
      content = File.read(file)
      fixed_content = fix_yaml_quoting(content, locale)

      begin
        translated = YAML.load(fixed_content)
        puts 'Successfully repaired YAML formatting'
        # Write the fixed version back
        File.write(file, fixed_content)
        return translated
      rescue Psych::SyntaxError => e
        puts "YAML parse error after repair attempt: #{e.message}"
        return
      end
    end

    # Fix common YAML quoting issues in Copilot output
    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def fix_yaml_quoting(content, _locale)
      lines = content.split("\n")
      fixed_lines =
        lines.map do |line|
          # Match lines with single-quoted values containing apostrophes
          # Pattern: key: 'value...'
          if line =~ /^(\s+)(\w+):\s+'(.+)'$/
            indent = ::Regexp.last_match(1)
            key = ::Regexp.last_match(2)
            value = ::Regexp.last_match(3)

            # Check if value contains an unescaped apostrophe
            # In YAML single quotes, apostrophes should be doubled ('')
            if value.include?("'") && !value.include?("''")
              # Convert to double quotes and escape backslashes and quotes properly
              # Must escape backslashes first to avoid double-escaping
              escaped_value = value.gsub('\\', '\\\\').gsub('"', '\"')
              "#{indent}#{key}: \"#{escaped_value}\""
            else
              # Single quotes are fine if no apostrophes
              line
            end
          # Match lines with UNQUOTED values that contain URLs or HTML
          # Pattern: key: <value or key: text://...
          # These need to be quoted because colons break YAML
          elsif line =~ %r{^(\s+)([\w_]+):\s+(<.+|.+://.*)$}
            indent = ::Regexp.last_match(1)
            key = ::Regexp.last_match(2)
            value = ::Regexp.last_match(3)

            # If already quoted, check for internal quote issues instead
            if value.start_with?('"', "'")
              fix_internal_quotes(line)
            else
              escaped_value = value.gsub('\\', '\\\\').gsub('"', '\"')
              "#{indent}#{key}: \"#{escaped_value}\""
            end
          else
            # Try to fix unescaped internal double quotes in double-quoted values
            fix_internal_quotes(line)
          end
        end
      fixed_lines.join("\n")
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    # Fix unescaped double quotes inside double-quoted YAML values
    # e.g., key: "The "term" means..." -> key: "The \"term\" means..."
    def fix_internal_quotes(line)
      # Match: key: "value with potential internal quotes"
      return line unless line =~ /^(\s+)([\w_]+):\s+"(.+)"$/

      indent = ::Regexp.last_match(1)
      key = ::Regexp.last_match(2)
      inner = ::Regexp.last_match(3)

      # Check if there are unescaped quotes (quotes not preceded by backslash)
      # Count quotes that are NOT preceded by backslash
      unescaped_quotes = inner.scan(/(?<!\\)"/).length
      return line if unescaped_quotes.zero?

      # Escape backslashes first, then quotes (like line 991)
      # This prevents incomplete sanitization vulnerabilities
      fixed_inner = inner.gsub('\\', '\\\\').gsub('"', '\"')

      "#{indent}#{key}: \"#{fixed_inner}\""
    end
  end
end
# rubocop:enable Rails/Output, Metrics/ModuleLength, Metrics/ClassLength
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength
