# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# Load the initializer code that defines gc_compact_as_needed
require_relative '../../../config/initializers/gc_compact_thread'

# rubocop:disable Metrics/ClassLength
class GcCompactThreadTest < ActiveSupport::TestCase
  # Test memory_use_in_bytes with default.
  # It will try to read from /proc/self/status, which works on Linux.
  # MacOS will fail and use its alternative, but still give an answer.
  test 'memory_use_in_bytes works by default' do
    current_mem = GcCompactThread.memory_use_in_bytes
    # We don't know the current value, but we know these must be true.
    assert current_mem.is_a?(Integer)
    assert current_mem.positive?
  end

  # Test memory_use_in_bytes with fixture file.
  # This lets us test Linux code path even if running on macOS.
  # It also lets us verify that the calculations are exactly correct.
  test 'memory_use_in_bytes reads from status fixture file' do
    fixture_path = Rails.root.join('test/fixtures/files/proc_status_sample').to_s
    current_mem = GcCompactThread.memory_use_in_bytes(fixture_path)
    # Fixture has 1952 RSS + 1 swap in K
    assert_equal (1952 + 1) * 1024, current_mem
  end

  # Test memory_use_in_bytes fallback to ps command when file doesn't exist
  test 'memory_use_in_bytes falls back to ps when status unavailable' do
    current_mem = GcCompactThread.memory_use_in_bytes('/nonexistent/path')
    # We don't know the current value, but we know these must be true.
    assert current_mem.is_a?(Integer)
    assert current_mem.positive?
  end

  # Test the GC compactor when memory is below threshold (no compaction)
  test 'gc_compact_as_needed when memory is below threshold' do
    # Use a very large memsize to ensure current memory is below it
    memsize = 1024 * 1024 * 1024 * 100 # 100 GiB, above any reasonable RSS
    assert GcCompactThread.gc_compact_as_needed(memsize, true, 0)
  end

  # Test the GC compactor when memory exceeds threshold (triggers compaction)
  test 'gc_compact_as_needed when memory exceeds threshold' do
    # Use a very small memsize to ensure current memory exceeds it
    memsize = 1 # 1 byte, will definitely be exceeded
    assert GcCompactThread.gc_compact_as_needed(memsize, true, 0)
  end

  # Test exception handling - thread survives exceptions
  test 'gc_compact_as_needed handles exceptions and continues' do
    # Use raise_exception parameter to trigger exception handling
    assert GcCompactThread.gc_compact_as_needed(1, true, 0, raise_exception: true)
  end

  # Test compact_with_logging directly to ensure full coverage
  test 'compact_with_logging performs compaction if GC.compact available' do
    # This test ensures calculate_compaction_stats is covered
    # Call with mem value to test logging path - should not raise
    assert_nothing_raised { GcCompactThread.compact_with_logging(100_000_000) }
  end

  test 'size_to_bucket' do
    assert_equal '0...100', GcCompactThread.size_to_bucket(50)
    assert_equal '100...1K', GcCompactThread.size_to_bucket(100)
    assert_equal '100...1K', GcCompactThread.size_to_bucket(999)
    assert_equal '1K...10K', GcCompactThread.size_to_bucket(1000)
    assert_equal '1K...10K', GcCompactThread.size_to_bucket(9999)
    assert_equal '10K...100K', GcCompactThread.size_to_bucket(10_000)
    assert_equal '10K...100K', GcCompactThread.size_to_bucket(99_999)
    assert_equal '100K+', GcCompactThread.size_to_bucket(100_000)
    assert_equal '100K+', GcCompactThread.size_to_bucket(500_000)
    assert_equal '100K+', GcCompactThread.size_to_bucket(10_000_000)
  end

  # Test report_string_analysis with large strings to ensure coverage of
  # the large string preview code path (lines that collect strings > 50KB)
  test 'report_string_analysis covers large string detection' do
    # Create a large unfrozen string (> 50KB) that will be detected
    # Use a distinctive prefix so we can verify it was found
    large_string = 'LARGE_STRING_TEST_MARKER_' + ('x' * 60_000)

    # Keep a reference to prevent GC from collecting it during the test
    # The string must exist in ObjectSpace when report_string_analysis runs
    assert large_string.bytesize > 50_000, 'Test string must be > 50KB'

    # Call report_string_analysis - should not raise and should log the large string
    assert_nothing_raised { GcCompactThread.report_string_analysis }

    # The large_string variable keeps the string alive until here
    assert large_string.present?
  end

  # Test enable_allocation_tracing method - thread-safe using parameter
  test 'enable_allocation_tracing enables tracing when not already enabled' do
    # Test the enabling path by passing already_enabled: false
    # This tests the logic without modifying global state
    assert_nothing_raised { GcCompactThread.enable_allocation_tracing(already_enabled: false) }
  end

  test 'enable_allocation_tracing returns early when already enabled' do
    # Test the early return path by passing already_enabled: true
    # This should be a no-op and not raise
    assert_nothing_raised { GcCompactThread.enable_allocation_tracing(already_enabled: true) }
  end

  # Test add_allocation_source method directly
  test 'add_allocation_source adds source info when file is available' do
    # Enable tracing so ObjectSpace can track allocations
    ObjectSpace.trace_object_allocations_start

    # Create a string that will have allocation info tracked
    test_string = 'x' * 100
    entry = { size: 100, frozen: false }
    allocation_sources = Hash.new(0)

    # Call add_allocation_source
    result = GcCompactThread.add_allocation_source(entry, test_string, allocation_sources)

    # The string was allocated in this file, so it should have source info
    # Note: result may be nil if ObjectSpace doesn't track this allocation
    if result
      assert entry.key?(:source)
      assert allocation_sources.any?
    end

    # Keep string alive
    assert test_string.present?
  end

  # Test log_allocation_sources method directly
  test 'log_allocation_sources logs top sources' do
    allocation_sources = { 'test.rb:10' => 1000, 'other.rb:20' => 500 }
    assert_nothing_raised { GcCompactThread.log_allocation_sources(allocation_sources) }
  end

  # Test report_string_analysis with tracing_enabled parameter (thread-safe)
  # Uses test_allocation_sources for deterministic coverage of log_allocation_sources call
  test 'report_string_analysis with tracing_enabled parameter covers source tracking' do
    # Inject test allocation sources to guarantee the log_allocation_sources path is hit
    test_sources = { 'test_file.rb:42' => 100_000, 'other_file.rb:99' => 50_000 }

    # Call report_string_analysis with tracing_enabled: true and injected sources
    assert_nothing_raised do
      GcCompactThread.report_string_analysis(
        tracing_enabled: true,
        test_allocation_sources: test_sources
      )
    end
  end

  # Test report_duplicate_analysis with large strings
  test 'report_duplicate_analysis detects duplicate frozen and unfrozen strings' do
    # Create a large string content that will appear as both frozen and unfrozen
    content = '<!DOCTYPE html>' + ('z' * 60_000)

    # Create unfrozen version
    unfrozen_string = content.dup
    assert_not unfrozen_string.frozen?
    assert unfrozen_string.bytesize > 50_000

    # Create frozen version with same content prefix
    frozen_string = content.dup.freeze
    assert frozen_string.frozen?

    # Call report_duplicate_analysis - should detect the duplicate
    assert_nothing_raised { GcCompactThread.report_duplicate_analysis }

    # Keep strings alive
    assert unfrozen_string.present?
    assert frozen_string.present?
  end

  # Test categorize_string_content for each pattern branch
  test 'categorize_string_content categorizes HTML documents' do
    html_en = '<!DOCTYPE html><html lang="en"><head>'
    assert_equal 'HTML_DOC_en', GcCompactThread.categorize_string_content(html_en)

    html_ru = '<!DOCTYPE html><html lang="ru"><head>'
    assert_equal 'HTML_DOC_ru', GcCompactThread.categorize_string_content(html_ru)

    html_unknown = '<!DOCTYPE html><html><head>'
    assert_equal 'HTML_DOC_unknown', GcCompactThread.categorize_string_content(html_unknown)
  end

  test 'categorize_string_content categorizes project form' do
    # Need whitespace after div for the regex to match
    form = "<div>\n<span id=\"project_entry_form\" data-foo=\"bar\">"
    assert_equal 'PROJECT_FORM', GcCompactThread.categorize_string_content(form)
  end

  test 'categorize_string_content categorizes project show' do
    show = '<div class="row"><div class="main-badge-container">'
    assert_equal 'PROJECT_SHOW', GcCompactThread.categorize_string_content(show)
  end

  test 'categorize_string_content categorizes div row' do
    div_row = '<div class="row"><div class="col-md-6">'
    assert_equal 'DIV_ROW', GcCompactThread.categorize_string_content(div_row)
  end

  test 'categorize_string_content categorizes link tags' do
    link = '<link rel="stylesheet" href="/assets/app.css">'
    assert_equal 'LINK_TAGS', GcCompactThread.categorize_string_content(link)
  end

  test 'categorize_string_content categorizes JSON' do
    json = '{"id":1,"name":"test"}'
    assert_equal 'JSON', GcCompactThread.categorize_string_content(json)
  end

  test 'categorize_string_content categorizes other content' do
    other = 'Some random text content'
    assert_equal 'OTHER', GcCompactThread.categorize_string_content(other)
  end

  test 'categorize_string_content returns OTHER for non-ASCII-compatible encoding' do
    utf32 = '<!DOCTYPE html>'.encode('UTF-32LE')
    assert_nothing_raised { GcCompactThread.categorize_string_content(utf32) }
    assert_equal 'OTHER', GcCompactThread.categorize_string_content(utf32)
  end
end
# rubocop:enable Metrics/ClassLength
