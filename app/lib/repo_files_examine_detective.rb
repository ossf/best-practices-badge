# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Examine repository files at the top level and in key subdirectories
# (those conventionally used for source and documentation).
# Note that a key precondition is determining how to open repo files.

# rubocop:disable Metrics/ClassLength
class RepoFilesExamineDetective < Detective
  INPUTS = [:repo_files].freeze
  OUTPUTS = %i[
    contribution_status license_location_status release_notes_status
    osps_do_02_01_status osps_gv_03_01_status
    osps_le_03_01_status osps_le_03_02_status
  ].freeze

  # This detective can override file-presence criteria with high confidence
  OVERRIDABLE_OUTPUTS = %i[
    contribution_status license_location_status release_notes_status
    osps_le_03_01_status
  ].freeze

  # Minimum file sizes (in bytes) before they are considered useful.
  # Empty files, in particular, clearly do NOT have enough content.
  NONTRIVIAL_MIN_SIZE = 40
  # Contribution should be longer to be considered useful.
  CONTRIBUTION_MIN_SIZE = 100

  EMPTY = [].freeze

  # Given an enumeration of fso info hashes, return the fso info for files
  # that match the regex name pattern and are at least minimum_size in length.
  # Returns EMPTY when @top_level is nil (GitHub API returned 404).
  def files_named(name_pattern, minimum_size)
    @top_level&.select do |fso|
      fso['type'] == 'file' && fso['name'].match(name_pattern) &&
        fso['size'] >= minimum_size
    end || EMPTY
  end

  # Return first entry iff there's a top-level directory matching name_pattern;
  # if not found, returns nil
  def directory_named(name_pattern)
    @top_level&.find do |fso|
      fso['type'] == 'dir' && fso['name'].match(name_pattern)
    end
  end

  def unmet_result(result_description, confidence: 1)
    {
      value: CriterionStatus::UNMET, confidence: confidence,
      explanation: I18n.t('detectives.repo_files.no_file_found',
                          description: result_description)
    }
  end

  def met_result(result_description, html_url, confidence: 3)
    {
      value: CriterionStatus::MET, confidence: confidence,
      explanation: I18n.t('detectives.repo_files.file_found',
                          description: result_description, url: html_url)
    }
  end

  # @param confidence [Hash] optional :met and :unmet confidence overrides
  def determine_results(
    status, name_pattern, minimum_size, result_description, confidence: {}
  )
    found_files = files_named(name_pattern, minimum_size)
    @results[status] =
      if found_files.empty?
        unmet_result(result_description,
                     confidence: confidence.fetch(:unmet, 1))
      else
        met_result(result_description, found_files.first['html_url'],
                   confidence: confidence.fetch(:met, 3))
      end
  end

  # If a directory found with name_pattern, decide that it's a met_result.
  # We don't check if the directory has any contents, but most projects
  # use git and git will not store an empty directory.
  def override_results_if_dir(status, name_pattern, result_description)
    html_url_directory = directory_named(name_pattern)
    return if html_url_directory.blank?

    @results[status] =
      met_result(result_description, html_url_directory['html_url'])
  end

  # rubocop:disable Metrics/MethodLength
  def analyze(_evidence, current)
    repo_files = current[:repo_files]
    return {} if repo_files.blank?

    @results = {}

    # nil when GitHub returns 404 (empty/private/deleted repo, transient error);
    # an array of fso hashes when the scan succeeded.
    @top_level = repo_files.get_info('/', not_found_result: nil)

    # TODO: Look in subdirectories.

    check_contribution_files
    check_license_files
    check_release_notes
    check_security_md_files

    @results
  end
  # rubocop:enable Metrics/MethodLength

  # Check for contribution files and set both metal and baseline criteria
  def check_contribution_files
    determine_results(
      :contribution_status,
      /\A(contributing|contribute)(\.md|\.txt)?\Z/i,
      CONTRIBUTION_MIN_SIZE, 'contribution'
    )
    set_baseline_contribution_status
  end

  def check_security_md_files
    # SECURITY.md file present?
    determine_results(
      :osps_do_02_01_status,
      /\A(security)(\.md|\.txt)?\Z/i,
      CONTRIBUTION_MIN_SIZE, 'SECURITY[.md] file found'
    )
  end

  # Set baseline contribution criteria if contribution file is met
  def set_baseline_contribution_status
    return unless @results[:contribution_status]&.dig(:value) == CriterionStatus::MET

    confidence = @results[:contribution_status][:confidence]
    @results[:osps_gv_03_01_status] = {
      value: CriterionStatus::MET, confidence: confidence,
      explanation: I18n.t('detectives.repo_files.contribution_documented')
    }
  end

  # Check for license files and set both metal and baseline criteria
  # rubocop:disable Metrics/MethodLength
  def check_license_files
    # Use forced confidence (5) for UNMET only when @top_level is non-empty,
    # confirming we actually scanned the repo and found no license file.
    # An empty @top_level may mean the GitHub API returned 404 for reasons
    # other than genuine absence (empty repo, private repo accessed without
    # auth, transient failure) — in those cases low confidence avoids
    # overriding a valid user-set "Met" value with a spurious "Unmet".
    unmet_confidence = @top_level.nil? ? 1 : 5
    determine_results(
      :license_location_status,
      /\A([A-Za-z0-9]+-)?(license|copying)(\.md|\.txt)?\Z/i,
      NONTRIVIAL_MIN_SIZE, 'license location', confidence: { unmet: unmet_confidence }
    )

    # If there's a LICENSES directory, then license_location probably met.
    override_results_if_dir(
      :license_location_status,
      /\ALICENSES\Z/,
      'licenses directory'
    )

    set_baseline_license_status
  end
  # rubocop:enable Metrics/MethodLength

  # Set baseline license-file-presence criteria if license location is met
  # rubocop:disable Metrics/MethodLength
  def set_baseline_license_status
    if @results[:license_location_status]&.dig(:value) == CriterionStatus::MET
      confidence = @results[:license_location_status][:confidence]
      @results[:osps_le_03_01_status] = {
        value: CriterionStatus::MET, confidence: confidence,
        explanation: I18n.t('detectives.repo_files.license_found')
      }
    else
      license_confidence = @results[:license_location_status][:confidence]
      @results[:osps_le_03_01_status] = {
        value: CriterionStatus::UNMET, confidence: license_confidence,
        explanation: I18n.t('detectives.repo_files.license_not_found')
      }
      @results[:osps_le_03_02_status] = {
        value: CriterionStatus::UNMET, confidence: 2,
        explanation: I18n.t('detectives.repo_files.license_not_in_releases')
      }
    end
  end
  # rubocop:enable Metrics/MethodLength

  # Check for release notes files
  def check_release_notes
    determine_results(
      :release_notes_status,
      /\A(changelog|news)(\.md|\.markdown|\.txt|\.html)?\Z/i,
      NONTRIVIAL_MIN_SIZE, 'release notes'
    )
  end
end
# rubocop:enable Metrics/ClassLength
