# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# CII Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# rubocop:disable Metrics/ClassLength
class ChiefTest < ActiveSupport::TestCase
  # Use the same field sets as production (computed from Criteria at load time).
  # Keys: '0' = passing, '1' = silver, '2' = gold, 'baseline-1', etc.
  FIELDS = ProjectsController::FIELDS_BY_SECTION

  setup do
    @full_name = 'linuxfoundation/cii-best-practices-badge'
    @repo_name = 'best-practices-badge'
    @description = '🏆Open Source Security Foundation (OpenSSF)' \
                   ' Best Practices Badge (formerly Core Infrastructure Initiative (CII) Best Practices Badge)'

    @sample_project = Project.new
    @sample_project[:repo_url] = "https://github.com/#{@full_name}"
  end

  # rubocop:disable Metrics/BlockLength
  test 'OpenSSF badge results correct' do
    new_chief = Chief.new(@sample_project, proc { Octokit::Client.new })
    VCR.use_cassette('github') do
      new_chief.autofill
    end
    results = @sample_project

    # skip 'Temporarily skip while debugging website problem.'
    mit_ok = 'The MIT license is approved by the Open Source Initiative (OSI).'
    assert_equal 'MIT', results[:license]
    assert_equal @repo_name, results[:name]
    assert_equal @description, results[:description]
    # Phase 3: Detectives return integers, and columns now store integers
    assert_equal CriterionStatus::MET, results[:floss_license_status]
    assert_equal mit_ok, results[:floss_license_justification]
    assert_equal CriterionStatus::MET, results[:floss_license_osi_status]
    assert_equal mit_ok, results[:floss_license_osi_justification]
    assert_equal CriterionStatus::MET, results[:contribution_status]
    assert_equal 'Non-trivial contribution file in repository: <https://github.com/ossf/best-practices-badge/blob/main/CONTRIBUTING.md>.',
                 results[:contribution_justification]
    assert_equal CriterionStatus::MET, results[:release_notes_status]
    assert_equal 'Non-trivial release notes file in repository: ' \
                 '<https://github.com/ossf/' \
                 'best-practices-badge/blob/main/CHANGELOG.md>.',
                 results[:release_notes_justification]
    assert_equal CriterionStatus::MET, results[:build_status]
    assert_equal 'Non-trivial build file in repository: ' \
                 '<https://github.com/ossf/' \
                 'best-practices-badge/blob/main/Rakefile>.',
                 results[:build_justification]
    assert_equal 'Ruby, JavaScript, Shell, SCSS, Dockerfile, Makefile, Procfile',
                 results[:implementation_languages]
    # BaselineDetective should detect license declaration via Chief pipeline
    assert_equal CriterionStatus::MET, results[:osps_le_02_01_status],
                 'FlossLicenseDetective should set osps_le_02_01 for OSI license'
  end
  # rubocop:enable Metrics/BlockLength

  # Create special exception that happens nowhere else.  That way if
  # a *different* exception happens we don't accidentally pass the test.
  class WeirdException1 < StandardError
  end

  # Mock a detective who always fails
  class BadRepoFilesExamineDetective1 < RepoFilesExamineDetective
    def analyze(_, _)
      raise WeirdException1,
            'Exception of BadRepoFilesExamineDetective', caller
    end
  end

  test 'Fatal exceptions in a Detective will not crash production system' do
    old_environment = ENV.fetch('RAILS_ENV', nil)
    # TEMPORARILY make this a 'production' environment (it isn't really)
    ENV['RAILS_ENV'] = 'production'

    new_chief = Chief.new(@sample_project, Octokit::Client.new)

    detective = BadRepoFilesExamineDetective1.new

    VCR.use_cassette('github') do
      my_results = new_chief.propose_one_change(detective, {})
      # Restore original environment BEFORE assertions (clean up FIRST)
      if old_environment
        ENV['RAILS_ENV'] = old_environment
      else
        ENV.delete('RAILS_ENV')
      end
      # Ruby weirdness: {} is considered a block, not an empty hash,
      # so we can't use 'assert_equal {}, ...'.  We can't surround the {}
      # with parentheses to disambiguate it, because rubocop complains
      # with Lint/ParenthesesAsGroupedExpression.  So, do this instead.
      empty_hash = {}
      assert_equal empty_hash, my_results
    end
  end

  # Create special exception that happens nowhere else.  That way if
  # a *different* exception happens we don't accidentally pass the test.
  class WeirdException2 < StandardError
  end

  # Mock a detective who always fails
  class BadRepoFilesExamineDetective2 < RepoFilesExamineDetective
    def analyze(_, _)
      raise WeirdException2,
            'Exception of BadRepoFilesExamineDetective2', caller
    end
  end

  test 'Fatal exceptions in a Detective will crash the test system' do
    # Note difference with previous test.
    # Here we ensure that Detective exceptions WILL crash during testing.
    # This is an important distinction - we want the test environment
    # to crash quickly, so we detect problems and their causes quickly.
    # However, in production we don't want the system to crash.
    # Normally we want test and production systems to be the same,
    # but not in this way.  Thus, we must more carefully test the alternatives,
    # to ensure that both behaviors occur.

    old_environment = ENV.fetch('RAILS_ENV', nil)
    # TEMPORARILY make this a 'test' environment (it probably is anyway)
    ENV['RAILS_ENV'] = 'test'

    new_chief = Chief.new(@sample_project, Octokit::Client.new)

    detective = BadRepoFilesExamineDetective2.new

    VCR.use_cassette('github') do
      assert_raises WeirdException2 do
        new_chief.propose_one_change(detective, {})
      end
    end
    # Restore original environment.
    if old_environment
      ENV['RAILS_ENV'] = old_environment
    else
      ENV.delete('RAILS_ENV')
    end
  end

  # Create special exception that happens nowhere else.
  class WeirdException3 < StandardError
  end

  # Mapping detective that always raises from analyze
  class BadMappingDetective < MetalToBaselineDetective
    def analyze(_evidence, _current, _source_proposals = {})
      raise WeirdException3, 'Exception of BadMappingDetective', caller
    end
  end

  test 'Fatal exceptions in propose_mapping_change will not crash production system' do
    old_environment = ENV.fetch('RAILS_ENV', nil)
    ENV['RAILS_ENV'] = 'production'

    new_chief = Chief.new(@sample_project, proc { Octokit::Client.new })
    detective  = BadMappingDetective.new
    original   = { osps_ac_01_01_status: { value: 1, confidence: 2, explanation: 'x' } }

    my_results = new_chief.propose_mapping_change(detective, original)

    if old_environment
      ENV['RAILS_ENV'] = old_environment
    else
      ENV.delete('RAILS_ENV')
    end
    # Exception was rescued: proposal is unchanged
    assert_equal original, my_results
  end

  # Tests for Phase 1: Topological Sort and Filtering

  test 'filter_needed_detectives returns all when needed_outputs is nil' do
    chief = Chief.new(@sample_project, proc { Octokit::Client.new })
    result = chief.filter_needed_detectives(nil)
    assert_equal Chief::ALL_DETECTIVES, result
  end

  test 'filter_needed_detectives returns all when needed_outputs is empty' do
    chief = Chief.new(@sample_project, proc { Octokit::Client.new })
    result = chief.filter_needed_detectives(Set.new)
    assert_equal Chief::ALL_DETECTIVES, result
  end

  test 'filter_needed_detectives returns subset when specific outputs needed' do
    chief = Chief.new(@sample_project, proc { Octokit::Client.new })
    # Request only license-related outputs
    needed = Set.new(%i[floss_license_osi_status floss_license_status])
    result = chief.filter_needed_detectives(needed)

    # Should include FlossLicenseDetective (produces these outputs)
    assert_includes result, FlossLicenseDetective

    # Should be smaller than full list
    assert result.size < Chief::ALL_DETECTIVES.size
  end

  test 'filter_needed_detectives includes dependencies' do
    chief = Chief.new(@sample_project, proc { Octokit::Client.new })
    # Request repo_files (output of HowAccessRepoFilesDetective)
    needed = Set.new([:contribution_status])
    result = chief.filter_needed_detectives(needed)

    # Should include RepoFilesExamineDetective (produces contribution_status)
    assert_includes result, RepoFilesExamineDetective

    # Should also include HowAccessRepoFilesDetective (provides :repo_files input)
    assert_includes result, HowAccessRepoFilesDetective
  end

  test 'topological_sort_detectives returns same size array' do
    chief = Chief.new(@sample_project, proc { Octokit::Client.new })
    detectives = [FlossLicenseDetective, NameFromUrlDetective]
    result = chief.topological_sort_detectives(detectives)
    assert_equal detectives.size, result.size
  end

  test 'topological_sort_detectives orders dependencies correctly' do
    chief = Chief.new(@sample_project, proc { Octokit::Client.new })
    # HowAccessRepoFilesDetective provides :repo_files
    # RepoFilesExamineDetective needs :repo_files as input
    detectives = [RepoFilesExamineDetective, HowAccessRepoFilesDetective]
    result = chief.topological_sort_detectives(detectives)

    # HowAccessRepoFilesDetective should come before RepoFilesExamineDetective
    how_index = result.index(HowAccessRepoFilesDetective)
    repo_index = result.index(RepoFilesExamineDetective)
    assert how_index < repo_index,
           'HowAccessRepoFilesDetective should come before RepoFilesExamineDetective'
  end

  test 'topological_sort handles multiple no-dependency detectives' do
    chief = Chief.new(@sample_project, proc { Octokit::Client.new })
    # Test with multiple detectives that have no dependencies (all start with
    # no dependencies), plus some that depend on one of them.
    # This tests the bug where detectives were added to no_dependencies
    # queue multiple times, causing incorrect ordering.
    detectives = [
      SubdirFileContentsDetective,  # depends on repo_files
      RepoFilesExamineDetective,    # depends on repo_files
      ProjectSitesHttpsDetective,   # no dependencies
      NameFromUrlDetective,         # no dependencies
      HowAccessRepoFilesDetective,  # no dependencies (provides repo_files)
      GithubBasicDetective,         # no dependencies (provides license)
      FlossLicenseDetective,        # depends on license
      BuildDetective                # depends on repo_files
    ]
    result = chief.topological_sort_detectives(detectives)

    # Verify all detectives are included exactly once
    assert_equal detectives.size, result.size
    assert_equal detectives.to_set, result.to_set

    # Verify dependencies are respected
    how_index = result.index(HowAccessRepoFilesDetective)
    repo_examine_index = result.index(RepoFilesExamineDetective)
    subdir_index = result.index(SubdirFileContentsDetective)
    build_index = result.index(BuildDetective)
    github_index = result.index(GithubBasicDetective)
    floss_index = result.index(FlossLicenseDetective)

    # HowAccessRepoFilesDetective must come before anything that needs repo_files
    assert how_index < repo_examine_index,
           'HowAccessRepoFilesDetective should come before RepoFilesExamineDetective'
    assert how_index < subdir_index,
           'HowAccessRepoFilesDetective should come before SubdirFileContentsDetective'
    assert how_index < build_index,
           'HowAccessRepoFilesDetective should come before BuildDetective'

    # GithubBasicDetective must come before FlossLicenseDetective
    assert github_index < floss_index,
           'GithubBasicDetective should come before FlossLicenseDetective'
  end

  test 'needed_outputs returns all outputs when needed_fields is nil' do
    chief = Chief.new(@sample_project, proc { Octokit::Client.new })
    result = chief.needed_outputs(nil)

    # Should include outputs from all detectives
    assert_includes result, :floss_license_osi_status # metal
    assert_includes result, :osps_le_02_01_status     # baseline
    assert result.size > 10
  end

  test 'needed_outputs returns only requested passing fields' do
    chief = Chief.new(@sample_project, proc { Octokit::Client.new })
    result = chief.needed_outputs(FIELDS['0'])

    # Should include passing-level criteria that detectives produce
    passing_detective_outputs = result
    assert passing_detective_outputs.size.positive?

    # Should not include baseline-only criteria
    baseline_only = FIELDS['baseline-1'] - FIELDS['0']
    baseline_only.each do |field|
      assert_not_includes result, field
    end
  end

  test 'needed_outputs returns only requested baseline fields' do
    chief = Chief.new(@sample_project, proc { Octokit::Client.new })
    result = chief.needed_outputs(FIELDS['baseline-1'])

    # Should include baseline criteria that detectives produce
    assert result.size.positive?

    # Should not include passing-only criteria
    passing_only = FIELDS['0'] - FIELDS['baseline-1']
    passing_only.each do |field|
      assert_not_includes result, field
    end
  end

  test 'needed_outputs includes changed_fields' do
    chief = Chief.new(@sample_project, proc { Octokit::Client.new })
    result = chief.needed_outputs(FIELDS['0'], [:custom_field])

    # Should include the explicitly changed field
    assert_includes result, :custom_field
  end

  test 'propose_changes accepts needed_fields parameter' do
    chief = Chief.new(@sample_project, proc { Octokit::Client.new })
    VCR.use_cassette('github') do
      result = chief.propose_changes(needed_fields: FIELDS['0'])
      assert_kind_of Hash, result
    end
  end

  test 'propose_changes with needed_fields runs fewer detectives than without' do
    chief = Chief.new(@sample_project, proc { Octokit::Client.new })

    # Count how many detectives would run for all fields
    needed_all = chief.needed_outputs(nil)
    detectives_all = chief.filter_needed_detectives(needed_all)
    detective_count_all = detectives_all.size

    # Count how many detectives would run for a single detective's outputs
    subset = Set.new(FlossLicenseDetective::OUTPUTS)
    needed_subset = chief.needed_outputs(subset)
    detectives_subset = chief.filter_needed_detectives(needed_subset)
    detective_count_subset = detectives_subset.size

    # Should run fewer detectives for a subset of fields
    assert detective_count_subset <= detective_count_all,
           "Subset should run <= detectives than all (#{detective_count_subset} vs #{detective_count_all})"
  end

  test 'autofill accepts needed_fields parameter' do
    chief = Chief.new(@sample_project, proc { Octokit::Client.new })
    VCR.use_cassette('github') do
      chief.autofill(needed_fields: FIELDS['0'])
    end
    # Should not raise an error
    assert_equal "https://github.com/#{@full_name}", @sample_project[:repo_url]
  end

  # Stub that provides a fixed security-insights.yml to the detective pipeline
  # without hitting GitHub, so we can test SecurityInsightsDetective via Chief.
  class FakeSiRepoFiles
    def blank? = false

    def get_content(path, max_size: nil) # rubocop:disable Lint/UnusedMethodArgument
      return unless path == 'security-insights.yml'

      <<~YAML
        project:
          vulnerability-reporting:
            reports-accepted: true
      YAML
    end
  end

  class FakeRepoFilesDetective < Detective
    INPUTS              = [].freeze
    OUTPUTS             = [:repo_files].freeze
    OVERRIDABLE_OUTPUTS = [].freeze

    def analyze(_evidence, _current)
      { repo_files: { value: FakeSiRepoFiles.new, confidence: 3, explanation: '' } }
    end
  end

  test 'SecurityInsightsDetective produces correct proposals through Chief pipeline' do
    # Project with no repo_url avoids triggering RepoJsonDetective's GitHub call.
    project = Project.new
    chief = Chief.new(project, proc { Octokit::Client.new },
                      detectives: [FakeRepoFilesDetective, SecurityInsightsDetective])
    result = chief.propose_changes
    assert_equal CriterionStatus::MET,
                 result[:vulnerability_report_process_status][:value],
                 'reports-accepted: true should infer vulnerability_report_process Met'
  end

  test 'autofill with needed_fields produces same results for overlapping criteria' do
    # Create two identical projects
    project1 = Project.new
    project1[:repo_url] = "https://github.com/#{@full_name}"

    project2 = Project.new
    project2[:repo_url] = "https://github.com/#{@full_name}"

    VCR.use_cassette('github') do
      # Run autofill with passing-level fields on project1
      chief1 = Chief.new(project1, proc { Octokit::Client.new })
      chief1.autofill(needed_fields: FIELDS['0'])

      # Run autofill with all fields on project2
      chief2 = Chief.new(project2, proc { Octokit::Client.new })
      chief2.autofill
    end

    # For passing-level criteria, results should be the same
    assert_equal project1[:floss_license_osi_status],
                 project2[:floss_license_osi_status]
    assert_equal project1[:contribution_status],
                 project2[:contribution_status]
  end
end
# rubocop:enable Metrics/ClassLength
