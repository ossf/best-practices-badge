# frozen_string_literal: true

# Copyright the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# Test class to include the concern for testing
class LevelConversionTestClass
  include LevelConversion
end

class LevelConversionTest < ActiveSupport::TestCase
  setup do
    @converter = LevelConversionTestClass.new
  end

  test 'converts baseline-1 to 1' do
    assert_equal 1, @converter.level_to_number('baseline-1')
  end

  test 'converts baseline-2 to 2' do
    assert_equal 2, @converter.level_to_number('baseline-2')
  end

  test 'converts baseline-3 to 3' do
    assert_equal 3, @converter.level_to_number('baseline-3')
  end

  test 'fallback converts unknown string to integer' do
    assert_equal 5, @converter.level_to_number('5')
    assert_equal 0, @converter.level_to_number('unknown')
  end

  test 'converts standard levels correctly' do
    assert_equal 0, @converter.level_to_number('0')
    assert_equal 0, @converter.level_to_number('passing')
    assert_equal 1, @converter.level_to_number('1')
    assert_equal 1, @converter.level_to_number('silver')
    assert_equal 2, @converter.level_to_number('2')
    assert_equal 2, @converter.level_to_number('gold')
  end
end
