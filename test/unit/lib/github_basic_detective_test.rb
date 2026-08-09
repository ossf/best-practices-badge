# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

class GithubBasicDetectiveTest < ActiveSupport::TestCase
  setup do
    @full_name = 'ciitest/test-repo'
    @repo_name = 'test-repo'
    @description = 'This is for testing the OpenSSF Best Practices BadgeApp'
    @evidence = Evidence.new({})
    @repo_url = "https://github.com/#{@full_name}"
  end

  # rubocop:disable Metrics/BlockLength
  test 'Mocked GitHub retrieves name, description (no emojis), and license' do
    VCR.use_cassette('unit_test_github_basic_detective') do
      detective = GithubBasicDetective.new
      results = detective.analyze(@evidence, repo_url: @repo_url)

      assert results.key?(:name)
      assert results[:name].key?(:value)
      assert_equal @repo_name, results[:name][:value]

      assert results.key?(:description)
      assert results[:description].key?(:value)
      assert_equal @description, results[:description][:value]

      assert results.key?(:license)
      assert results[:license].key?(:value)
      assert_equal 'MIT', results[:license][:value]

      # Did we correctly determine the implementation language of our
      # stub test project by ciitest?
      assert_equal 'Python', results[:implementation_languages][:value]

      # Do several unit tests of language_cleanup, it's more complex.
      # This does not invoke network calls, we are directly providing
      # test values to more thoroughly test the method language_cleanup.
      assert_equal '', detective.language_cleanup({})
      assert_equal 'C', detective.language_cleanup(C: 1000) # singleton
      # We need to use the older hash syntax to spell some names
      # rubocop:disable Style/HashSyntax
      assert_equal 'C++, C', detective.language_cleanup( # actually sorts
        C: 1000, :'C++' => 5000
      )
      assert_equal 'C#, JavaScript', detective.language_cleanup(
        HTML: 1000, :'C#' => 5000, JavaScript: 800
      )
      # This is the list from https://api.github.com/repos/
      # assimilation/assimilation-official/languages
      assert_equal 'Python, C, Shell, C++, CMake, C#, Ruby',
                   detective.language_cleanup(
                     Python: 1_151_127,
                     C: 1_059_779,
                     Shell: 285_358,
                     :'C++' => 44_086,
                     CMake: 33_855,
                     :'C#' => 29_834,
                     HTML: 2_290,
                     Ruby: 1_359
                   )
      # rubocop:enable Style/HashSyntax
    end
  end
  # rubocop:enable Metrics/BlockLength
end
