# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

class CriterionStatusTest < ActiveSupport::TestCase
  test 'parse accepts canonical names case-insensitively' do
    assert_equal CriterionStatus::MET, CriterionStatus.parse('Met')
    assert_equal CriterionStatus::MET, CriterionStatus.parse('met')
    assert_equal CriterionStatus::MET, CriterionStatus.parse('MET')

    assert_equal CriterionStatus::UNMET, CriterionStatus.parse('Unmet')
    assert_equal CriterionStatus::UNMET, CriterionStatus.parse('unmet')
    assert_equal CriterionStatus::UNMET, CriterionStatus.parse('UNMET')

    assert_equal CriterionStatus::NA, CriterionStatus.parse('N/A')
    assert_equal CriterionStatus::NA, CriterionStatus.parse('n/a')

    assert_equal CriterionStatus::UNKNOWN, CriterionStatus.parse('?')
    assert_equal CriterionStatus::UNKNOWN, CriterionStatus.parse('unknown')
  end

  test 'parse accepts aliases' do
    # N/A aliases
    assert_equal CriterionStatus::NA, CriterionStatus.parse('na')
    assert_equal CriterionStatus::NA, CriterionStatus.parse('NA')
    assert_equal CriterionStatus::NA, CriterionStatus.parse('n/a')

    # Unknown aliases
    assert_equal CriterionStatus::UNKNOWN, CriterionStatus.parse('?')
    assert_equal CriterionStatus::UNKNOWN, CriterionStatus.parse('unknown')
    assert_equal CriterionStatus::UNKNOWN, CriterionStatus.parse('UNKNOWN')
  end

  test 'parse strips whitespace' do
    assert_equal CriterionStatus::MET, CriterionStatus.parse('  met  ')
    assert_equal CriterionStatus::NA, CriterionStatus.parse("\tn/a\n")
  end

  test 'parse returns nil for invalid values' do
    assert_nil CriterionStatus.parse('invalid')
    assert_nil CriterionStatus.parse('yes')
    assert_nil CriterionStatus.parse('no')
    assert_nil CriterionStatus.parse('123')
    assert_nil CriterionStatus.parse('')
    assert_nil CriterionStatus.parse('   ')
  end

  test 'parse returns nil for non-string input' do
    assert_nil CriterionStatus.parse(nil)
    assert_nil CriterionStatus.parse(3)
    assert_nil CriterionStatus.parse([])
  end

  test 'canonical returns correct string for integer' do
    assert_equal '?', CriterionStatus.canonical(0)
    assert_equal 'Unmet', CriterionStatus.canonical(1)
    assert_equal 'N/A', CriterionStatus.canonical(2)
    assert_equal 'Met', CriterionStatus.canonical(3)
  end

  test 'canonical returns nil for invalid integers' do
    assert_nil CriterionStatus.canonical(-1)
    assert_nil CriterionStatus.canonical(4)
    assert_nil CriterionStatus.canonical(100)
    assert_nil CriterionStatus.canonical(nil)
  end

  test 'parse and canonical round-trip correctly' do
    ['met', 'unmet', 'n/a', '?', 'unknown', 'na'].each do |input|
      int_value = CriterionStatus.parse(input)
      canonical = CriterionStatus.canonical(int_value)
      assert_not_nil canonical, "Expected #{input} to parse to valid integer"

      # Parse canonical form should return same integer
      reparsed = CriterionStatus.parse(canonical)
      assert_equal int_value, reparsed,
                   "Round-trip failed: #{input} -> #{int_value} -> #{canonical} -> #{reparsed}"
    end
  end

  test 'canonicalize converts to canonical string for query strings' do
    # Query strings allow ALL values including "?" (user can reset status)
    assert_equal 'Met', CriterionStatus.canonicalize('met')
    assert_equal 'Met', CriterionStatus.canonicalize('MET')
    assert_equal 'Unmet', CriterionStatus.canonicalize('unmet')
    assert_equal 'N/A', CriterionStatus.canonicalize('n/a')
    assert_equal 'N/A', CriterionStatus.canonicalize('na')
    assert_equal '?', CriterionStatus.canonicalize('?')
    assert_equal '?', CriterionStatus.canonicalize('unknown')
    assert_nil CriterionStatus.canonicalize('invalid')
  end

  test 'canonicalize_for_automation rejects UNKNOWN' do
    # JSON automation ignores "?" - it provides no automation value
    assert_equal 'Met', CriterionStatus.canonicalize_for_automation('met')
    assert_equal 'Unmet', CriterionStatus.canonicalize_for_automation('unmet')
    assert_equal 'N/A', CriterionStatus.canonicalize_for_automation('n/a')
    assert_equal 'N/A', CriterionStatus.canonicalize_for_automation('na')

    # These are rejected for automation
    assert_nil CriterionStatus.canonicalize_for_automation('?')
    assert_nil CriterionStatus.canonicalize_for_automation('unknown')
    assert_nil CriterionStatus.canonicalize_for_automation('invalid')
  end
end
