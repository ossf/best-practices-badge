# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

class RepoFilesExamineDetectiveTest < ActiveSupport::TestCase
  # Mock the file request system.
  class MockRepoFilesLicenses
    def get_info(_pattern, **)
      [
        {
          name: 'LICENSES', type: 'dir', html_url: './LICENSES/'
        }.with_indifferent_access
      ]
    end

    @octokit_client = true # anything other than nil
  end

  # Mock repo_files that simulates a 404 (empty repo, private repo, etc.).
  # Mirrors GithubContentAccess#get_info behaviour: returns not_found_result,
  # which is nil when the detective passes not_found_result: nil.
  class MockEmptyRepoFiles
    def blank?
      false
    end

    def get_info(_path, not_found_result: [])
      not_found_result
    end
  end

  # Mock repo with a LICENSE file at root (common layout).
  class MockRepoFilesLicenseFile
    def get_info(_pattern, **)
      [
        {
          name: 'LICENSE', type: 'file', size: 11_340, html_url: './LICENSE'
        }.with_indifferent_access
      ]
    end
  end

  # Mock repo with BOTH a LICENSE file AND a LICENSES/ directory (REUSE-style),
  # matching the layout that triggered issue #2818 (e.g. camelot-os/sentry-kernel).
  class MockRepoFilesLicenseBoth
    def get_info(_pattern, **)
      [
        {
          name: 'LICENSE', type: 'file', size: 11_340, html_url: './LICENSE'
        }.with_indifferent_access,
        {
          name: 'LICENSES', type: 'dir', html_url: './LICENSES/'
        }.with_indifferent_access
      ]
    end
  end

  # Mock a non-empty repo that has files but no license (README only).
  class MockRepoFilesNoLicense
    def get_info(_pattern, **)
      [
        {
          name: 'README.md', type: 'file', size: 500, html_url: './README.md'
        }.with_indifferent_access
      ]
    end
  end

  test 'empty repo returns unmet results without crashing' do
    repo_files = MockEmptyRepoFiles.new
    results = RepoFilesExamineDetective.new.analyze(nil, repo_files: repo_files)

    assert results.key?(:contribution_status)
    assert_equal CriterionStatus::UNMET, results[:contribution_status][:value]
    assert results.key?(:license_location_status)
    assert_equal CriterionStatus::UNMET, results[:license_location_status][:value]
    assert results.key?(:release_notes_status)
    assert_equal CriterionStatus::UNMET, results[:release_notes_status][:value]
  end

  test 'empty repo does not force license unmet (confidence below override threshold)' do
    # An empty @top_level may mean API failure, private repo, or transient 404 —
    # not necessarily genuine absence of a license. Use low confidence so we do
    # NOT override a user-set "Met" value with a spurious automated "Unmet".
    repo_files = MockEmptyRepoFiles.new
    results = RepoFilesExamineDetective.new.analyze(nil, repo_files: repo_files)

    assert_equal CriterionStatus::UNMET, results[:license_location_status][:value]
    assert_operator results[:license_location_status][:confidence], :<,
                    Chief::CONFIDENCE_OVERRIDE,
                    'Empty @top_level must NOT produce a forced (>= CONFIDENCE_OVERRIDE) unmet result'
    assert_operator results[:osps_le_03_01_status][:confidence], :<,
                    Chief::CONFIDENCE_OVERRIDE,
                    'osps_le_03_01_status must not be forced when API result is ambiguous'
  end

  test 'LICENSES directory probably has licenses' do
    file_mock = MockRepoFilesLicenses.new
    results = RepoFilesExamineDetective.new.analyze(nil, repo_files: file_mock)

    assert results.key?(:license_location_status)
    assert results[:license_location_status].key?(:value)
    assert results[:license_location_status][:value] == CriterionStatus::MET
    assert results[:license_location_status][:confidence] == 3
  end

  test 'LICENSE file at repo root is detected as met' do
    file_mock = MockRepoFilesLicenseFile.new
    results = RepoFilesExamineDetective.new.analyze(nil, repo_files: file_mock)

    assert results.key?(:license_location_status)
    assert_equal CriterionStatus::MET, results[:license_location_status][:value]
  end

  test 'LICENSE file with LICENSES directory (REUSE-style) is detected as met' do
    # Regression test for issue #2818: projects using REUSE (LICENSES/ dir) AND
    # a top-level LICENSE file must be detected as met. The LICENSES/ directory
    # must not downgrade or interfere with the file-based MET result.
    file_mock = MockRepoFilesLicenseBoth.new
    results = RepoFilesExamineDetective.new.analyze(nil, repo_files: file_mock)

    assert results.key?(:license_location_status)
    assert_equal CriterionStatus::MET, results[:license_location_status][:value]
  end

  test 'non-empty repo without any license file uses forced unmet confidence' do
    # When the API returns repo contents but we find no license, we can assert
    # with high (forced) confidence that the license criterion is unmet.
    file_mock = MockRepoFilesNoLicense.new
    results = RepoFilesExamineDetective.new.analyze(nil, repo_files: file_mock)

    assert_equal CriterionStatus::UNMET, results[:license_location_status][:value]
    assert_operator results[:license_location_status][:confidence], :>=,
                    Chief::CONFIDENCE_OVERRIDE,
                    'Non-empty repo with no license should use forced confidence'
    assert_operator results[:osps_le_03_01_status][:confidence], :>=,
                    Chief::CONFIDENCE_OVERRIDE,
                    'osps_le_03_01_status should be forced when API confirmed no license'
  end
end
