# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

class I18nTest < ActiveSupport::TestCase
  # Check that basic internationalization (i18n) functionality is working
  test 'i18n sanity check' do
    assert_equal 'Hello world', I18n.t(:hello, locale: :en)
    assert_equal 'Bonjour le monde', I18n.t(:hello, locale: :fr)
    assert_equal '你好，世界', I18n.t(:hello, locale: :'zh-CN')
    assert_equal 'Здравствуй, мир', I18n.t(:hello, locale: :ru)
    assert_equal 'Last translation entry', I18n.t(:last_entry, locale: :en)
  end

  # Test Spanish plural handling for projects_count
  # Spanish uses: one (1), other (0, 2, 3, ...)
  test 'Spanish projects_count pluralization' do
    # Zero projects
    result = I18n.t(:projects_count, count: 0, locale: :es)
    assert result.present?, 'Spanish projects_count should be translated for count=0'

    # One project - should use 'one' form
    result = I18n.t(:projects_count, count: 1, locale: :es)
    assert result.present?, 'Spanish projects_count should be translated for count=1'
    assert result.include?('1'), 'Should include the count'

    # Multiple projects - should use 'other' form
    result = I18n.t(:projects_count, count: 2, locale: :es)
    assert result.present?, 'Spanish projects_count should be translated for count=2'
    assert result.include?('2'), 'Should include the count'

    result = I18n.t(:projects_count, count: 5, locale: :es)
    assert result.present?, 'Spanish projects_count should be translated for count=5'
    assert result.include?('5'), 'Should include the count'

    result = I18n.t(:projects_count, count: 100, locale: :es)
    assert result.present?, 'Spanish projects_count should be translated for count=100'
    assert result.include?('100'), 'Should include the count'
  end

  # Test German plural handling for projects_count
  # German uses: zero (0), one (1), other (2, 3, ...)
  test 'German projects_count pluralization' do
    # Zero projects - should use 'zero' form
    result = I18n.t(:projects_count, count: 0, locale: :de)
    assert_equal 'Keine Projekte', result,
                 'German should have "Keine Projekte" for count=0'

    # One project - should use 'one' form
    result = I18n.t(:projects_count, count: 1, locale: :de)
    assert_equal '1 Projekt', result,
                 'German should have "1 Projekt" (singular) for count=1'

    # Two projects - should use 'other' form (plural)
    result = I18n.t(:projects_count, count: 2, locale: :de)
    assert_equal '2 Projekte', result,
                 'German should have "2 Projekte" (plural) for count=2'

    # Multiple projects - should use 'other' form (plural)
    result = I18n.t(:projects_count, count: 5, locale: :de)
    assert_equal '5 Projekte', result,
                 'German should have "5 Projekte" (plural) for count=5'

    result = I18n.t(:projects_count, count: 100, locale: :de)
    assert_equal '100 Projekte', result,
                 'German should have "100 Projekte" (plural) for count=100'
  end
end
