# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# This precomputes the text for each icon as safe_html.
# This is a singleton class.  It's complicated enough that
# it's useful to put in its own class.

class Icon
  class << self
    ICONS_TO_GENERATE = %i[
      fa-address-card
      fa-bookmark
      fa-edit
      fa-list
      fa-plus
      fa-sign-in-alt
      fa-sign-out-alt
      fa-times-circle
      fa-user
      fa-user-plus
    ].freeze
    BRAND_ICONS_TO_GENERATE = %i[
      fa-github
    ].freeze

    # Returns the pre-rendered SafeBuffer HTML for icon +key+.
    # @param key [Symbol] icon name, e.g. :'fa-user'
    # @return [ActiveSupport::SafeBuffer, nil] frozen HTML for the icon,
    #   or nil if the icon cache has not been initialized
    # @raise [KeyError] if key is not a registered icon name
    def [](key)
      # Use fetch, not @icon_data[key], so we discover missing keys
      @icon_data&.fetch(key)
    end

    # Returns all registered icon keys. Useful for debugging.
    # @return [Array<Symbol>] list of icon keys
    # Equivalent to:
    # def keys
    #   @icon_data.keys
    # end
    delegate :keys, to: :@icon_data

    # Populates the icon cache by pre-rendering HTML for every registered icon.
    # Must be called once during application initialization
    # before Icon[] is used.
    # @return [nil]
    def initialize_class
      @icon_data = {}
      ICONS_TO_GENERATE.each do |name|
        @icon_data[name] = my_icon_tag(name.to_s)
      end
      # Brands must be handled specially
      fab_html_safe = 'fab'.html_safe
      BRAND_ICONS_TO_GENERATE.each do |name|
        @icon_data[name] = my_icon_tag(name.to_s, fab_html_safe)
      end
      # Should we freeze it?
      nil
    end

    # Default class.
    # Unfortunately, rubocop doesn't realize that concatenating
    # constants we define is safe.
    # rubocop: disable Rails/OutputSafety
    FA_HTML_SAFE = 'fa'.html_safe
    # rubocop: enable Rails/OutputSafety

    private

    # Returns the tag for a given icon as a SafeBuffer.
    # In font-awesome 5, the category "fab" is used for brands.
    # Currently we use an icon file; in the future we
    # might use a reference to an SVG or SVG sprite.
    # Note: Double-check loading of the language icon if you change things.
    # I needed to handle it specially using this approach.
    def my_icon_tag(icon, category = FA_HTML_SAFE)
      # Unfortunately, rubocop doesn't realize that concatenating
      # constants we define is safe.
      # rubocop: disable Rails/OutputSafety
      res = ''.html_safe
      res.safe_concat('<i class="')
      res += category
      res.safe_concat(' ')
      res += icon
      res.safe_concat('" aria-hidden="true"></i>&nbsp;')
      # rubocop: enable Rails/OutputSafety
      res.freeze
    end
  end
end
