# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# Test that test environment is configured correctly for testing
class TestEnvironmentConfigurationTest < ActiveSupport::TestCase
  test 'test environment disables force_ssl' do
    # This ensures HTTPS redirects don't interfere with tests
    assert_equal false, Rails.configuration.force_ssl,
                 'force_ssl should be false in test environment'
  end

  test 'system defaults to English locale' do
    # I18n.default_locale should be :en (set in initializers/i18n.rb)
    assert_equal :en, I18n.default_locale,
                 'Default locale should be English'
  end

  test 'LocaleUtils.find_best_locale returns English when no browser preference' do
    # Create a mock request with no Accept-Language header
    request = ActionDispatch::TestRequest.create

    # Should fall back to I18n.default_locale which is :en
    locale = LocaleUtils.find_best_locale(request)
    assert_equal :en, locale,
                 'find_best_locale should return :en when no Accept-Language header'
  end

  test 'LocaleUtils.find_best_locale respects browser French preference' do
    # When browser explicitly requests French, and French is in automatic_locales,
    # the system should honor that request
    request = ActionDispatch::TestRequest.create
    request.env['HTTP_ACCEPT_LANGUAGE'] = 'fr-FR,fr;q=0.9'

    locale = LocaleUtils.find_best_locale(request)
    assert_equal :fr, locale,
                 'find_best_locale should return :fr when browser requests French'
  end

  test 'LocaleUtils.find_best_locale falls back to English for unsupported locale' do
    # When the browser requests a locale not in available_locales at all,
    # fall back to English. This will only be checked when the URL
    # doesn't specify a (known) locale.
    #
    # First, create a request object
    request = ActionDispatch::TestRequest.create
    # Include a request for Icelandic, which is not (currently) supported.
    # If we later add an Icelandic translation, then (1) that's amazing and
    # (2) we'll need to change this test to use a different locale.
    # I would like to have that problem :-).
    request.env['HTTP_ACCEPT_LANGUAGE'] = 'is-IS,is;q=0.9'

    locale = LocaleUtils.find_best_locale(request)
    assert_equal :en, locale,
                 'find_best_locale should return :en for unsupported locale (Icelandic)'
  end
end
