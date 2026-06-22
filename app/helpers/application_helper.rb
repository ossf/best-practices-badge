# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

module ApplicationHelper # rubocop:disable Metrics/ModuleLength
  include Pagy::Frontend

  # Frozen string constant for unknown project names (memory optimization)
  NAME_UNKNOWN = '(Name Unknown)'

  # URL for the automation proposals documentation page.
  # Update this if the documentation moves to a new location.
  AUTOMATION_PROPOSALS_URL =
    'https://github.com/coreinfrastructure/best-practices-badge/blob/main/docs/automation-proposals.md'

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

  # Cache metrics (enabled via CACHE_PROFILE=1).
  # Metrics are written to tmp/cache_metrics.json every 100 requests.
  # Read with: script/cache_metrics_report.rb
  CACHE_METRICS = {} # rubocop:disable Style/MutableConstant
  CACHE_METRICS_MUTEX = Mutex.new
  CACHE_METRICS_FILE = Rails.root.join('tmp/cache_metrics.json')
  CACHE_METRICS_WRITE_INTERVAL = 100

  def self.cache_metrics
    CACHE_METRICS_MUTEX.synchronize do
      CACHE_METRICS.values.sort_by { |m| -m[:hit_allocs] }
    end
  end

  def self.cache_metrics_reset
    CACHE_METRICS_MUTEX.synchronize { CACHE_METRICS.clear }
  end

  def self.cache_metrics_save
    CACHE_METRICS_MUTEX.synchronize do
      File.write(CACHE_METRICS_FILE, JSON.pretty_generate(CACHE_METRICS.values))
    end
  end

  private

  def cache_frozen_perform(name, options, &)
    return cache_frozen_perform_profiled(name, options, &) if ENV['CACHE_PROFILE']

    cache_frozen_perform_fast(name, options, &)
  end

  def cache_frozen_perform_fast(name, options, &)
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

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def cache_frozen_perform_profiled(name, options, &)
    alloc_before = GC.stat(:total_allocated_objects)
    cache_key = controller.combined_fragment_cache_key(
      cache_fragment_name(name, **options.slice(:skip_digest))
    )
    fragment = controller.cache_store.read(cache_key, options)

    if fragment
      # HIT: measure only the overhead (key gen + read + concat)
      safe_concat(fragment)
      hit_allocs = GC.stat(:total_allocated_objects) - alloc_before
      record_cache_metric(name, true, hit_allocs, 0)
    else
      # MISS: measure overhead separately from rendering
      alloc_after_read = GC.stat(:total_allocated_objects)
      fragment = output_buffer.capture(&).freeze
      controller.cache_store.write(cache_key, fragment, options)
      safe_concat(fragment)
      total_allocs = GC.stat(:total_allocated_objects) - alloc_before
      overhead_allocs = alloc_after_read - alloc_before # key gen + read
      record_cache_metric(name, false, overhead_allocs, total_allocs)
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def record_cache_metric(name, hit, overhead_allocs, miss_total_allocs)
    key = name.is_a?(Array) ? name.map(&:to_s).join('/') : name.to_s
    total = nil
    CACHE_METRICS_MUTEX.synchronize do
      m = CACHE_METRICS[key] ||= {
        key: key, hits: 0, misses: 0, hit_allocs: 0, miss_allocs: 0
      }
      if hit
        m[:hits] += 1
        m[:hit_allocs] += overhead_allocs
      else
        m[:misses] += 1
        m[:miss_allocs] += miss_total_allocs
      end
      total = CACHE_METRICS.values.sum { |v| v[:hits] + v[:misses] }
    end
    ApplicationHelper.cache_metrics_save if (total % CACHE_METRICS_WRITE_INTERVAL).zero?
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
  # rubocop:enable Rails/OutputSafety
end
