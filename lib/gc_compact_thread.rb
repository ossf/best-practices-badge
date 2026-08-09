# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Ruby's garbage collector doesn't normally compact, leading to
# uncontrolled memory fragmentation. Here we run a periodic compactor;
# this does pause the system. We accept this because without compaction
# we run out space eventually.
# We previously scheduled this using rack middleware, but that turned
# out to be unreliable (sometimes it would never be called).
# This is simpler anyway. This configuration is inspired by
# https://www.mintbit.com/blog/
# ruby-2-dot-7-optimizing-applications-with-gc-dot-compact/
# but I've made a number of changes.

# Module to handle periodic GC compaction in a background thread
# rubocop:disable Metrics/ModuleLength
module GcCompactThread
  module_function

  # Track string counts between compactions for delta reporting
  @previous_string_count = 0
  @previous_string_bytes = 0
  @allocation_tracing_enabled = false

  class << self
    attr_accessor :previous_string_count, :previous_string_bytes,
                  :allocation_tracing_enabled
  end

  # Enable allocation tracing if configured (has performance overhead)
  TRACE_ALLOCATIONS = ENV['BADGEAPP_TRACE_ALLOCATIONS'].present?

  # Enable allocation tracing. The already_enabled parameter allows testing
  # the enabling logic without checking/modifying global state.
  def enable_allocation_tracing(already_enabled: GcCompactThread.allocation_tracing_enabled)
    return if already_enabled

    ObjectSpace.trace_object_allocations_start
    GcCompactThread.allocation_tracing_enabled = true
    Rails.logger.warn 'GC.compact - Allocation tracing ENABLED'
  end

  # Regexes to retrieve memory information from /proc/self/status
  VM_RSS_RE  = /VmRSS:\s+(\d+)/
  VM_SWAP_RE = /VmSwap:\s+(\d+)/

  # Calculate compaction statistics.
  # We use .to_f on numerators before dividing, so that if the denominator
  # is 0 we get a NaN instead of an exception.
  def calculate_stats_diff(stats_before, stats_after, compact_info)
    {
      pages_freed: stats_before[:heap_allocated_pages] - stats_after[:heap_allocated_pages],
      objects_moved: compact_info[:moved],
      fragmentation_ratio_before: (stats_before[:heap_live_slots].to_f / stats_before[:heap_available_slots]).round(4),
      fragmentation_ratio_after: (stats_after[:heap_live_slots].to_f / stats_after[:heap_available_slots]).round(4),
      read_barrier_faults_delta: stats_after[:read_barrier_faults] - stats_before[:read_barrier_faults]
    }
  end

  require 'objspace'

  def report_class_info
    # Extract specific stats
    # This extracts only specific class info, so it's faster.
    [Redcarpet::Markdown, Redcarpet::Render::HTML, String, Array].each do |klass|
      count = 0
      total_mem = 0
      ObjectSpace.each_object(klass) do |o|
        count += 1
        total_mem += ObjectSpace.memsize_of(o)
      end
      Rails.logger.warn "GC.compact - #{klass.name}: Count #{count}, " \
                        "Ruby-Mem: #{total_mem} bytes"
    end
    # # sleep before another long-running task
    # sleep 10
    # # Get counts and memory sizes of all instances
    # counts = Hash.new(0) # count# instances. The '0' is the default value 0
    # mem_size = Hash.new(0)
    # ObjectSpace.each_object do |o|
    #   # We use the class object directly to avoid the overhead of
    #   # .name strings for every single object in the heap.
    #   cls = o.class
    #   counts[cls] += 1
    #   mem_size[cls] += ObjectSpace.memsize_of(o)
    # rescue StandardError
    #   # Some objects might not respond
    # end

    # # Sort and take top X to avoid massive log lines
    # top_mem = mem_size.sort_by { |_, v| -v }.first(50).map { |k, v| [k.to_s, v] }.to_h
    # top_count = counts.sort_by { |_, v| -v }.first(50).map { |k, v| [k.to_s, v] }.to_h

    # Rails.logger.warn "GC.compact - Top Memory: #{top_mem}"
    # Rails.logger.warn "GC.compact - Top Counts: #{top_count}"
  end

  # Convert a non-negative integer size into a bucket.
  # This simplifies tracking size categories.
  # In Ruby, X...Y includes X but does NOT include Y.
  def self.size_to_bucket(size)
    case size
    when 0...100 then '0...100'
    when 100...1000 then '100...1K'
    when 1000...10_000 then '1K...10K'
    when 10_000...100_000 then '10K...100K'
    else '100K+'
    end
  end

  # Add allocation source info to an entry if available.
  # Returns the source string if found, nil otherwise.
  def add_allocation_source(entry, str, allocation_sources)
    file = ObjectSpace.allocation_sourcefile(str)
    line = ObjectSpace.allocation_sourceline(str)
    return unless file

    source = "#{file}:#{line}"
    entry[:source] = source
    allocation_sources[source] += str.bytesize
    source
  end

  # Log top allocation sources.
  def log_allocation_sources(allocation_sources)
    top_sources = allocation_sources.sort_by { |_, bytes| -bytes }
                                    .first(10)
    Rails.logger.warn "GC.compact - Top allocation sources for large unfrozen strings: #{top_sources.to_h}"
  end

  # Analyze string memory to identify sources of growth
  # The tracing_enabled parameter allows testing without global state.
  # The test_allocation_sources parameter allows injecting sources for testing.
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def report_string_analysis(
    tracing_enabled: GcCompactThread.allocation_tracing_enabled,
    test_allocation_sources: nil
  )
    # Group strings by size ranges
    size_buckets = Hash.new(0)
    frozen_count = 0
    unfrozen_count = 0
    total_frozen_bytes = 0
    total_unfrozen_bytes = 0

    # Sample large strings for inspection
    large_strings = []

    # Track allocation sources for large unfrozen strings
    allocation_sources = Hash.new(0)

    ObjectSpace.each_object(String) do |s|
      size = s.bytesize

      # Bucket by size
      bucket = size_to_bucket(size)
      size_buckets[bucket] += 1

      # Track frozen vs unfrozen
      if s.frozen?
        frozen_count += 1
        total_frozen_bytes += size
      else
        unfrozen_count += 1
        total_unfrozen_bytes += size
      end

      # Collect large strings for inspection (limit to 20)
      next if size <= 50_000 || large_strings.length >= 20

      # Get a safe preview (avoid binary garbage in logs)
      preview = s[0..80].encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
      entry = {
        size: size,
        preview: preview.inspect,
        frozen: s.frozen?
      }

      # Add allocation source if tracing is enabled and string is unfrozen
      add_allocation_source(entry, s, allocation_sources) if tracing_enabled && !s.frozen?

      large_strings << entry
    end

    Rails.logger.warn "GC.compact - String size distribution: #{size_buckets}"
    Rails.logger.warn "GC.compact - Frozen strings: #{frozen_count} " \
                      "(#{total_frozen_bytes / 1_000_000}MB)"
    Rails.logger.warn "GC.compact - Unfrozen strings: #{unfrozen_count} " \
                      "(#{total_unfrozen_bytes / 1_000_000}MB)"

    large_strings.sort_by! { |h| -h[:size] }
    Rails.logger.warn "GC.compact - Large strings (>50KB): #{large_strings}"

    # Report top allocation sources if tracing is enabled
    # Use test_allocation_sources if provided (for deterministic testing)
    sources_to_report = test_allocation_sources || allocation_sources
    return unless tracing_enabled && sources_to_report.any?

    log_allocation_sources(sources_to_report)
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  # Track memory growth between compactions
  # rubocop:disable Metrics/MethodLength
  def report_growth_delta
    current_count = 0
    current_bytes = 0

    ObjectSpace.each_object(String) do |s|
      current_count += 1
      current_bytes += s.bytesize
    end

    count_delta = current_count - GcCompactThread.previous_string_count
    bytes_delta = current_bytes - GcCompactThread.previous_string_bytes
    Rails.logger.warn 'GC.compact - String delta since last: ' \
                      "count #{'+' if count_delta.positive?}#{count_delta}, " \
                      "bytes #{'+' if bytes_delta.positive?}#{bytes_delta}"

    GcCompactThread.previous_string_count = current_count
    GcCompactThread.previous_string_bytes = current_bytes
  end
  # rubocop:enable Metrics/MethodLength

  # Report Rails cache statistics
  def report_cache_stats
    cache = Rails.cache
    data = cache.instance_variable_get(:@data)
    cache_size = cache.instance_variable_get(:@cache_size)
    max_size = cache.instance_variable_get(:@max_size)

    Rails.logger.warn "GC.compact - Cache entries: #{data&.size || 'N/A'}, " \
                      "size: #{cache_size || 'N/A'}, max: #{max_size || 'N/A'}"
  end

  # Detect duplicate large strings (same content as both frozen and unfrozen)
  # This helps identify cache-related duplication issues
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity
  def report_duplicate_analysis
    # Collect large strings (>50KB) grouped by content hash
    large_by_hash = Hash.new { |h, k| h[k] = { frozen: [], unfrozen: [] } }
    content_patterns = Hash.new(0)

    ObjectSpace.each_object(String) do |s|
      size = s.bytesize
      next if size < 50_000

      # Use first 1000 chars as key to group similar strings
      key = s[0, 1000].hash

      if s.frozen?
        large_by_hash[key][:frozen] << size
      else
        large_by_hash[key][:unfrozen] << size
      end

      # Categorize by content pattern
      pattern = categorize_string_content(s)
      content_patterns[pattern] += size
    end

    # Find duplicates (content appearing as both frozen and unfrozen)
    duplicates =
      large_by_hash.select do |_, v|
        v[:frozen].any? && v[:unfrozen].any?
      end

    # Always report duplicate stats (shows 0 if none found)
    dup_count = duplicates.size
    dup_frozen_bytes = duplicates.values.sum { |v| v[:frozen].sum }
    dup_unfrozen_bytes = duplicates.values.sum { |v| v[:unfrozen].sum }
    Rails.logger.warn "GC.compact - DUPLICATE large strings: #{dup_count} unique contents, " \
                      "frozen: #{dup_frozen_bytes / 1_000_000}MB, " \
                      "unfrozen: #{dup_unfrozen_bytes / 1_000_000}MB"

    # Report content patterns
    top_patterns = content_patterns.sort_by { |_, bytes| -bytes }
                                   .first(5)
    Rails.logger.warn "GC.compact - Large string patterns: #{top_patterns.to_h}"
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity

  # Categorize a string by its content pattern
  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength
  def categorize_string_content(str)
    # Classify as 'OTHER' any string whose encoding can't interoperate
    # with US-ASCII regexps (UTF-32LE, UTF-32BE, UTF-16LE, etc.).
    # Most of the time this isn't a problem, but omitting this check will
    # occasionally lead to sudden failures.
    return 'OTHER' unless str.encoding.ascii_compatible?

    preview = str[0, 200]
    case preview
    when /\A<!DOCTYPE html>/i
      lang = preview[/lang="([^"]+)"/, 1] || 'unknown'
      "HTML_DOC_#{lang}"
    when /\A<div>\s*<span id="project_entry_form"/
      'PROJECT_FORM'
    when /<div class="row">.*main-badge/m
      'PROJECT_SHOW'
    when /\A\s*<div class="row">/
      'DIV_ROW'
    when /\A\s*<link rel=/
      'LINK_TAGS'
    when /\A\{/
      'JSON'
    else
      'OTHER'
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def compact_with_logging(mem = nil)
    return unless GC.respond_to?(:compact)

    Rails.logger.warn "GC.compact starting; (#{mem * 1.0 / (2**20)}MiB)" if mem
    stats_before = GC.stat
    # Trigger a full, immediate collection
    GC.start(full_mark: true, immediate_mark: true, immediate_sweep: true)
    # Compact the now-clean heap
    compact_info = GC.compact
    stats_after = GC.stat
    Rails.logger.warn 'GC.compact completed'
    stats_diff = calculate_stats_diff(stats_before, stats_after, compact_info)
    Rails.logger.warn("GC.compact - statistics before: #{stats_before}")
    Rails.logger.warn("GC.compact - statistics afterwards: #{stats_after}")
    Rails.logger.warn("GC.compact - statistics changes: #{stats_diff}")

    report_class_info
    report_string_analysis
    report_growth_delta
    report_cache_stats
    report_duplicate_analysis
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  # Return current memory use in bytes
  # The status_path parameter is primarily for testing the fallback path
  def memory_use_in_bytes(status_path = '/proc/self/status')
    # Slurp file status_path into temp string; it's expected to be smallish.
    # We need to know our total memory use, which is
    # rss (physical memory in use) + swap (memory swapped to storage)
    # File /proc/self/statm would give us rss easily, but not swap space.
    status = File.read(status_path)
    # Pull kB values out via regex
    rss  = status[VM_RSS_RE, 1].to_i
    swap = status[VM_SWAP_RE, 1].to_i

    # Log every memory use check if configured to do so
    # We log from within this method so we can provide the details
    Rails.logger.warn "GC Compacting: rss=#{rss}, swap=#{swap} bytes" if ANNOUNCE_GC_CHECK
    # Return total in bytes
    (rss + swap) * 1024
  rescue StandardError
    # Guesstimate memory from rss alone. This is useful on Macs, etc.
    `ps -o rss= -p #{Process.pid}`.to_i * 1024
  end

  # We originally compacted on a fixed period. However, that compacted
  # when we didn't need to, and it didn't compact soon enough if we did.
  # So instead, we now periodically check memory use, and we compact
  # if the memory use is too much.
  # Compacting takes a while, so once we've done it, we delay much longer
  # before checking again. After all, it's unlikely to help for a while.
  # As a result, we have 2 separate delay times.
  # Instead of `20 * 60` we could use `20.minutes`, but the latter
  # generate special types. Garbage collection is low-level;
  # we want to minimize the objects we create, and what's happening in
  # general here, to maximize the memory we recover.

  # Seconds post memory-ok before recheck
  SLEEP_AFTER_CHECK = (ENV['BADGEAPP_SLEEP_AFTER_CHECK'] || (1 * 60)).to_i
  # Seconds post memory-not-ok before recheck
  SLEEP_AFTER_COMPACT = (ENV['BADGEAPP_SLEEP_AFTER_COMPACT'] || (20 * 60)).to_i

  ANNOUNCE_GC_CHECK = ENV['BADGEAPP_ANNOUNCE_GC_CHECK'].present?

  # Repeated check if memory used is more than max_mem, and if so, compact.
  # The parameters make testing easier.
  # For tests we typically want one_time = true and
  # delay = 0 (in Ruby only false and nil are falsey; 0 is truthy).
  # The raise_exception parameter lets us test the process of
  # handling an exception within the main loop.
  # This isn't a predicate; Rubocop is misled by the name.
  # rubocop:disable Naming/PredicateMethod
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity
  def gc_compact_as_needed(max_mem, one_time = false, delay = nil, raise_exception: false)
    loop do
      begin
        raise StandardError, 'Test exception' if raise_exception

        current_mem = memory_use_in_bytes
        if current_mem <= max_mem
          sleep(delay || SLEEP_AFTER_CHECK)
        else
          compact_with_logging(current_mem)
          sleep(delay || SLEEP_AFTER_COMPACT)
        end
      rescue StandardError => e
        Rails.logger.error "GC compact error: #{e.class}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n") if e.backtrace
        # Exceptions suggest a serious problem. Let's not make things
        # worse by repeatedly doing them aggressively, and hope that the
        # system will manage to right itself over time.
        sleep(delay || SLEEP_AFTER_COMPACT)
      end
      break if one_time
    end
    true
  end
  # rubocop:enable Naming/PredicateMethod
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity

  # Start the background thread that runs GC compaction periodically.
  # Called from config/initializers/gc_compact_thread.rb during app initialization.
  #
  # @return [Thread] The background thread that was created
  def start_background_thread
    # Enable allocation tracing if configured (must be done before allocations)
    enable_allocation_tracing if TRACE_ALLOCATIONS

    Thread.new do
      # By default, compact once we exceed 1GiB
      max_mem = (ENV['BADGEAPP_MEMORY_COMPACTOR_MB'] || 1024).to_i * (2**20)
      current_mem = memory_use_in_bytes
      Rails.logger.warn "GC Compacting thread if > #{max_mem} bytes, currently #{current_mem} bytes"
      Rails.logger.warn 'GC Compacting with allocation tracing enabled' if TRACE_ALLOCATIONS
      gc_compact_as_needed(max_mem)
    end
  end
end
# rubocop:enable Metrics/ModuleLength
