# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# rubocop:disable Metrics/ClassLength
class RepoJsonDetectiveTest < ActiveSupport::TestCase
  # Mock for repo_files that returns JSON content
  class MockRepoFiles
    attr_accessor :primary_content, :fallback_content

    def initialize(primary_content: nil, fallback_content: nil)
      @primary_content = primary_content
      @fallback_content = fallback_content
    end

    def blank?
      false
    end

    # rubocop:disable Lint/UnusedMethodArgument
    def get_content(path, max_size:)
      # rubocop:enable Lint/UnusedMethodArgument
      return @primary_content if path == '.bestpractices.json' && @primary_content
      return @fallback_content if path == '.project.d/bestpractices.json' && @fallback_content

      nil
    end
  end

  test 'returns empty hash when repo_files is blank' do
    detective = RepoJsonDetective.new
    result = detective.analyze(nil, {})
    assert_equal({}, result)
  end

  test 'processes valid status with JSON justification' do
    json_content = {
      'contribution_status' => 'Met',
      'contribution_justification' => 'See CONTRIBUTING.md'
    }.to_json

    repo_files = MockRepoFiles.new(primary_content: json_content)
    detective = RepoJsonDetective.new

    result = detective.analyze(nil, { repo_files: repo_files })

    assert result.key?(:contribution_status)
    assert_equal CriterionStatus::MET, result[:contribution_status][:value]
    assert_equal 3.5, result[:contribution_status][:confidence]
    assert_equal 'See CONTRIBUTING.md', result[:contribution_status][:explanation]
  end

  test 'uses generic explanation when no JSON justification provided' do
    json_content = { 'contribution_status' => 'Met' }.to_json

    repo_files = MockRepoFiles.new(primary_content: json_content)
    detective = RepoJsonDetective.new

    result = detective.analyze(nil, { repo_files: repo_files })

    assert result.key?(:contribution_status)
    assert_match(/bestpractices/, result[:contribution_status][:explanation])
  end

  test 'handles case-insensitive status values' do
    json_content = {
      'contribution_status' => 'met',
      'license_location_status' => 'UNMET',
      'build_status' => 'N/a'
    }.to_json

    repo_files = MockRepoFiles.new(primary_content: json_content)
    detective = RepoJsonDetective.new

    result = detective.analyze(nil, { repo_files: repo_files })

    assert_equal CriterionStatus::MET, result[:contribution_status][:value]
    assert_equal CriterionStatus::UNMET, result[:license_location_status][:value]
    assert_equal CriterionStatus::NA, result[:build_status][:value]
  end

  test 'ignores question mark status values' do
    json_content = {
      'contribution_status' => '?',
      'contribution_justification' => 'This should be ignored',
      'license_location_status' => 'Met'
    }.to_json

    repo_files = MockRepoFiles.new(primary_content: json_content)
    detective = RepoJsonDetective.new

    result = detective.analyze(nil, { repo_files: repo_files })

    assert_not result.key?(:contribution_status)
    assert result.key?(:license_location_status)
  end

  test 'ignores unknown status values for automation' do
    # JSON automation: 'unknown' means "I don't know" - provides no value
    json_content = {
      'contribution_status' => 'unknown',
      'contribution_justification' => 'This should be ignored',
      'license_location_status' => 'Met'
    }.to_json

    repo_files = MockRepoFiles.new(primary_content: json_content)
    detective = RepoJsonDetective.new

    result = detective.analyze(nil, { repo_files: repo_files })

    assert_not result.key?(:contribution_status),
               'JSON "unknown" status should be ignored (no automation value)'
    assert result.key?(:license_location_status)
  end

  test 'ignores empty status values' do
    json_content = {
      'contribution_status' => '',
      'license_location_status' => '  '
    }.to_json

    repo_files = MockRepoFiles.new(primary_content: json_content)
    detective = RepoJsonDetective.new

    result = detective.analyze(nil, { repo_files: repo_files })

    assert_equal({}, result)
  end

  test 'ignores invalid status values' do
    json_content = {
      'contribution_status' => 'invalid',
      'license_location_status' => 'Met'
    }.to_json

    repo_files = MockRepoFiles.new(primary_content: json_content)
    detective = RepoJsonDetective.new

    result = detective.analyze(nil, { repo_files: repo_files })

    assert_not result.key?(:contribution_status)
    assert result.key?(:license_location_status)
  end

  test 'ignores invalid field names' do
    json_content = {
      'contribution_status' => 'Met',
      'invalid_field_status' => 'Met',
      'another_invalid' => 'Some value'
    }.to_json

    repo_files = MockRepoFiles.new(primary_content: json_content)
    detective = RepoJsonDetective.new

    result = detective.analyze(nil, { repo_files: repo_files })

    assert result.key?(:contribution_status)
    assert_not result.key?(:invalid_field_status)
    assert_not result.key?(:another_invalid)
  end

  test 'processes standalone justification field' do
    json_content = {
      'contribution_justification' => 'Some standalone justification'
    }.to_json

    repo_files = MockRepoFiles.new(primary_content: json_content)
    detective = RepoJsonDetective.new

    result = detective.analyze(nil, { repo_files: repo_files })

    assert result.key?(:contribution_justification)
    assert_equal 'Some standalone justification', result[:contribution_justification][:value]
    assert_equal 3.5, result[:contribution_justification][:confidence]
  end

  test 'tries fallback location when primary not found' do
    json_content = { 'contribution_status' => 'Met' }.to_json

    repo_files = MockRepoFiles.new(fallback_content: json_content)
    detective = RepoJsonDetective.new

    result = detective.analyze(nil, { repo_files: repo_files })

    assert result.key?(:contribution_status)
  end

  test 'returns empty when file not found in either location' do
    repo_files = MockRepoFiles.new
    detective = RepoJsonDetective.new

    result = detective.analyze(nil, { repo_files: repo_files })

    assert_equal({}, result)
  end

  test 'returns empty when JSON is invalid' do
    invalid_json = '{ invalid json content'

    repo_files = MockRepoFiles.new(primary_content: invalid_json)
    detective = RepoJsonDetective.new

    result = detective.analyze(nil, { repo_files: repo_files })

    assert_equal({}, result)
  end

  test 'returns empty when content is not UTF-8' do
    # Create invalid UTF-8 string
    invalid_utf8 = "\xFF\xFE{ }".dup.force_encoding('UTF-8')

    repo_files = MockRepoFiles.new(primary_content: invalid_utf8)
    detective = RepoJsonDetective.new

    result = detective.analyze(nil, { repo_files: repo_files })

    assert_equal({}, result)
  end

  # Security: valid JSON that is not an object (array, scalar, string, bool,
  # null) must be rejected cleanly. Without the is_a?(Hash) guard these raise
  # NoMethodError (e.g. Integer#each, Integer#to_sym), relying on Chief's outer
  # rescue; the detective should be safe on its own.
  test 'returns empty for non-object top-level JSON' do
    detective = RepoJsonDetective.new
    [
      '[1,2,3]', '123', '"a string"', 'true', 'null',
      '[["contribution_status","Met"]]'
    ].each do |raw|
      repo_files = MockRepoFiles.new(primary_content: raw)
      result = detective.analyze(nil, { repo_files: repo_files })
      assert_equal({}, result, "expected {} for top-level JSON #{raw}")
    end
  end

  test 'processes multiple fields with mixed validity' do
    json_content = {
      'contribution_status' => 'Met',
      'contribution_justification' => 'Valid justification',
      'license_location_status' => '?',
      'build_status' => 'invalid',
      'invalid_field' => 'Met',
      'release_notes_status' => 'Unmet'
    }.to_json

    repo_files = MockRepoFiles.new(primary_content: json_content)
    detective = RepoJsonDetective.new

    result = detective.analyze(nil, { repo_files: repo_files })

    # Should include valid fields
    assert result.key?(:contribution_status)
    assert result.key?(:release_notes_status)

    # Should exclude invalid fields
    assert_not result.key?(:license_location_status) # '?' ignored
    assert_not result.key?(:build_status) # invalid value
    assert_not result.key?(:invalid_field) # invalid field name

    # Check justification handling
    assert_equal 'Valid justification', result[:contribution_status][:explanation]
  end
end
# rubocop:enable Metrics/ClassLength
