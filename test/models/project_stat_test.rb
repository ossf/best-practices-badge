# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

class ProjectStatTest < ActiveSupport::TestCase
  setup do
    # Normalize time in order to test timestamps
    travel_to Time.zone.parse('2015-03-01T12:00:00') do
      @project_stat = ProjectStat.create!
    end
  end

  # If you change files in test/fixtures/* you may need to change
  # the expected values.
  test 'project_stat matches expected values' do
    assert_equal 7, @project_stat.percent_ge_0
    assert_equal 4, @project_stat.percent_ge_25
    assert_equal 4, @project_stat.percent_ge_50
    assert_equal 4, @project_stat.percent_ge_75
    assert_equal 3, @project_stat.percent_ge_90
    assert_equal 3, @project_stat.percent_ge_100
    assert_equal 6, @project_stat.created_since_yesterday
    assert_equal 0, @project_stat.updated_since_yesterday
    assert_equal '2015-03-01 12:00:00 UTC', @project_stat.created_at.to_s
    assert_equal '2015-03-01 12:00:00 UTC', @project_stat.updated_at.to_s
    assert_equal 9, @project_stat.users
  end

  test 'BADGE_LEVELS has expected minimum size and starting value' do
    assert_operator ProjectStat::BADGE_LEVELS.count, :>=, 3
    assert_equal 0, ProjectStat::BADGE_LEVELS.first
  end

  test 'BASELINE_BADGE_LEVELS has expected minimum size and starting value' do
    assert_operator ProjectStat::BASELINE_BADGE_LEVELS.count, :>=, 3
    assert_equal 1, ProjectStat::BASELINE_BADGE_LEVELS.first
  end

  test 'count including fixtures' do
    # This includes the statistic created during setup
    assert_equal 9, ProjectStat.count
  end

  # Baseline stats should all be 0 since no project fixtures have
  # baseline percentage values set.
  test 'baseline stats are all zero with no baseline data' do
    ProjectStat::BASELINE_BADGE_LEVELS.each do |bl|
      ProjectStat::STAT_VALUES_GT0.each do |pct|
        field = :"percent_baseline_#{bl}_ge_#{pct}"
        assert_equal 0, @project_stat.public_send(field),
                     "Expected #{field} to be 0"
      end
    end
  end

  test 'ProjectStat.percent_field_name() works correctly' do
    assert_equal 'percent_ge_0', ProjectStat.percent_field_name(0, 0)
    assert_equal 'percent_ge_90', ProjectStat.percent_field_name(0, 90)
    assert_equal 'percent_1_ge_90', ProjectStat.percent_field_name(1, 90)
    assert_equal 'percent_2_ge_100', ProjectStat.percent_field_name(2, 100)
  end

  test 'ProjectStat.percent_field_description() works correctly' do
    I18n.with_locale(:en) do
      assert_equal 'Total Projects',
                   ProjectStat.percent_field_description(0, 0)
      assert_equal 'Total Projects',
                   ProjectStat.percent_field_description('0', 0)
      assert_equal 'Passing Projects',
                   ProjectStat.percent_field_description(0, 100)
      assert_equal 'Passing Projects',
                   ProjectStat.percent_field_description('0', 100)
      assert_equal 'Silver Projects',
                   ProjectStat.percent_field_description(1, 100)
      assert_equal 'Gold Projects',
                   ProjectStat.percent_field_description(2, 100)
      assert_equal 'Passing Projects, 50%+ to Silver',
                   ProjectStat.percent_field_description(1, 50)
      assert_equal 'Silver Projects, 90%+ to Gold',
                   ProjectStat.percent_field_description(2, 90)
      assert_equal 'Silver Projects, 90%+ to Gold',
                   ProjectStat.percent_field_description('2', 90)
    end
  end

  test 'ProjectStat.baseline_percent_field_name() works correctly' do
    assert_equal 'percent_baseline_1_ge_25',
                 ProjectStat.baseline_percent_field_name(1, 25)
    assert_equal 'percent_baseline_2_ge_50',
                 ProjectStat.baseline_percent_field_name(2, 50)
    assert_equal 'percent_baseline_3_ge_100',
                 ProjectStat.baseline_percent_field_name(3, 100)
  end

  test 'ProjectStat.baseline_percent_field_description() works correctly' do
    I18n.with_locale(:en) do
      assert_equal 'Baseline Level 1 Projects',
                   ProjectStat.baseline_percent_field_description(1, 100)
      assert_equal 'Baseline Level 2 Projects',
                   ProjectStat.baseline_percent_field_description(2, 100)
      assert_equal 'Baseline Level 3 Projects',
                   ProjectStat.baseline_percent_field_description(3, 100)
      assert_equal '50%+ to Baseline Level 1',
                   ProjectStat.baseline_percent_field_description(1, 50)
      assert_equal 'Baseline Level 1 Projects, 75%+ to Baseline Level 2',
                   ProjectStat.baseline_percent_field_description(2, 75)
      assert_equal 'Baseline Level 2 Projects, 90%+ to Baseline Level 3',
                   ProjectStat.baseline_percent_field_description(3, 90)
    end
  end

  test 'ProjectStat.baseline_percent_field_description() rejects bad levels' do
    assert_equal 'Bad baseline level 0',
                 ProjectStat.baseline_percent_field_description(0, 50)
    assert_equal 'Bad baseline level 4',
                 ProjectStat.baseline_percent_field_description(4, 50)
  end
end
