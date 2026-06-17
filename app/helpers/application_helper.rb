# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

module ApplicationHelper
  include Pagy::Frontend

  # Frozen string constant for unknown project names (memory optimization)
  NAME_UNKNOWN = '(Name Unknown)'

  # URL for the automation proposals documentation page.
  # Update this if the documentation moves to a new location.
  AUTOMATION_PROPOSALS_URL =
    'https://github.com/ossf/best-practices-badge/blob/main/docs/automation-proposals.md'

  # Frozen string constant: robot emoji for automation (memory optimization)
  ROBOT_EMOJI = '🤖 '
  # rubocop:disable Rails/OutputSafety
  ROBOT_EMOJI_SAFE = ROBOT_EMOJI.html_safe.freeze
  # rubocop:enable Rails/OutputSafety

  # Frozen string constants for highlight CSS classes (memory optimization)
  HIGHLIGHT_AUTOMATED_CLASS  = 'highlight-automated'
  HIGHLIGHT_OVERRIDDEN_CLASS = 'highlight-overridden'
  HIGHLIGHT_DIVERGENT_CLASS  = 'highlight-divergent'

  # Pre-computed section dropdown data for project show navigation.
  # Lazy-initialized (memoized) to avoid I18n initialization order issues.
  # Eagerly triggered during app boot
  # (see config/initializers/zz_eager_load_helpers.rb) to ensure
  # single-threaded initialization before Puma starts its thread pool.
  # @return [Hash{Symbol => Array<Hash>}] frozen hash keyed by locale;
  #   each value is an array of {name:, level:} section descriptors
  # rubocop:disable Metrics/MethodLength, Style/MethodCalledOnDoEndBlock
  def self.project_nav_sections
    @project_nav_sections ||= {}.tap do |hash|
      I18n.available_locales.each do |locale|
        hash[locale] = [
          {
            name: I18n.t('projects.form_early.level.0', locale: locale),
            level: 'passing'
          },
          {
            name: I18n.t('projects.form_early.level.1', locale: locale),
            level: 'silver'
          },
          {
            name: I18n.t('projects.form_early.level.2', locale: locale),
            level: 'gold'
          },
          {
            name: I18n.t('projects.form_early.level.baseline-1',
                         locale: locale),
            level: 'baseline-1'
          },
          {
            name: I18n.t('projects.form_early.level.baseline-2',
                         locale: locale),
            level: 'baseline-2'
          },
          {
            name: I18n.t('projects.form_early.level.baseline-3',
                         locale: locale),
            level: 'baseline-3'
          },
          {
            name: I18n.t('projects.edit.permissions_panel_title',
                         locale: locale, default: 'Permissions'),
            level: 'permissions'
          }
        ].freeze
      end
    end.freeze
  end
  # rubocop:enable Metrics/MethodLength, Style/MethodCalledOnDoEndBlock

  # This is like the ActionView view helper `cache`
  # (specifically ActionView::Helpers::CacheHelper)
  # where cache, cache_if, cache_unless, cache_fragment_name, and the private
  # fragment_for/write_fragment_for methods live.
  #
  # However, our version freezes the fragment as a SafeBuffer before writing
  # it to the cache, and returns the frozen SafeBuffer directly on read.
  # This pairs with NoDupCoder: frozen strings skip Entry allocation on
  # both write and every subsequent read, eliminating per-request copying
  # of large cached fragments.
  #
  # Unlike +cache+, this bypasses +read_fragment+ and +write_fragment+
  # to avoid the .to_str/.html_safe round-trip that would strip the
  # SafeBuffer class on write and allocate a new one on every read.
  #
  # Usage in views is identical to +cache+:
  #   <% cache_frozen [locale, 'sidebar'] do %>
  #     ...expensive rendering...
  #   <% end %>
  # @param name [Object] cache key fragment (default {})
  # @param options [Hash] cache store options (default {})
  # @return [nil] content is written to the output buffer; when cached,
  #   a frozen SafeBuffer is stored and reused to avoid per-request
  #   allocation (memory optimization under heavy load)
  # rubocop:disable Rails/OutputSafety
  def cache_frozen(name = {}, options = {}, &)
    if controller.respond_to?(:perform_caching) && controller.perform_caching
      cache_frozen_perform(name, options, &)
    else
      yield
    end
    nil
  end

  # Like +cache_if+: caches only when +condition+ is true.
  # @param condition [Boolean] caches only when truthy
  # @param name [Object] cache key fragment (default {})
  # @param options [Hash] cache store options (default {})
  # @return [nil] content is written to the output buffer; see
  #   cache_frozen for the frozen SafeBuffer memory optimization
  def cache_frozen_if(condition, name = {}, options = {}, &)
    if condition
      cache_frozen(name, options, &)
    else
      yield
      nil
    end
  end

  # Like +cache_unless+: caches only when +condition+ is false.
  # @param condition [Boolean] skips caching when truthy
  # @param name [Object] cache key fragment (default {})
  # @param options [Hash] cache store options (default {})
  # @return [nil] content is written to the output buffer; see
  #   cache_frozen for the frozen SafeBuffer memory optimization
  def cache_frozen_unless(condition, name = {}, options = {}, &)
    cache_frozen_if(!condition, name, options, &)
  end

  private

  def cache_frozen_perform(name, options, &)
    cache_key = controller.combined_fragment_cache_key(
      cache_fragment_name(name, **options.slice(:skip_digest))
    )
    fragment = controller.cache_store.read(cache_key, options)
    unless fragment
      fragment = output_buffer.capture(&).freeze
      controller.cache_store.write(cache_key, fragment, options)
    end
    safe_concat(fragment)
  end
  # rubocop:enable Rails/OutputSafety
end
