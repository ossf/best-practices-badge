# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# rubocop:disable Metrics/ClassLength
class ProjectTest < ActiveSupport::TestCase
  setup do
    @user = users(:test_user)
    @project_built = @user.projects.build(
      homepage_url: 'https://www.example.org',
      repo_url: 'https://www.example.org/code'
    )
    @unjustified_project = projects(:perfect_unjustified)
    @project_passing = projects(:perfect_passing)
    @project_silver = projects(:perfect_silver)
    @project_gold = projects(:perfect)
  end

  test 'should be valid' do
    assert @project_built.valid?
  end

  test 'user id should be present' do
    @project_built.user_id = nil
    assert_not @project_built.valid?
  end

  test 'invalid URLs should be rejected' do
    @project_built.homepage_url = 'http://127.0.0.1'
    assert_not @project_built.valid?
    assert @project_built.errors[:homepage_url].any?

    @project_built.homepage_url = 'https://www.example.org'
    @project_built.repo_url = 'https://containrrr/watchtower'
    assert_not @project_built.valid?
    assert @project_built.errors[:repo_url].any?
  end

  test '#contains_url?' do
    assert Project.new.contains_url? 'https://www.example.org'
    assert Project.new.contains_url? 'http://www.example.org'
    assert Project.new.contains_url? 'See also http://x.org.'
    assert Project.new.contains_url? 'See also <http://x.org>.'
    assert_not Project.new.contains_url? 'mailto://mail@example.org'
    assert_not Project.new.contains_url? 'abc'
    assert_not(
      Project.new.contains_url?('See also http://x for more information.')
    )
    assert_not Project.new.contains_url? 'www.google.com'
    # New regex requires a dot in the hostname to reject obvious nonsense
    assert_not Project.new.contains_url? 'http://nodothost'
  end

  # rubocop:disable Metrics/BlockLength
  test 'Rigorous project and repo URL checker' do
    regex = UrlValidator::URL_REGEX
    my_url = 'https://github.com/ossf/best-practices-badge'
    assert my_url =~ regex

    # Here we just the regex directly, to make sure it's okay.
    assert 'https://kernel.org' =~ regex
    assert_not 'https://' =~ regex
    assert_not 'www.google.com' =~ regex
    assert_not 'See also http://x.org for more information.' =~ regex
    assert_not 'See also <http://x.org>.' =~ regex

    # Here we use the full validator.  We stub out the info necessary
    # to create a validator instance to test (we won't really use them).
    validator = UrlValidator.new(attributes: %i[repo_url project_url])
    assert validator.url_acceptable?(my_url)
    assert validator.url_acceptable?('https://kernel.org')
    assert validator.url_acceptable?('') # Empty allowed.
    assert_not validator.url_acceptable?('https://')
    assert_not validator.url_acceptable?('www.google.com')
    assert_not validator.url_acceptable?('See also http://x.org for more.')
    assert_not validator.url_acceptable?('See also <http://x.org>.')
    assert validator.url_acceptable?('http://google.com')
    # We don't allow '?'
    assert_not validator.url_acceptable?('http://google.com?hello')
    # We do allow fragments, e.g., #
    assert_not validator.url_acceptable?('http://google.com#hello')

    # Security: Reject all IP addresses (IPv4 and IPv6) and malformed domains
    assert_not validator.url_acceptable?('http://127.0.0.1')
    assert_not validator.url_acceptable?('http://10.0.0.1')
    assert_not validator.url_acceptable?('http://192.168.1.1')
    assert_not validator.url_acceptable?('http://8.8.8.8')
    assert_not validator.url_acceptable?('http://3.6.47.234')
    assert_not validator.url_acceptable?('http://[::1]')
    assert_not validator.url_acceptable?('http://localhost')
    assert_not validator.url_acceptable?('http://127.1') # Shorthand
    assert_not validator.url_acceptable?('http://0x7f000001') # Hex bypass
    assert_not validator.url_acceptable?('http://2130706433') # Integer bypass
    assert_not validator.url_acceptable?('https://containrrr/watchtower') # Missing dot

    # Accept U+0020 (space) and U+00E9 c3 a9 "LATIN SMALL LETTER E WITH ACUTE"
    assert validator.url_acceptable?('https://github.com/linuxfoundation/' \
                                     'cii-best-practices-badge%20%c3%a9')
    # Accept U+8C0A Unicode Han Character 'friendship; appropriate, suitable'
    # encoded in UTF-8 as 0xE8 0xB0 0x8A (e8b08a); see
    # http://www.fileformat.info/info/unicode/char/8c0a/index.htm
    assert validator.url_acceptable?('https://github.com/linuxfoundation/' \
                                     '%E8%B0%8A')
    # Accept U+1000 Unicode Character 'MYANMAR LETTER KA'
    # encoded in UTF-8 as 0xE1 0x80 0x80
    # http://www.fileformat.info/info/unicode/char/1000/index.htm
    assert validator.url_acceptable?('https://github.com/linuxfoundation/' \
                                     '%e1%80%80')
    # Don't accept "c0 80", an overlong (2-byte) encoding of U+0000 (NUL).
    # Note that "modified UTF-8" does accept this.
    assert_not validator.url_acceptable?('https://github.com/linuxfoundation/' \
                                         'cii-best-practices-badge%20%c0%80')
    # Don't accept non-UTF-8, even if the individual bytes are acceptable.
    assert_not validator.url_acceptable?('https://github.com/linuxfoundation/' \
                                         'cii-best-practices-badge%eex')
    assert_not validator.url_acceptable?('https://github.com/linuxfoundation/' \
                                         'cii-best-practices-badge%ee')
    assert_not validator.url_acceptable?('https://github.com/linuxfoundation/' \
                                         'cii-best-practices-badge%ff%ff')
  end
  # rubocop:enable Metrics/BlockLength

  test 'UTF-8 validator should refute non-UTF-8 encoding' do
    validator = TextValidator.new(attributes: %i[name description])
    # Don't accept non-UTF-8, even if the individual bytes are acceptable.
    assert_not validator.text_acceptable?("The best practices badge\255")
    assert_not validator.text_acceptable?("The best practices badge\xff\xff")
    assert_not validator.text_acceptable?("The best practices badge\xee")
    assert_not validator.text_acceptable?("The best practices badge\xe4")
    # Don't accept an invalid control character
    assert_not validator.text_acceptable?("The best practices badge\x0c")
    assert validator.text_acceptable?('The best practices badge.')
  end

  # rubocop:disable Metrics/BlockLength
  test 'test get_criterion_result returns correct values' do
    assert_equal(
      :criterion_url_required,
      @unjustified_project.get_criterion_result(Criteria['0'][:contribution])
    )
    assert_equal(
      :criterion_justification_required,
      @unjustified_project.get_criterion_result(Criteria['0'][:release_notes])
    )
    assert_equal(
      :criterion_justification_required,
      @unjustified_project.get_criterion_result(
        Criteria['0'][:test_invocation]
      )
    )
    assert_equal(
      :criterion_justification_required,
      @unjustified_project.get_criterion_result(
        Criteria['0'][:static_analysis]
      )
    )
    assert_equal(
      :criterion_barely,
      @unjustified_project.get_criterion_result(Criteria['0'][:test_most])
    )
    assert_equal(
      :criterion_failing,
      @unjustified_project.get_criterion_result(
        Criteria['1'][:crypto_certificate_verification]
      )
    )
    assert_equal(
      :criterion_unknown,
      @unjustified_project.get_criterion_result(
        Criteria['2'][:build_reproducible]
      )
    )
    assert_equal(
      :criterion_passing,
      @unjustified_project.get_criterion_result(
        Criteria['0'][:vulnerability_report_private]
      )
    )
  end
  # rubocop:enable Metrics/BlockLength

  test 'check correct badge levels are returned' do
    assert_equal 'in_progress', @unjustified_project.badge_level
    assert_equal 'passing', @project_passing.badge_level
    assert_equal 'silver', @project_silver.badge_level
    assert_equal 'gold', @project_gold.badge_level
  end

  # This test works because we don't set the higher level prereqs in the
  # fixture files.  Make sure not to change this.
  test 'check update_prereqs works correctly for level upgrades' do
    # Phase 3: Achievement status fields return raw integers (no custom readers)
    assert_equal CriterionStatus::UNMET, @unjustified_project.achieve_passing_status
    assert_equal CriterionStatus::UNMET, @project_passing.achieve_passing_status
    assert_equal CriterionStatus::UNMET, @project_passing.achieve_silver_status
    assert_equal CriterionStatus::MET, @project_silver.achieve_passing_status
    assert_equal CriterionStatus::UNMET, @project_silver.achieve_silver_status
    assert @project_silver.achieved_silver_at.blank?
    assert @project_silver.first_achieved_silver_at.blank?
    Project.update_all_badge_percentages(Criteria.keys)
    assert_equal(
      CriterionStatus::UNMET, Project.find(@unjustified_project.id).achieve_passing_status
    )
    assert_equal(
      CriterionStatus::MET, Project.find(@project_passing.id).achieve_passing_status
    )
    assert_equal(
      CriterionStatus::UNMET, Project.find(@project_passing.id).achieve_silver_status
    )
    updated_project = Project.find(@project_silver.id)
    assert_equal CriterionStatus::MET, updated_project.achieve_passing_status
    assert_equal CriterionStatus::MET, updated_project.achieve_silver_status
  end

  test 'update_prereqs works correctly for level downgrades' do
    assert_equal CriterionStatus::MET, @project_silver.achieve_passing_status
    @project_silver.update!(description_good_status: CriterionStatus::UNMET)
    assert_equal(
      CriterionStatus::UNMET, Project.find(@project_silver.id).achieve_passing_status
    )
  end

  # The number of named badge levels must be equal to the number of
  # criteria levels + 1, because projects can be "in_progress"
  test 'test all possible badge "levels/statuses" are named' do
    # Metal series: in_progress + 3 levels (passing, silver, gold)
    # Baseline series: 3 levels (baseline-1, baseline-2, baseline-3)
    metal_count = Project::CRITERIA_SERIES[:metal].size
    assert_equal metal_count + 1, Project::BADGE_LEVELS.size
    # ALL_BADGE_LEVELS should equal all criteria levels (metal + baseline)
    assert_equal metal_count + Project::CRITERIA_SERIES[:baseline].size,
                 Project::ALL_BADGE_LEVELS.size
  end

  test 'Project counts from fixtures are as expected' do
    assert_equal 4, Project.in_progress.count
    assert_equal 3, Project.passing.count
  end

  test 'test get_satisfaction_data' do
    basics = @unjustified_project.get_satisfaction_data('0', 'basics')
    assert_equal '10/13', basics[:text]
    assert_equal 'hsl(92, 100%, 50%)', basics[:color]
    reporting = @unjustified_project.get_satisfaction_data('0', 'reporting')
    assert_equal '5/8', reporting[:text]
    assert_equal 'hsl(75, 100%, 50%)', reporting[:color]
    quality = @unjustified_project.get_satisfaction_data('0', 'quality')
    assert_equal '12/13', quality[:text]
    assert_equal 'hsl(111, 100%, 50%)', quality[:color]
  end

  test 'Justification goodness' do
    # Use "send" to do unit tests of a private method.
    assert @unjustified_project.send(
      :justification_good?,
      'This is long enough.'
    )
    assert_not @unjustified_project.send(
      :justification_good?,
      '// This is a comment.'
    )
    assert_not @unjustified_project.send(:justification_good?, 'bah.')
    assert_not @unjustified_project.send(:justification_good?, '')
    assert_not @unjustified_project.send(:justification_good?, nil)
  end

  # rubocop:disable Metrics/BlockLength
  test 'test :skip_callbacks works as expected' do
    project_one = projects(:one)
    Project.skip_callbacks = true
    # With skip_callbacks = true there should be
    # no change to percentages on save.
    assert_no_difference [
      'Project.find(projects(:one).id).badge_percentage_0',
      'Project.find(projects(:one).id).badge_percentage_1'
    ] do
      project_one.update!(
        crypto_weaknesses_status: CriterionStatus::MET,
        crypto_weaknesses_justification: 'It is good'
      )
    end
    Project.skip_callbacks = false
    old_percentage0 = Project.find(projects(:one).id).badge_percentage_0
    old_percentage1 = Project.find(projects(:one).id).badge_percentage_1
    project_one.update!(
      warnings_strict_status: CriterionStatus::MET,
      warnings_strict_justification: 'It is good'
    )
    # Check the badge percentage changed
    assert_not_equal(
      Project.find(projects(:one).id).badge_percentage_0,
      old_percentage0
    )
    assert_not_equal(
      Project.find(projects(:one).id).badge_percentage_1,
      old_percentage1
    )
  end
  # rubocop:enable Metrics/BlockLength

  test 'compute_tiered_percentage works' do
    # Simple unit test of 'compute_tiered_percentage'
    p = Project.new
    # Very different numbers so correct answer unlikely to happen by chance
    p.badge_percentage_0 = 31
    p.badge_percentage_1 = 17
    p.badge_percentage_2 = 4
    assert_equal 31, p.compute_tiered_percentage
    p.badge_percentage_0 = 100
    assert_equal 117, p.compute_tiered_percentage
    p.badge_percentage_1 = 100
    assert_equal 204, p.compute_tiered_percentage
    p.badge_percentage_2 = 100
    assert_equal 300, p.compute_tiered_percentage
    p.badge_percentage_0 = 85
    assert_equal 85, p.compute_tiered_percentage
  end

  # If one of these tests fail, you've probably changed the criteria and
  # haven't changed the fixture values to match. The solution
  # will probably require updating test/fixtures/projects.yml
  test 'Check that fixture percentages are correct' do
    projects.each_entry do |project|
      Project::LEVEL_IDS.each do |level|
        assert_equal project["badge_percentage_#{level}"],
                     project.calculate_badge_percentage(level),
                     "Miscalculation level #{level} in project #{project.name}"
      end
    end
  end

  # =========================================================================
  # Unit tests for Project scopes - added before Rails modernization
  # These tests ensure that scope behavior remains identical when we
  # modernize from Arel syntax to Rails 7+ range syntax
  # =========================================================================

  test 'created_since scope filters projects by creation time' do
    # Create test projects with specific creation times
    old_time = 3.days.ago
    recent_time = 1.hour.ago

    old_project = Project.create!(
      user: @user,
      name: 'Old Project',
      homepage_url: 'https://old.example.com',
      repo_url: 'https://github.com/old/project',
      created_at: old_time
    )

    recent_project = Project.create!(
      user: @user,
      name: 'Recent Project',
      homepage_url: 'https://recent.example.com',
      repo_url: 'https://github.com/recent/project',
      created_at: recent_time
    )

    # Test filtering with 2.days.ago threshold
    results = Project.created_since(2.days.ago)
    assert_includes results, recent_project,
                    'Recent project should be included'
    assert_not_includes results, old_project,
                        'Old project should be excluded'

    # Test filtering with 4.days.ago threshold (should include both)
    results_all = Project.created_since(4.days.ago)
    assert_includes results_all, recent_project,
                    'Recent project should be included'
    assert_includes results_all, old_project,
                    'Old project should be included'

    # Test filtering with 30.minutes.ago threshold (should exclude both)
    results_none = Project.created_since(30.minutes.ago)
    assert_not_includes results_none, recent_project,
                        'Recent project should be excluded'
    assert_not_includes results_none, old_project,
                        'Old project should be excluded'
  end

  test 'updated_since scope filters projects by update time' do
    # Create a project and update it at a specific time
    project = Project.create!(
      user: @user,
      name: 'Test Project',
      homepage_url: 'https://test.example.com',
      repo_url: 'https://github.com/test/project'
    )

    # Update the project 2 hours ago
    travel_to(2.hours.ago) do
      project.update!(name: 'Updated Test Project')
    end

    # Create another project that hasn't been updated recently
    old_project = projects(:one) # This is from fixtures, updated in 2000

    # Test filtering
    results = Project.updated_since(3.hours.ago)
    assert_includes results, project,
                    'Recently updated project should be included'
    assert_not_includes results, old_project,
                        'Old project should be excluded'

    # Test with 1.hour.ago threshold (should exclude our test project)
    results_none = Project.updated_since(1.hour.ago)
    assert_not_includes results_none, project,
                        'Project updated 2 hours ago should be excluded'
  end

  test 'gteq scope filters projects by tiered_percentage >=threshold' do
    # Use existing fixtures that have known tiered_percentage values
    # From fixtures: tiered_percentage values are 0, 87, 113, 239, 300

    # Test filtering with 100 threshold (should include 113, 239, 300)
    results_100 = Project.gteq(100)
    passing_projects = results_100.pluck(:tiered_percentage).sort

    assert_operator passing_projects.min, :>=, 100,
                    'All results should be >= 100'
    assert_includes passing_projects, 113,
                    'Should include project with 113%'
    assert_includes passing_projects, 239,
                    'Should include project with 239%'
    assert_includes passing_projects, 300,
                    'Should include project with 300%'

    # Test filtering with 200 threshold (should include 239, 300)
    results_200 = Project.gteq(200)
    high_projects = results_200.pluck(:tiered_percentage).sort

    assert_operator high_projects.min, :>=, 200,
                    'All results should be >= 200'
    assert_includes high_projects, 239,
                    'Should include project with 239%'
    assert_includes high_projects, 300,
                    'Should include project with 300%'
    assert_equal 2, high_projects.length,
                 'Should have exactly 2 projects >= 200%'

    # Test filtering with 0 threshold (should include all projects)
    results_0 = Project.gteq(0)
    all_percentages = results_0.pluck(:tiered_percentage)
    assert_operator all_percentages.length, :>, 5,
                    'Should include multiple projects'

    # Test filtering with very high threshold (should include none)
    results_500 = Project.gteq(500)
    assert_equal 0, results_500.count, 'No projects should have >= 500%'
  end

  test 'lteq scope filters projects by tiered_percentage <=threshold' do
    # Test filtering with 100 threshold (should include 0, 87)
    results_100 = Project.lteq(100)
    low_projects = results_100.pluck(:tiered_percentage).sort

    assert_operator low_projects.max, :<=, 100,
                    'All results should be <= 100'
    assert_includes low_projects, 0, 'Should include projects with 0%'
    assert_includes low_projects, 87, 'Should include project with 87%'

    # Test filtering with 50 threshold (should include only 0)
    results_50 = Project.lteq(50)
    very_low_projects = results_50.pluck(:tiered_percentage).sort

    assert_operator very_low_projects.max, :<=, 50,
                    'All results should be <= 50'
    assert_includes very_low_projects, 0, 'Should include projects with 0%'

    # Test filtering with 500 threshold (should include all projects)
    results_500 = Project.lteq(500)
    all_percentages = results_500.pluck(:tiered_percentage)
    assert_operator all_percentages.length, :>, 5,
                    'Should include multiple projects'
  end

  test 'gteq and lteq scopes can be chained together' do
    # Test range filtering: 80% <= tiered_percentage <= 120%
    results = Project.gteq(80).lteq(120)
    range_percentages = results.pluck(:tiered_percentage).sort

    range_percentages.each do |percentage|
      assert_operator percentage, :>=, 80, "#{percentage} should be >= 80"
      assert_operator percentage, :<=, 120, "#{percentage} should be <= 120"
    end

    # Should include 87 and 113, but not 0, 239, or 300
    assert_includes range_percentages, 87,
                    'Should include project with 87%'
    assert_includes range_percentages, 113,
                    'Should include project with 113%'
  end

  test 'passing scope is equivalent to gteq(100)' do
    # The passing scope should return the same results as gteq(100)
    passing_results = Project.passing.ids.sort
    gteq_results = Project.gteq(100).ids.sort

    assert_equal gteq_results, passing_results,
                 'passing scope should equal gteq(100)'
  end

  test 'in_progress scope is equivalent to lteq(99)' do
    # The in_progress scope should return the same results as lteq(99)
    in_progress_results = Project.in_progress.ids.sort
    lteq_results = Project.lteq(99).ids.sort

    assert_equal lteq_results, in_progress_results,
                 'in_progress scope should equal lteq(99)'
  end

  test 'scope methods handle edge cases correctly' do
    # Test with nil/empty parameters (should not crash)
    assert_nothing_raised do
      Project.gteq(nil).count
      Project.lteq(nil).count
    end

    # Test with string parameters (should be converted to integers)
    string_results = Project.gteq('100').pluck(:tiered_percentage)
    integer_results = Project.gteq(100).pluck(:tiered_percentage)

    assert_equal integer_results.sort, string_results.sort,
                 'String and integer params should give same results'

    # Test with negative numbers
    negative_results = Project.gteq(-10)
    all_results = Project.all

    assert_equal all_results.count, negative_results.count,
                 'Negative threshold should include all projects'
  end

  test 'time-based scopes work correctly with Time objects' do
    # Test created_since with various Time formats
    time_formats = [
      2.days.ago,
      Time.zone.parse('2023-01-01'),
      Date.yesterday,
      Time.zone.parse('2023-06-01')
    ]

    time_formats.each do |time_format|
      assert_nothing_raised do
        results = Project.created_since(time_format)
        assert_respond_to results, :count, 'Should return a relation'
      end
    end
  end

  test 'scopes maintain proper ActiveRecord::Relation behavior' do
    # Ensure scopes return proper ActiveRecord relations, not arrays
    created_since_relation = Project.created_since(1.day.ago)
    gteq_relation = Project.gteq(50)
    lteq_relation = Project.lteq(150)

    [created_since_relation, gteq_relation, lteq_relation].each do |rel|
      assert_kind_of ActiveRecord::Relation, rel,
                     'Should return ActiveRecord::Relation'
      assert_respond_to rel, :where, 'Should be chainable with scopes'
      assert_respond_to rel, :limit, 'Should be chainable with limit'
      assert_respond_to rel, :order, 'Should be chainable with order'
    end
  end

  test 'badge_percentage_field_name returns correct field for baseline-1' do
    project = projects(:perfect_passing)
    assert_equal :badge_percentage_baseline_1,
                 project.badge_percentage_field_name('baseline-1')
  end

  test 'badge_percentage_field_name returns correct field for baseline-2' do
    project = projects(:perfect_passing)
    assert_equal :badge_percentage_baseline_2,
                 project.badge_percentage_field_name('baseline-2')
  end

  test 'badge_percentage_field_name returns correct field for baseline-3' do
    project = projects(:perfect_passing)
    assert_equal :badge_percentage_baseline_3,
                 project.badge_percentage_field_name('baseline-3')
  end

  test 'badge_percentage_field_name handles unknown level with fallback' do
    project = projects(:perfect_passing)
    # Test the else branch with an unknown level
    assert_equal :badge_percentage_unknown,
                 project.badge_percentage_field_name('unknown')
  end

  test 'baseline_badge_level returns in_progress when no baseline achieved' do
    project = projects(:perfect_passing)
    project.badge_percentage_baseline_1 = 50
    project.badge_percentage_baseline_2 = 0
    project.badge_percentage_baseline_3 = 0
    assert_equal 'in_progress', project.baseline_badge_level
  end

  test 'baseline_badge_level returns baseline-1 when only level 1 achieved' do
    project = projects(:perfect_passing)
    project.badge_percentage_baseline_1 = 100
    project.badge_percentage_baseline_2 = 50
    project.badge_percentage_baseline_3 = 0
    assert_equal 'baseline-1', project.baseline_badge_level
  end

  test 'baseline_badge_level returns baseline-2 when level 2 achieved' do
    project = projects(:perfect_passing)
    project.badge_percentage_baseline_1 = 100
    project.badge_percentage_baseline_2 = 100
    project.badge_percentage_baseline_3 = 50
    assert_equal 'baseline-2', project.baseline_badge_level
  end

  test 'baseline_badge_level returns baseline-3 when level 3 achieved' do
    project = projects(:perfect_passing)
    project.badge_percentage_baseline_1 = 100
    project.badge_percentage_baseline_2 = 100
    project.badge_percentage_baseline_3 = 100
    assert_equal 'baseline-3', project.baseline_badge_level
  end

  test 'baseline_badge_level ignores past achievements if percentage dropped' do
    project = projects(:perfect_passing)
    project.badge_percentage_baseline_1 = 50
    project.badge_percentage_baseline_2 = 0
    project.badge_percentage_baseline_3 = 0
    # Past achievement doesn't count - only current percentage matters
    project.achieved_baseline_1_at = 1.day.ago
    assert_equal 'in_progress', project.baseline_badge_level
  end

  test 'baseline_badge_value returns percentage badge when in_progress' do
    project = projects(:perfect_passing)
    project.badge_percentage_baseline_1 = 42
    project.badge_percentage_baseline_2 = 0
    project.badge_percentage_baseline_3 = 0
    assert_equal 'baseline-pct-42', project.baseline_badge_value
  end

  test 'baseline_badge_value returns level name when achieved' do
    project = projects(:perfect_passing)
    project.badge_percentage_baseline_1 = 100
    project.badge_percentage_baseline_2 = 100
    project.badge_percentage_baseline_3 = 0
    assert_equal 'baseline-2', project.baseline_badge_value
  end

  test 'baseline_badge_value returns highest achieved level' do
    project = projects(:perfect_passing)
    project.badge_percentage_baseline_1 = 100
    project.badge_percentage_baseline_2 = 100
    project.badge_percentage_baseline_3 = 100
    assert_equal 'baseline-3', project.baseline_badge_value
  end

  test 'baseline_badge_src_url returns static URL when recently updated' do
    project = projects(:perfect_passing)
    project.updated_at = 1.hour.ago
    project.badge_percentage_baseline_1 = 42
    assert_equal '/badge_static/baseline-pct-42', project.baseline_badge_src_url
  end

  test 'baseline_badge_src_url returns project URL when not recently updated' do
    project = projects(:perfect_passing)
    project.updated_at = 2.days.ago
    assert_equal "/projects/#{project.id}/baseline", project.baseline_badge_src_url
  end

  test 'compute_baseline_tiered_percentage returns 0-99 when working on baseline-1' do
    project = projects(:perfect_passing)
    project.badge_percentage_baseline_1 = 42
    project.badge_percentage_baseline_2 = 0
    project.badge_percentage_baseline_3 = 0
    assert_equal 42, project.compute_baseline_tiered_percentage
  end

  test 'compute_baseline_tiered_percentage returns 100-199 when baseline-1 complete' do
    project = projects(:perfect_passing)
    project.badge_percentage_baseline_1 = 100
    project.badge_percentage_baseline_2 = 50
    project.badge_percentage_baseline_3 = 0
    assert_equal 150, project.compute_baseline_tiered_percentage
  end

  test 'compute_baseline_tiered_percentage returns 200-299 when baseline-2 complete' do
    project = projects(:perfect_passing)
    project.badge_percentage_baseline_1 = 100
    project.badge_percentage_baseline_2 = 100
    project.badge_percentage_baseline_3 = 75
    assert_equal 275, project.compute_baseline_tiered_percentage
  end

  test 'compute_baseline_tiered_percentage returns 300 when all baseline levels complete' do
    project = projects(:perfect_passing)
    project.badge_percentage_baseline_1 = 100
    project.badge_percentage_baseline_2 = 100
    project.badge_percentage_baseline_3 = 100
    assert_equal 300, project.compute_baseline_tiered_percentage
  end

  test 'compute_baseline_tiered_percentage handles nil values' do
    project = projects(:perfect_passing)
    project.badge_percentage_baseline_1 = nil
    project.badge_percentage_baseline_2 = nil
    project.badge_percentage_baseline_3 = nil
    assert_equal 0, project.compute_baseline_tiered_percentage
  end

  test 'update_baseline_tiered_percentage sets the field correctly' do
    project = projects(:perfect_passing)
    project.badge_percentage_baseline_1 = 100
    project.badge_percentage_baseline_2 = 40
    project.badge_percentage_baseline_3 = 0
    project.update_baseline_tiered_percentage
    assert_equal 140, project.baseline_tiered_percentage
  end

  test 'entry_locale defaults to en' do
    project = @user.projects.build(
      homepage_url: 'https://www.example.org',
      repo_url: 'https://www.example.org/code'
    )
    assert_equal 'en', project.entry_locale
  end

  test 'entry_locale accepts valid locales' do
    @project_built.entry_locale = 'fr'
    assert @project_built.valid?, 'French locale should be valid'
    @project_built.entry_locale = 'zh-CN'
    assert @project_built.valid?, 'Chinese locale should be valid'
    @project_built.entry_locale = 'ja'
    assert @project_built.valid?, 'Japanese locale should be valid'
  end

  test 'entry_locale rejects invalid locales' do
    @project_built.entry_locale = 'xx'
    assert_not @project_built.valid?, 'Invalid locale should be rejected'
    @project_built.entry_locale = ''
    assert @project_built.valid?, 'Empty locale should be accepted (defaults to en)'
    # After validation, blank is normalized to 'en'
    assert_equal 'en', @project_built.entry_locale, 'Empty locale normalized to en'
    @project_built.entry_locale = 'english'
    assert_not @project_built.valid?, 'Full language name should be rejected'
  end
end
# rubocop:enable Metrics/ClassLength
