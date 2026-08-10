# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

class BadgeTest < ActiveSupport::TestCase
  test 'Badge should have 206 instances' do
    # 100 percentages (0-99) + 3 metal levels + 3 baseline levels
    # + 100 baseline percentages = 206
    assert_equal 206, Badge.count
  end

  test 'First badge should be 0%' do
    assert_equal '0%', Badge.first.to_s[-19..-18]
  end

  test '88% Badge matches fixture file' do
    assert_equal contents('badge-88.svg'), Badge[88].to_s
  end

  test 'passing Badge matches fixture file' do
    assert_equal contents('badge-passing.svg'), Badge['passing'].to_s
  end

  test ' silver badge matches silver from fixture file' do
    assert_equal contents('badge-silver.svg'), Badge['silver'].to_s
  end

  test ' gold badge matches gold from fixture file' do
    assert_equal contents('badge-gold.svg'), Badge['gold'].to_s
  end

  test 'baseline-1 badge is valid and contains expected text' do
    badge = Badge['baseline-1']
    assert badge.to_s.include?('>1<')
    assert badge.to_s.include?('openssf baseline')
  end

  test 'baseline-2 badge is valid and contains expected text' do
    badge = Badge['baseline-2']
    assert badge.to_s.include?('>2<')
    assert badge.to_s.include?('openssf baseline')
  end

  test 'baseline-3 badge is valid and contains expected text' do
    badge = Badge['baseline-3']
    assert badge.to_s.include?('>3<')
    assert badge.to_s.include?('openssf baseline')
  end

  test 'baseline-pct-42 badge is valid and contains expected text' do
    badge = Badge['baseline-pct-42']
    assert badge.to_s.include?('42%')
    assert badge.to_s.include?('openssf baseline')
  end

  test 'baseline-pct-0 badge is valid and contains expected text' do
    badge = Badge['baseline-pct-0']
    assert badge.to_s.include?('0%')
    assert badge.to_s.include?('openssf baseline')
  end

  test 'Badge requires integer < 100 parameters' do
    assert_raise(ArgumentError) { Badge[5.5] }
    assert_raise(ArgumentError) { Badge[100] }
  end

  test 'Badge.width returns correct width for passing badge' do
    assert_equal 184, Badge.width('passing')
  end

  test 'Badge.width returns plausible width for baseline-1 badge' do
    assert_includes (200..300), Badge.width('baseline-1')
  end

  test 'Badge.width returns plausible width for baseline percentage badge' do
    assert_includes (200..300), Badge.width('baseline-pct-42')
  end

  test 'Badge.badge_widths returns widths for all badges' do
    widths = Badge.badge_widths
    assert_equal 206, widths.length
    assert(widths.values.all? { |w| w.is_a?(Integer) && w.positive? })
  end

  test 'Badge.reset_widths! clears cached widths' do
    # Access widths to cache them
    Badge.badge_widths
    # Reset the cache
    Badge.reset_widths!
    # Access again - should still work (rebuilds cache)
    widths = Badge.badge_widths
    assert_equal 206, widths.length
  end

  test 'read_svg_file returns empty string for non-existent file' do
    # Test the rescue clause for missing files
    result = Badge.send(:read_svg_file, 'nonexistent-badge-level')
    assert_equal '', result
  end
end
