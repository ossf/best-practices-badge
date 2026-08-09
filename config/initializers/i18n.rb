# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Here we set the available locales.
#
# Rails requires that locales given (if any) must be an
# available locale by default (I18n.enforce_available_locales = true).
# We build on that by setting the available locales.
#
# The Rails default is as follows (this illustrates some options):
# [:en, :"en-BORK", :"de-CH", :fa, :"en-US", :"en-GB", :ja, :"en-NG", :es,
# :"en-UG", :"ca-CAT", :"en-PAK", :pt, :"de-AT", :nl, :"en-AU", :"en-ZA",
# :"nb-NO", :id, :"en-IND", :"es-MX", :"fi-FI", :ca, :ru, :fr, :"en-CA",
# :ko, :vi, :sv, :"da-DK", :he, :"en-SG", :tr, :"zh-CN", :pl, :it, :sk,
# :de, :"en-au-ocker", :"en-NZ", :"zh-TW", :"pt-BR", :nep, :uk, :ro, :da,
# :hu, :cs]
#
# The order here is English (the source language in this case), followed
# by the locales in English name order. Pagy initialization requires en first.
# This has the useful side-effect that Chinese is listed early, next to
# a Romance language, so it will be *immediately* obvious to users
# that this is the locale selection list.
# We maintain this order elsewhere, to reduce the risk that
# we'll accidentally omit a locale.  For example, see
# config/initializers/translation.rb

I18n.available_locales = %i[en zh-CN es fr de ja pt-BR ru sw].freeze

# String version of available locales for validations
Rails.application.config.valid_locale_strings =
  I18n.available_locales.map(&:to_s).freeze

# Here are the locales we will *automatically* switch to.
# This *may* be the same as I18n.available_locales, but if a locale's
# translation isn't ready we will remove it here.
Rails.application.config.automatic_locales =
  (I18n.available_locales.dup - %i[es sw pt-BR]).freeze

# Automatic_locales must be a subset of I18n.available_locales - check it!
raise InvalidLocale unless
  (Rails.application.config.automatic_locales - I18n.available_locales).empty?

# The rest of the application uses those settings above automatically.
# For example, robots.txt counters crawling in these locales.
# To see how it does that, see:
# app/views/static_pages/robots.text.erb
#

# If we don't have text, fall back to English.  That obviously isn't
# ideal, but it's better to show *some* text to the user than leave it
# a mystery.
# ALSO: Gem i18n 1.1 changed fallbacks to exclude default locale. It says:
# > Please check your Rails app for 'config.i18n.fallbacks = true'.
# > If you're using I18n (>= 1.1.0) and Rails (< 5.2.2), this should be
# > 'config.i18n.fallbacks = [I18n.default_locale]'.
# > If not, fallbacks will be broken in your app by I18n 1.1.x.
Rails.application.config.i18n.fallbacks = [:en]

# Load machine translations using a custom I18n backend with smart fallback.
#
# CRITICAL REQUIREMENT:
# Machine translations MUST NOT be added to I18n.load_path because
# translation.io's sync mechanism reads ALL files from I18n.load_path
# and would upload our machine translations to translation.io, making it
# impossible to distinguish between human and machine translations.
#
# WHY NOT CONDITIONAL LOADING (Rails.env.local? check)?
# That would mean test/development see different behavior than production.
# We need consistent behavior across all environments.
#
# SOLUTION: Custom Backend with Smart Fallback
# We load machine translations into a separate backend (not in I18n.load_path),
# then use MachineTranslationFallbackBackend to check human translations first,
# falling through to machine translations only when human is nil/empty.
#
# Result:
# - Machine translations work in ALL environments (production, test, dev)
# - Human translations (when present) always override machine translations
# - Empty/nil values in human translations are treated as "not translated"
# - translation.io never sees machine translations
# - Consistent behavior everywhere

require_relative '../../lib/machine_translation_fallback_backend'

# Build display name for a single locale pair
# @param ui_locale [Symbol] The locale for the UI display
# @param target_locale [Symbol] The locale being described
# @return [String] Formatted display name
def build_single_locale_display_name(ui_locale, target_locale)
  I18n.with_locale(ui_locale) do
    name = I18n.t("locale_name.#{target_locale}")
    name += " / #{I18n.t("locale_name.#{target_locale}", locale: target_locale)}" if target_locale != ui_locale
    "#{name} (#{target_locale})".freeze
  end
end

# Build locale display names hash for all UI and target locale combinations
# @return [Hash] Nested hash: {ui_locale => {target_locale => display_string}}
def build_locale_display_names
  {}.tap do |outer_hash|
    I18n.available_locales.each do |ui_locale|
      outer_hash[ui_locale.to_s] = {}.tap do |inner_hash|
        I18n.available_locales.each do |target_locale|
          inner_hash[target_locale.to_s] = build_single_locale_display_name(ui_locale, target_locale)
        end
      end.freeze
    end
  end.freeze
end

# Build select options arrays for Rails form helpers
# @return [Hash] Hash mapping UI locale to array of [display_name, code] pairs
def build_locale_select_options(display_names)
  {}.tap do |hash|
    I18n.available_locales.each do |ui_locale|
      names = display_names[ui_locale.to_s]
      # Defense in depth: skip if names is nil (should not happen normally)
      next if names.nil?

      hash[ui_locale.to_s] =
        names
        .map { |code, name| [name, code].freeze }
        .freeze
    end
  end.freeze
end

Rails.application.config.after_initialize do
  # Pre-build locale display names and select options AFTER translations are loaded
  Rails.application.config.locale_display_names = build_locale_display_names
  Rails.application.config.locale_select_options =
    build_locale_select_options(Rails.application.config.locale_display_names)

  # CRITICAL SAFETY CHECK: Ensure machine translations are isolated
  # from translation.io. translation.io syncs all files
  # in I18n.load_path, so machine translations MUST NOT be there
  machine_translations_dir = Rails.root.join('config', 'machine_translations').to_s
  contaminated_paths = I18n.load_path.select { |path| path.to_s.start_with?(machine_translations_dir) }

  if contaminated_paths.any?
    paths_list = contaminated_paths.map { |p| "  - #{p}" }
                                   .join("\n")
    raise StandardError, <<~ERROR
      CRITICAL CONFIGURATION ERROR: Machine translations detected in I18n.load_path!

      The following machine translation files are in I18n.load_path:
      #{paths_list}

      This would cause translation.io to sync machine translations, contaminating
      the human translation database and making it impossible to distinguish between
      human and machine translations.

      Machine translations MUST be loaded through the custom backend only, not via
      I18n.load_path. Check config/initializers/i18n.rb and ensure machine_translations/
      directory is NOT added to I18n.load_path.
    ERROR
  end

  # Collect file paths for human and machine translations (YAML files only)
  human_files = I18n.load_path.select { |f| File.exist?(f) && f.end_with?('.yml', '.yaml') }

  machine_translation_pattern = Rails.root.join('config', 'machine_translations', '*.yml')
  machine_files =
    Dir[machine_translation_pattern].reject do |filepath|
      # Skip source tracking files (src_en_*.yml) - they're metadata, not translations
      File.basename(filepath).start_with?('src_en_')
    end

  # Replace backend with merged flat hash backend
  # This loads all translations, builds merged hash, then discards source data
  I18n.backend = MachineTranslationFallbackBackend.new(human_files, machine_files)
end
