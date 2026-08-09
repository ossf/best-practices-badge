# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Custom I18n backend with single merged hash for O(1) translation lookup.
#
# CRITICAL REQUIREMENT:
# Machine translations MUST NOT be in I18n.load_path because translation.io
# reads from I18n.load_path and would sync them to the remote service.
# This is not a *security* requirement, but it is needed for correct data.
#
# Translation precedence (highest to lowest):
# 1. Human translations (from I18n.load_path)
# 2. Machine translations (from config/machine_translations/)
# 3. English fallback
#
# For pluralization hashes, merging happens at the key level
# (:one, :other, etc.) so partial human translations are filled
# in by machine translations.
#
# PERFORMANCE: Single hash lookup per translation. All values frozen at init.
# Memory: Only stores merged flat hash; source data is discarded after merge.
# Hot path optimization: Uses frozen constants to avoid allocating new objects
# on every method call.

# rubocop:disable Style/Send, Metrics/ClassLength
class MachineTranslationFallbackBackend < I18n::Backend::Simple
  # Pluralization keys used by I18n to select singular/plural forms.
  # Stored as a Set for O(1) membership testing.
  PLURAL_KEYS = Set.new(%w[zero one two few many other]).freeze

  # Frozen empty hash to avoid allocating new hash objects on every call
  EMPTY_HASH = {}.freeze

  # Frozen empty array to avoid allocating new array objects on every call
  EMPTY_ARRAY = [].freeze

  # Override parent's initialize to load and merge translations from files.
  # Files are loaded one at a time to minimize peak memory usage.
  # @param human_files [Array<String>] paths to human translation YAML files
  # @param machine_files [Array<String>] paths to machine translation YAML files
  def initialize(human_files, machine_files)
    super()
    @translations = build_merged_hash(human_files, machine_files)
    load_ruby_locale_files
    # Tell parent class we're initialized (prevents lazy reload in lookup)
    @initialized = true
  end

  # Override parent's translate to use optimized single hash lookup.
  # @param locale [Symbol] the locale (e.g., :fr, :de)
  # @param key [String, Symbol] the translation key
  # @param options [Hash] options including :scope, :count, :default
  # @return [String, Hash, nil] the translated value or nil if not found
  # rubocop:disable Style/OptionHash
  def translate(locale, key, options = EMPTY_HASH)
    lookup_key = build_lookup_key(key, options[:scope])

    value = @translations.dig(locale, lookup_key)

    return process_translation(locale, lookup_key, value, options) if value

    # Key not found - use parent's default handling for fallback arrays
    return default(locale, key, options[:default], options) if options.key?(:default)

    nil
  end
  # rubocop:enable Style/OptionHash

  # Override parent's lookup to use our flat hash structure.
  # This is called by parent's translate() method.
  # @param locale [Symbol] the locale
  # @param key [String, Symbol] the translation key
  # @param scope [Array, nil] the scope
  # @param options [Hash] additional options (unused - parameter kept for API compatibility)
  # @return [String, Hash, nil] the value or nil if not found
  # rubocop:disable Style/OptionHash
  def lookup(locale, key, scope = EMPTY_ARRAY, _options = EMPTY_HASH)
    lookup_key = build_lookup_key(key, scope)
    @translations.dig(locale, lookup_key)
  end
  # rubocop:enable Style/OptionHash

  # Override parent's exists? to check our flat hash structure.
  # @param locale [Symbol] the locale
  # @param key [String, Symbol] the translation key
  # @param options [Hash] options including :scope
  # @return [Boolean] true if the translation exists
  # rubocop:disable Style/OptionHash
  def exists?(locale, key, options = EMPTY_HASH)
    lookup_key = build_lookup_key(key, options[:scope])
    @translations.dig(locale, lookup_key).present?
  end
  # rubocop:enable Style/OptionHash

  # Override parent's available_locales to return keys from our merged hash.
  # @return [Array<Symbol>] available locales
  def available_locales
    @translations.keys
  end

  # Override parent's reload! as a no-op: translations loaded at startup.
  def reload!; end

  # Override parent's eager_load! as a no-op: translations loaded at startup.
  def eager_load!; end

  # Override store_translations to flatten and store data in our format.
  # This allows rails-i18n pluralization rules, date formats, etc. to work.
  # Note: This does NOT affect the translation.io concern - that reads from
  # I18n.load_path (files), not from store_translations (runtime API).
  # @param locale [Symbol] the locale
  # @param data [Hash] the nested data to store
  # @param options [Hash] options (unused - parameter kept for API compatibility)
  # rubocop:disable Style/OptionHash
  def store_translations(locale, data, _options = EMPTY_HASH)
    return unless data.is_a?(Hash)

    @translations[locale] ||= {}
    store_nested(locale, data, '')
  end
  # rubocop:enable Style/OptionHash

  # Return the merged flat translations hash.
  # Note: This returns flat format {"dotted.key" => value}, not nested.
  # @return [Hash] flat translations hash keyed by locale
  attr_reader :translations

  # Public API method (not an override): Get a nested hash
  # for a translation path.
  # This is needed for asset precompilation where we export translations to JS.
  # @param locale [Symbol] locale
  # @param path [String] translation path (e.g., "criteria.0.description_good")
  # @return [Hash, nil] nested hash with symbol keys, or nil if not found
  def nested_hash(locale, path)
    locale_data = @translations[locale]
    return unless locale_data

    prefix = path.empty? ? '' : "#{path}."
    matching_keys = locale_data.keys.select { |k| prefix.empty? || k.start_with?(prefix) }
    return if matching_keys.empty?

    result = {}
    matching_keys.each do |full_key|
      relative_key = prefix.empty? ? full_key : full_key.delete_prefix(prefix)
      value = locale_data[full_key]
      set_nested_value(result, relative_key.split('.'), value)
    end
    result
  end

  private

  # Load a single YAML file and flatten its translations into the
  # accumulator. The YAML nested data is discarded after flattening.
  # Blank values are always skipped; present values overwrite earlier ones,
  # so loading machine files first and human files second gives correct
  # precedence. Pluralization parent hashes are built as we go.
  # @param accumulator [Hash] {locale: {"dotted.key" => value}} to merge into
  # @param filepath [String] path to a YAML file
  def flatten_yaml_file_into(accumulator, filepath)
    return unless File.exist?(filepath)

    yaml_data = YAML.load_file(filepath)
    return unless yaml_data.is_a?(Hash)

    yaml_data.each do |locale, translations|
      next unless translations.is_a?(Hash)

      locale_sym = locale.to_sym
      accumulator[locale_sym] ||= {}
      flatten_tree(translations, '', accumulator[locale_sym])
    end
  end

  # Load Ruby locale files from I18n.load_path (pluralization, ordinals, etc.).
  # YAML files are loaded via human_files; this handles the .rb files that
  # rails-i18n uses for Procs (pluralization rules, ordinal rules, etc.).
  def load_ruby_locale_files
    I18n.load_path.each do |path|
      next unless path.end_with?('.rb')

      data, = load_rb(path)
      next unless data.is_a?(Hash)

      data.each do |locale, translations|
        store_translations(locale.to_sym, translations) if translations.is_a?(Hash)
      end
    rescue StandardError, SyntaxError => e
      Rails.logger.debug { "Could not load locale data from #{path}: #{e.message}" }
    end
  end

  # Store nested hash data in BOTH flat and hierarchical formats.
  # Flat: "a.b" => "x" (for our optimized lookup)
  # Hierarchical: "a" => { "b" => "x" } (for compatibility with parent class methods)
  # This ensures lookups work regardless of which format code expects.
  # @param locale [Symbol] the locale
  # @param hash [Hash] the nested hash to store
  # @param prefix [String] the key prefix built up during recursion
  def store_nested(locale, hash, prefix)
    hash.each do |key, value|
      full_key = prefix.empty? ? key.to_s : "#{prefix}.#{key}"
      if value.is_a?(Hash)
        store_nested(locale, value, full_key)
      else
        # Store flat format for our optimized lookup
        @translations[locale][full_key] = value
        # Also store hierarchical format for parent class compatibility
        store_hierarchical(locale, full_key, value)
      end
    end
  end

  # Store a value in hierarchical (nested hash) format.
  # @param locale [Symbol] the locale
  # @param dotted_key [String] the dotted key (e.g., "a.b.c")
  # @param value [Object] the value to store
  def store_hierarchical(locale, dotted_key, value)
    keys = dotted_key.split('.')
    current = @translations[locale]
    keys[0..-2].each do |k|
      current[k] ||= {}
      current = current[k]
    end
    current[keys.last] = value
  end

  # Build a single merged hash: machine base → human overlay → English fallback.
  # Uses one accumulator: machine files flattened first, then human files
  # overlay (present values overwrite). Blank values are always skipped, so
  # a blank human entry never erases a machine translation.
  # Pluralization parent hashes are built during flattening, not in a
  # separate pass. Only one YAML file is in memory at a time.
  # @param human_files [Array<String>] paths to human translation YAML files
  # @param machine_files [Array<String>] paths to machine translation YAML files
  # @return [Hash] flat hash {locale: {"dotted.key" => value}} with frozen values
  def build_merged_hash(human_files, machine_files)
    merged = {}
    machine_files.each { |f| flatten_yaml_file_into(merged, f) }
    human_files.each { |f| flatten_yaml_file_into(merged, f) }

    english = merged[:en] || EMPTY_HASH

    result = {}
    merged.each do |locale, flat_data|
      fallback = locale == :en ? EMPTY_HASH : english
      result[locale] = apply_fallback(flat_data, fallback)
    end
    result
  end

  # Recursively flatten a nested hash into dotted-key format.
  # Skips blank values and builds pluralization parent hashes as it goes.
  # @param hash [Hash] the hash to flatten
  # @param prefix [String] the key prefix built up during recursion
  # @param result [Hash] accumulator (modified in place for efficiency)
  # @return [Hash] flat hash with dotted string keys
  def flatten_tree(hash, prefix, result = {})
    hash.each do |key, value|
      full_key = prefix.empty? ? key.to_s : "#{prefix}.#{key}"
      if value.is_a?(Hash)
        flatten_tree(value, full_key, result)
      elsif present_string?(value)
        result[full_key] = value.freeze
        add_to_parent_if_plural(result, full_key, value)
      end
    end
    result
  end

  # Apply English fallback for keys not already present.
  # The flat_data already has correct values and pluralization parent
  # hashes from flatten_tree; this just fills gaps from English.
  # @param flat_data [Hash] merged flat translations for one locale
  # @param english [Hash] flat English translations (fallback)
  # @return [Hash] the same hash, with fallbacks added
  def apply_fallback(flat_data, english)
    english.each do |key, value|
      next if present_string?(flat_data[key])
      next unless present_string?(value)

      flat_data[key] = value.freeze
      add_to_parent_if_plural(flat_data, key, value)
    end

    flat_data
  end

  # If key ends with a plural key, add merged value to parent hash.
  # @param result [Hash] the result hash to modify
  # @param key [String] the full dotted key
  # @param merged [String] the merged value
  def add_to_parent_if_plural(result, key, merged)
    parts = key.rpartition('.')
    leaf_key = parts.last
    return if PLURAL_KEYS.exclude?(leaf_key)

    parent_key = parts.first
    return if parent_key.empty?

    ensure_parent_hash(result, parent_key, key)
    result[parent_key][leaf_key.to_sym] = merged
  end

  # Ensure parent key is a hash, replacing any string value if needed.
  # @param result [Hash] the result hash to modify
  # @param parent_key [String] the parent key
  def ensure_parent_hash(result, parent_key, _child_key = nil)
    existing = result[parent_key]
    return result[parent_key] = ActiveSupport::HashWithIndifferentAccess.new if existing.nil?
    return if existing.is_a?(Hash)

    # Some rails-i18n locale files use plain strings for keys that English
    # defines as plural hashes (e.g., zh-CN/ja/sw for
    # errors.messages.too_short). This is expected and harmless.
    # Chinese and Japanese don't grammatically
    # distinguish singular and plural, and Swahili has a special class system.
    # No warning needed, simply deal with it.
    result[parent_key] = ActiveSupport::HashWithIndifferentAccess.new
  end

  # Build the lookup key by combining scope and key.
  # @param key [String, Symbol] the translation key
  # @param scope [Symbol, String, Array, nil] optional scope prefix
  # @return [String] the full dotted lookup key
  def build_lookup_key(key, scope)
    key_str = key.to_s
    # Leading dot means "ignore scope, use absolute path from root"
    return key_str.delete_prefix('.') if key_str.start_with?('.')
    return key_str if scope.nil? || (scope.is_a?(Array) && scope.empty?)

    scope_str = scope.is_a?(Array) ? scope.join('.') : scope.to_s
    "#{scope_str}.#{key_str}"
  end

  # Check if a string value is present (non-nil, non-empty).
  # @param value [String, nil] the value to check
  # @return [Boolean] true if present
  def present_string?(value)
    value.is_a?(String) ? value != '' : !value.nil?
  end

  # Process a found translation: resolve, pluralize, and interpolate.
  # @param locale [Symbol] the locale for pluralization rules
  # @param key [String] the translation key
  # @param value [String, Hash] the raw translation value
  # @param options [Hash] options including :count for pluralization
  # @return [String] the processed translation string
  def process_translation(locale, key, value, options)
    # Only create new hash if we need to exclude :default (parent's resolve doesn't use it)
    resolve_opts =
      if options != EMPTY_HASH && options.key?(:default)
        options.except(:default)
      else
        options
      end
    entry = resolve(locale, key, value, resolve_opts)
    return entry if entry.is_a?(::I18n::MissingTranslation)

    entry = pluralize(locale, entry, options[:count]) if options.key?(:count)
    interpolate(locale, entry, options)
  end

  # Set a value in a nested hash given a path of keys.
  # @param hash [Hash] the hash to modify
  # @param keys [Array<String>] path of keys
  # @param value [Object] the value to set
  def set_nested_value(hash, keys, value)
    if keys.length == 1
      # Use symbols for hash keys to match I18n conventions
      hash[keys.first.to_sym] = value
    else
      key = keys.first.to_sym
      hash[key] ||= {}
      set_nested_value(hash[key], keys[1..], value)
    end
  end
end
# rubocop:enable Style/Send, Metrics/ClassLength
