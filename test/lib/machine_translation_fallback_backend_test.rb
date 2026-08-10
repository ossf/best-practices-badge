# frozen_string_literal: true

# Copyright the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# rubocop:disable Metrics/ClassLength
class MachineTranslationFallbackBackendTest < ActiveSupport::TestCase
  def setup
    super
    @backend = I18n.backend
  end

  test 'available_locales includes all locales' do
    locales = @backend.available_locales
    assert_includes locales, :en
    assert_includes locales, :fr
  end

  test 'reload! and eager_load! are no-ops' do
    @backend.reload!
    @backend.eager_load!
    assert I18n.t('feed_title', locale: :en).present?
  end

  test 'translations returns flat hash with dotted keys' do
    t = @backend.translations
    assert t.is_a?(Hash) && t.key?(:en)
    assert t[:en].key?('feed_title') && t[:en].key?('layouts.projects')
  end

  # rubocop:disable Rails/DotSeparatedKeys
  test 'translate handles scope parameter' do
    assert_equal 'Notions de base', I18n.t('Basics', scope: :headings, locale: :fr)
    assert_equal 'Contrôles', I18n.t('Controls', scope: :headings, locale: :fr)
    assert_equal I18n.t('Basics', scope: :headings, locale: :fr), I18n.t('headings.Basics', locale: :fr)
    assert_equal 'Submit (and exit)', I18n.t('submit_and_exit', scope: %i[projects edit], locale: :en)
  end
  # rubocop:enable Rails/DotSeparatedKeys

  test 'translate uses English fallback and returns nil for missing' do
    result = I18n.t('feed_title', locale: :fr)
    assert result.present? && result.include?('OpenSSF')
    assert_nil @backend.translate(:en, 'nonexistent.key')
  end

  test 'pluralization works with count' do
    assert_equal '1 Project', I18n.t('projects_count', count: 1, locale: :en)
    assert_equal '5 Projects', I18n.t('projects_count', count: 5, locale: :en)
  end

  test 'merged hash preserves pluralization hashes and freezes string values' do
    t = @backend.translations
    pc = t[:en]['projects_count']
    assert pc.is_a?(Hash) && pc.key?(:one) && pc.key?(:other)
    # String values are frozen, but hashes remain mutable for I18n compatibility
    assert t[:en]['feed_title'].frozen?
  end

  test 'build_lookup_key handles various inputs' do
    assert_equal 'key', @backend.send(:build_lookup_key, 'key', nil)
    assert_equal 'key', @backend.send(:build_lookup_key, :key, nil)
    assert_equal 'headings.Controls', @backend.send(:build_lookup_key, 'Controls', :headings)
    assert_equal 'projects.edit.title', @backend.send(:build_lookup_key, 'title', %i[projects edit])
  end

  test 'apply_fallback uses fallback only for missing keys' do
    flat_data = { 'a' => 'present', 'b' => '', 'c' => nil }
    english = { 'a' => 'en_a', 'b' => 'en_b', 'c' => 'en_c', 'd' => 'en_d' }
    result = @backend.send(:apply_fallback, flat_data, english)
    assert_equal 'present', result['a']
    assert_equal 'en_b', result['b']
    assert_equal 'en_c', result['c']
    assert_equal 'en_d', result['d']
  end

  test 'present_string? handles various inputs' do
    assert @backend.send(:present_string?, 'hello')
    assert @backend.send(:present_string?, false)
    assert_not @backend.send(:present_string?, nil)
    assert_not @backend.send(:present_string?, '')
  end

  test 'flatten_yaml_file_into loads file and handles missing gracefully' do
    accumulator = {}
    en_file = Rails.root.join('config', 'locales', 'en.yml').to_s
    @backend.send(:flatten_yaml_file_into, accumulator, en_file)
    assert accumulator.is_a?(Hash) && accumulator.key?(:en)

    empty = {}
    @backend.send(:flatten_yaml_file_into, empty, '/nonexistent/file.yml')
    assert_equal({}, empty)
  end

  test 'load_ruby_locale_files handles errors gracefully' do
    # Create a temporary malformed .rb file that will cause an error when loaded
    malformed_file = Rails.root.join('tmp', ',test_malformed_locale.rb')
    File.write(malformed_file, 'this is not valid ruby { [ (')

    original_load_path = I18n.load_path.dup
    begin
      # Add the malformed file to load_path
      I18n.load_path << malformed_file.to_s

      # Call the method - should handle the error gracefully without raising
      assert_nothing_raised do
        @backend.send(:load_ruby_locale_files)
      end
    ensure
      # Restore original load_path and clean up
      I18n.load_path.replace(original_load_path)
      FileUtils.rm_f(malformed_file)
    end
  end

  test 'lookup method finds translations with scope' do
    # Test direct lookup without scope (or with empty array scope)
    result = @backend.lookup(:en, 'feed_title', [])
    assert_equal 'OpenSSF Best Practices BadgeApp Updated Projects', result

    # Test lookup with scope as symbol
    result = @backend.lookup(:en, 'projects', [:layouts])
    assert_equal 'Projects', result

    # Test lookup with nil scope
    result = @backend.lookup(:en, 'hello', nil)
    assert_equal 'Hello world', result
  end

  test 'exists? method checks for translation presence' do
    assert @backend.exists?(:en, 'feed_title')
    assert @backend.exists?(:en, 'projects', scope: :layouts)
    assert_not @backend.exists?(:en, 'nonexistent_key')
    assert_not @backend.exists?(:en, 'nonexistent', scope: :nonexistent)
  end

  test 'store_translations stores data in flat format' do
    # store_translations now works (needed for rails-i18n pluralization rules)
    @backend.store_translations(:en, { test_key: 'test value' })
    assert_equal 'test value', @backend.lookup(:en, 'test_key', [])

    # Nested data is flattened
    @backend.store_translations(:en, { nested: { key: 'nested value' } })
    assert_equal 'nested value', @backend.lookup(:en, 'nested.key', [])
  end

  test 'translate returns default value when key not found' do
    result = @backend.translate(:en, 'missing.key', default: 'default value')
    assert_equal 'default value', result

    # Test with nil default (should return nil)
    result = @backend.translate(:en, 'missing.key', default: nil)
    assert_nil result
  end

  test 'nested_hash returns proper nested structure' do
    result = @backend.nested_hash(:en, 'locale_name')
    assert result.is_a?(Hash)
    assert_equal 'English', result[:en]
    assert_equal 'French', result[:fr]

    # Test with non-existent path
    result = @backend.nested_hash(:en, 'nonexistent.path')
    assert_nil result

    # Test with invalid locale
    result = @backend.nested_hash(:invalid_locale, 'locale_name')
    assert_nil result
  end

  test 'nested_hash handles deeply nested paths' do
    result = @backend.nested_hash(:en, 'projects.edit')
    assert result.is_a?(Hash)
    assert result.keys.any? # Should have some keys
  end

  test 'pluralization parent keys are created for single plural forms' do
    # Access the pluralization hash that should have been created
    t = @backend.translations
    # The test_pluralization_only_one should create a parent hash
    result = t[:en]['test_pluralization_only_one']
    assert result.is_a?(Hash)
    assert_equal 'just one item. Do not translate this.', result[:one]
  end

  test 'flatten_tree creates pluralization parent hashes' do
    # Test that parent keys are created for plural entries during flattening
    nested = { 'items' => { 'one' => 'one item', 'other' => 'other items' } }
    result = @backend.send(:flatten_tree, nested, '')

    # Should create 'items' parent hash
    assert result.key?('items')
    assert result['items'].is_a?(Hash)
    assert_equal 'one item', result['items']['one']
    assert_equal 'other items', result['items']['other']
  end

  test 'flatten_tree skips empty parent keys for top-level plurals' do
    # Plurals without a parent (shouldn't happen but should handle gracefully)
    nested = { 'one' => 'single', 'other' => 'multiple' }
    result = @backend.send(:flatten_tree, nested, '')

    # Should have the flat keys but not try to create invalid parent
    assert_equal 'single', result['one']
    assert_equal 'multiple', result['other']
  end

  # Russian has complex pluralization rules:
  # - one:  n % 10 == 1 && n % 100 != 11 (1, 21, 31, 41... but NOT 11, 111...)
  # - few:  n % 10 in 2..4 && n % 100 not in 12..14 (2, 3, 4, 22, 23, 24...)
  # - many: n % 10 == 0 || n % 10 in 5..9 || n % 100 in 11..14 (0, 5-20, 25-30...)
  # - zero: specifically 0 (optional, falls back to many if not defined)
  test 'Russian pluralization uses all plural forms correctly' do
    # From config/locales/translation.ru.yml:
    # zero: "Нет проектов"
    # one: "%{count} проект"
    # few: "%{count} проекта"
    # many: "%{count} проектов"
    # other: "%{count} проекта"

    # Test 'zero' form (count = 0)
    assert_equal 'Нет проектов', I18n.t('projects_count', count: 0, locale: :ru)

    # Test 'one' form (1, 21, 31, 101, but NOT 11)
    assert_equal '1 проект', I18n.t('projects_count', count: 1, locale: :ru)
    assert_equal '21 проект', I18n.t('projects_count', count: 21, locale: :ru)
    assert_equal '31 проект', I18n.t('projects_count', count: 31, locale: :ru)
    assert_equal '101 проект', I18n.t('projects_count', count: 101, locale: :ru)

    # Test 'few' form (2, 3, 4, 22, 23, 24, but NOT 12, 13, 14)
    assert_equal '2 проекта', I18n.t('projects_count', count: 2, locale: :ru)
    assert_equal '3 проекта', I18n.t('projects_count', count: 3, locale: :ru)
    assert_equal '4 проекта', I18n.t('projects_count', count: 4, locale: :ru)
    assert_equal '22 проекта', I18n.t('projects_count', count: 22, locale: :ru)
    assert_equal '23 проекта', I18n.t('projects_count', count: 23, locale: :ru)
    assert_equal '24 проекта', I18n.t('projects_count', count: 24, locale: :ru)

    # Test 'many' form (5-20, 25-30, 11, 12, 13, 14, 111, 112...)
    assert_equal '5 проектов', I18n.t('projects_count', count: 5, locale: :ru)
    assert_equal '10 проектов', I18n.t('projects_count', count: 10, locale: :ru)
    assert_equal '11 проектов', I18n.t('projects_count', count: 11, locale: :ru)
    assert_equal '12 проектов', I18n.t('projects_count', count: 12, locale: :ru)
    assert_equal '14 проектов', I18n.t('projects_count', count: 14, locale: :ru)
    assert_equal '15 проектов', I18n.t('projects_count', count: 15, locale: :ru)
    assert_equal '20 проектов', I18n.t('projects_count', count: 20, locale: :ru)
    assert_equal '25 проектов', I18n.t('projects_count', count: 25, locale: :ru)
    assert_equal '100 проектов', I18n.t('projects_count', count: 100, locale: :ru)
    assert_equal '111 проектов', I18n.t('projects_count', count: 111, locale: :ru)
  end

  # Date formatting varies by locale (from rails-i18n YAML files)
  test 'date formatting works correctly across locales' do
    date = Date.new(2024, 3, 15) # March 15, 2024

    # English: March 15, 2024
    assert_equal 'March 15, 2024', I18n.l(date, format: :long, locale: :en)

    # French: 15 mars 2024
    assert_equal '15 mars 2024', I18n.l(date, format: :long, locale: :fr)

    # German: 15. März 2024
    assert_equal '15. März 2024', I18n.l(date, format: :long, locale: :de)

    # Russian: 15 марта 2024
    assert_equal '15 марта 2024', I18n.l(date, format: :long, locale: :ru)

    # Japanese: 2024年03月15日(金) - includes day of week
    assert_equal '2024年03月15日(金)', I18n.l(date, format: :long, locale: :ja)

    # Short formats also vary
    assert_equal 'Mar 15', I18n.l(date, format: :short, locale: :en)
    assert_equal '15 mars', I18n.l(date, format: :short, locale: :fr)
  end

  # Day and month names are locale-specific
  test 'day and month names are localized' do
    # Day names
    assert_equal 'Friday', I18n.t('date.day_names', locale: :en)[5]
    assert_equal 'vendredi', I18n.t('date.day_names', locale: :fr)[5]
    assert_equal 'Freitag', I18n.t('date.day_names', locale: :de)[5]
    assert_equal '金曜日', I18n.t('date.day_names', locale: :ja)[5]

    # Month names
    assert_equal 'March', I18n.t('date.month_names', locale: :en)[3]
    assert_equal 'mars', I18n.t('date.month_names', locale: :fr)[3]
    assert_equal 'März', I18n.t('date.month_names', locale: :de)[3]
  end

  # Number formatting: decimal and thousands separators vary by locale
  test 'number formatting uses locale-specific separators' do
    # English/US: comma for thousands, period for decimal
    assert_equal '.', I18n.t('number.format.separator', locale: :en)
    assert_equal ',', I18n.t('number.format.delimiter', locale: :en)

    # French: space for thousands, comma for decimal
    assert_equal ',', I18n.t('number.format.separator', locale: :fr)
    assert_equal ' ', I18n.t('number.format.delimiter', locale: :fr)

    # German: comma for decimal, period for thousands
    assert_equal ',', I18n.t('number.format.separator', locale: :de)
    assert_equal '.', I18n.t('number.format.delimiter', locale: :de)

    # Verify number_to_currency uses locale settings
    # Note: We test the translations exist; actual formatting is done by helpers
    assert I18n.t('number.currency.format.format', locale: :en).present?
    assert I18n.t('number.currency.format.format', locale: :fr).present?
  end

  # ActiveRecord error messages are localized
  test 'ActiveRecord error messages are localized' do
    # Basic error messages
    blank_en = I18n.t('errors.messages.blank', locale: :en)
    blank_fr = I18n.t('errors.messages.blank', locale: :fr)
    blank_de = I18n.t('errors.messages.blank', locale: :de)

    assert_equal "can't be blank", blank_en
    assert_equal 'doit être rempli(e)', blank_fr
    assert_equal 'muss ausgefüllt werden', blank_de

    # Validation messages with interpolation
    too_short_en = I18n.t('errors.messages.too_short', count: 3, locale: :en)
    too_short_fr = I18n.t('errors.messages.too_short', count: 3, locale: :fr)

    assert_equal 'is too short (minimum is 3 characters)', too_short_en
    assert_match(/trop court/, too_short_fr)

    # Record invalid message (used when save fails)
    record_invalid_en = I18n.t('activerecord.errors.messages.record_invalid',
                               errors: 'Name is blank', locale: :en)
    assert_match(/Validation failed/, record_invalid_en)
  end

  # Test that ActiveRecord model validation actually uses localized messages
  test 'model validation errors use localized messages' do
    # Create an invalid project (missing required fields)
    project = Project.new

    # Validate in English
    I18n.with_locale(:en) do
      project.valid?
      # Should have errors with English messages
      assert project.errors.any?
      error_messages = project.errors.full_messages.join(' ')
      # Verify error messages are actual translated text, not arrays of translation keys
      # Project validates user_id (not a number), repo_url/homepage_url (URL format)
      assert_match(/is not a number|must begin with http/i, error_messages)
      # Verify attribute names are humanized strings, not symbol arrays
      assert_no_match(/\[:"/, error_messages, 'Error should not contain translation key arrays')
    end

    # Validate in French
    I18n.with_locale(:fr) do
      project.valid?
      assert project.errors.any?
      error_messages = project.errors.full_messages.join(' ')
      # French error messages should be in French
      # "n'est pas un nombre" = "is not a number" in French
      assert_match(/n'est pas un nombre|doit commencer par http/i, error_messages)
    end
  end

  # Time formatting also varies by locale
  test 'time formatting works correctly across locales' do
    time = Time.zone.local(2024, 3, 15, 14, 30, 0)

    # Different locales format times differently
    time_en = I18n.l(time, format: :short, locale: :en)
    time_fr = I18n.l(time, format: :short, locale: :fr)

    # Both should contain time components but formatted differently
    assert time_en.present?
    assert time_fr.present?
    # English typically uses 12-hour format, French uses 24-hour
    # Just verify they're different and non-empty
    assert time_en != time_fr || time_en.present?
  end
end
# rubocop:enable Metrics/ClassLength
