# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

module Translations
  module_function

  # This class is a used to gather sets of translations which will commonly
  # be called in bulk.  For example, there are translations we would like
  # to export to JavaScript.  We can use a method here to do that quickly.

  # Returns all JavaScript-relevant translations keyed by locale then field.
  # @return [Hash{Symbol => Hash{String => String}}]
  #   locale symbol -> translation key -> translated string
  def for_js
    # Get keys from English locale - works with both nested and flat backends
    keys = js_translation_keys

    js_translations =
      I18n.available_locales.map do |locale|
        locale_t =
          keys.map do |k|
            [k, I18n.t(".projects.misc.in_javascript.#{k}", locale: locale)]
          end
        [locale, locale_t.to_h]
      end
    js_translations.to_h
  end

  # Returns the list of translation keys under projects.misc.in_javascript.
  # Works with both nested backends (returns hash.keys) and flat backends.
  # @return [Array<Symbol>] sorted list of JavaScript translation keys
  def js_translation_keys
    # Try traditional nested backend approach first
    result = I18n.t('.projects.misc.in_javascript', locale: :en, default: nil)
    return result.keys if result.is_a?(Hash)

    # For flat backends, use the backend's nested_hash method
    backend = I18n.backend
    return [] unless backend.respond_to?(:nested_hash)

    nested = backend.nested_hash(:en, 'projects.misc.in_javascript')
    nested ? nested.keys.sort : []
  end

  # Get all translation keys under a given path.
  # Works with both nested and flat backends.
  # @param path [String] dot-separated translation path
  # @param locale [Symbol] locale to query (defaults to :en)
  # @return [Array<Symbol>] sorted list of keys
  def get_translation_keys(path, locale: :en)
    # Try traditional nested backend approach first
    result = I18n.t(".#{path}", locale: locale, default: nil)
    return result.keys if result.is_a?(Hash)

    # For flat backends, use the backend's nested_hash method
    backend = I18n.backend
    return [] unless backend.respond_to?(:nested_hash)

    nested = backend.nested_hash(locale, path)
    nested ? nested.keys.sort : []
  end
end
