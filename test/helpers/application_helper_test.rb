# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase
  # Test cache_frozen when caching is disabled (line 82: yield)
  test 'cache_frozen yields block when caching disabled' do
    # Stub controller to report caching is disabled
    stub_controller = Object.new
    # rubocop:disable Naming/PredicateMethod
    def stub_controller.perform_caching
      false
    end
    # rubocop:enable Naming/PredicateMethod

    def stub_controller.respond_to?(method)
      method == :perform_caching
    end

    @controller = stub_controller

    result = nil
    cache_frozen('test_cache_frozen_disabled') do
      result = 'executed'
      'block_return_value'
    end

    assert_equal 'executed', result
  end

  # Test cache_frozen_if when condition is true (line 90: cache_frozen call)
  test 'cache_frozen_if calls cache_frozen when condition is true' do
    # Stub controller to make caching disabled for simpler test
    stub_controller = Object.new
    # rubocop:disable Naming/PredicateMethod
    def stub_controller.perform_caching
      false
    end
    # rubocop:enable Naming/PredicateMethod

    def stub_controller.respond_to?(method)
      method == :perform_caching
    end

    @controller = stub_controller

    executed = false

    # When condition is true, should call cache_frozen (which yields with caching off)
    cache_frozen_if(true, 'test_cache_frozen_if_true') do
      executed = true
      'content'
    end

    assert executed, 'Block should execute when condition is true'
  end

  # Test cache_frozen_unless delegates to cache_frozen_if (line 99)
  test 'cache_frozen_unless caches when condition is false' do
    # Stub controller to report caching is disabled for simpler test
    stub_controller = Object.new
    # rubocop:disable Naming/PredicateMethod
    def stub_controller.perform_caching
      false
    end
    # rubocop:enable Naming/PredicateMethod

    def stub_controller.respond_to?(method)
      method == :perform_caching
    end

    @controller = stub_controller

    result = nil
    cache_frozen_unless(false, 'test_cache_frozen_unless_false') do
      result = 'executed'
      'block_return_value'
    end

    assert_equal 'executed', result

    result2 = nil
    cache_frozen_unless(true, 'test_cache_frozen_unless_true') do
      result2 = 'should_execute'
      'block_return_value'
    end

    assert_equal 'should_execute', result2
  end
end
