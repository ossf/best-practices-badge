# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# CII Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

class NameFromUrlDetectiveTest < ActiveSupport::TestCase
  setup do
    @evidence = Evidence.new({})
  end

  test 'Simple name in project URL domain name is detected' do
    results = NameFromUrlDetective.new.analyze(
      @evidence, homepage_url: 'http://www.sendmail.com'
    )

    assert results.key?(:name)
    assert results[:name].key?(:value)
    assert_equal 'sendmail', results[:name][:value]
    assert_equal 1, results[:name][:confidence]
  end

  test 'Simple name in project URL tail is detected' do
    results = NameFromUrlDetective.new.analyze(
      @evidence, homepage_url: 'http://www.dwheeler.com/flawfinder'
    )

    assert results.key?(:name)
    assert results[:name].key?(:value)
    assert_equal 'flawfinder', results[:name][:value]
    assert_equal 1, results[:name][:confidence]
  end

  test 'Simple name in repo URL tail is detected' do
    results = NameFromUrlDetective.new.analyze(
      @evidence,
      repo_url: 'https://github.com/ossf/best-practices-badge'
    )

    assert results.key?(:name)
    assert results[:name].key?(:value)
    assert_equal 'best-practices-badge', results[:name][:value]
    assert_equal 1, results[:name][:confidence]
  end
end
