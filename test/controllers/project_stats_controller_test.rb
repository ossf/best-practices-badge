# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# rubocop:disable Metrics/ClassLength
class ProjectStatsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project_stat = project_stats(:one)
  end

  test 'should get index' do
    get '/en/project_stats'
    assert_response :success
    assert @response.body.include?('All projects')
    assert @response.body.include?(
      '<h2>Projects with badge entry activity in last 30 days</h2>'
    )
    # This isn't normally shown:
    assert_not @response.body.include?('Percentage of projects earning badges')
    # Do *NOT* include "Accept" in the Vary heading.
    # Note: "Origin" will be added to the Vary headers outside this test.
    assert 'Accept-Encoding', @response.headers['Vary']
  end

  test 'should get index as admin' do
    log_in_as(users(:admin_user))
    get '/en/project_stats'
    assert_response :success
    assert @response.body.include?('All projects')
    assert @response.body.include?(
      '<h2>Projects with badge entry activity in last 30 days</h2>'
    )
    assert @response.body.include?('As an admin, you may also see')
  end

  test 'should get uncommon stats on request' do
    get '/en/project_stats?type=uncommon'
    assert @response.body.include?('Daily badge entry activity')
    assert @response.body.include?('Percentage of projects earning badges')
  end

  # rubocop:disable Metrics/BlockLength
  test 'should get index, CSV format' do
    get '/en/project_stats.csv'
    assert_response :success
    contents = CSV.parse(@response.body, headers: true)

    # We *require* that 'id' be the first header
    assert_equal 'id', contents.headers.first

    # To make this test flexible, we simply test if expected headers are
    # *included* in the CSV - the CSV may have some other headers, and we
    # don't assert a particular order here.
    expected_headers = %w[
      id percent_ge_0 percent_ge_25 percent_ge_50
      percent_ge_75 percent_ge_90 percent_ge_100
      created_since_yesterday updated_since_yesterday created_at
      updated_at reminders_sent reactivated_after_reminder
      active_projects active_in_progress projects_edited
      active_edited_projects active_edited_in_progress
      percent_1_ge_25 percent_1_ge_50 percent_1_ge_75
      percent_1_ge_90 percent_1_ge_100 percent_2_ge_25
      percent_2_ge_50 percent_2_ge_75 percent_2_ge_90
      percent_2_ge_100 users github_users local_users
      users_created_since_yesterday users_updated_since_yesterday
      users_with_projects users_without_projects
      users_with_multiple_projects users_with_passing_projects
      users_with_silver_projects users_with_gold_projects
      additional_rights_entries projects_with_additional_rights
      users_with_additional_rights
    ]
    assert expected_headers.all? { |item| contents.headers.include?(item) },
           "Expected #{expected_headers} to be a subset of #{contents.headers}"

    assert_equal 8, contents.size
    assert_equal '13', contents[0]['percent_ge_50']
    assert_equal '20', contents[0]['percent_ge_0']
    assert_equal '19', contents[1]['percent_ge_0']

    # Do *NOT* include "Accept" in the Vary heading.
    assert 'Accept-Encoding', @response.headers['Vary']
  end
  # rubocop:enable Metrics/BlockLength

  test 'should get index, JSON format' do
    get '/en/project_stats.json'
    assert_response :success
    # Check if we can parse it.
    _contents = JSON.parse(@response.body)
    # Do *NOT* include "Accept" in the Vary heading.
    assert 'Accept-Encoding', @response.headers['Vary']
  end

  test 'should NOT be able to get new' do
    get '/en/project_stats/new'
    assert_response :not_found # 404
  end

  test 'should NOT be able create project_stat' do
    log_in_as(users(:admin_user))
    post '/en/project_stats', params: {
      project_stat: {
        percent_ge_0: @project_stat.percent_ge_0,
        percent_ge_25: @project_stat.percent_ge_25,
        percent_ge_50: @project_stat.percent_ge_50,
        percent_ge_75: @project_stat.percent_ge_75,
        percent_ge_90: @project_stat.percent_ge_90,
        percent_ge_100: @project_stat.percent_ge_100,
        created_since_yesterday: @project_stat.created_since_yesterday,
        updated_since_yesterday: @project_stat.updated_since_yesterday
      }
    }
    assert_response :not_found # 404
  end

  # At one time we supported this route, but it's pretty useless to
  # get a single data point in isolation. Yes, it's odd a REST-style
  # interface to only support acquiring a collection and not support retrieving
  # a single value, but in practice we don't want people to repeatedly
  # query us to get every item. If you need data, you need the whole thing,
  # so just request that and we can provide it (with a cache), which we have
  # to support anyway.
  test 'should NOT show project_stat' do
    get "/de/project_stats/#{@project_stat.id}"
    assert_response :not_found
  end

  test 'should NOT get edit' do
    get "/de/project_stats/#{@project_stat.id}/edit"
    assert_response :not_found # 404
  end

  test 'should NOT update project_stat' do
    log_in_as(users(:admin_user))
    patch "/en/project_stats/#{@project_stat.id}", params: {
      id: @project_stat,
      project_stat: {
        percent_ge_0: @project_stat.percent_ge_0,
        percent_ge_25: @project_stat.percent_ge_25,
        percent_ge_50: @project_stat.percent_ge_50,
        percent_ge_75: @project_stat.percent_ge_75,
        percent_ge_90: @project_stat.percent_ge_90,
        percent_ge_100: @project_stat.percent_ge_100,
        created_since_yesterday: @project_stat.created_since_yesterday,
        updated_since_yesterday: @project_stat.updated_since_yesterday
      }
    }
    assert_response :not_found # 404
  end

  test 'should NOT destroy project_stat' do
    log_in_as(users(:admin_user))
    delete "/en/project_stats/#{@project_stat.id}"
    assert_response :not_found # 404
  end

  test 'Test /project_stats/total_projects.json' do
    assert '/project_stats/total_projects.json',
           total_projects_project_stats_path(locale: nil)
    get total_projects_project_stats_path(locale: nil)
    contents = JSON.parse(@response.body)
    assert 20, contents['2013-05-19 17:44:18 UTC']
    # Do *NOT* include "Accept" in the Vary heading.
    # Note: "Origin" will be added to the Vary headers outside this test.
    assert 'Accept-Encoding', @response.headers['Vary']
    cache_control = @response.headers['Cache-Control']
    assert_includes cache_control, 'max-age='
    assert_includes cache_control, 'public'
    assert_not_includes cache_control, 'private'
  end

  test 'Test /project_stats/nontrivial_projects.json' do
    assert '/project_stats/nontrivial_projects.json',
           nontrivial_projects_project_stats_path(locale: nil)
    get nontrivial_projects_project_stats_path
    contents = JSON.parse(@response.body)
    levels = contents.pluck('name') # levels reported
    assert_equal ['>=25%', '>=50%', '>=75%', '>=90%', '>=100%'], levels
    assert_equal '>=25%', contents[0]['name']
    assert_equal 18, contents[0]['data']['2013-05-19 17:44:18 UTC']
  end

  test 'Test /en/project_stats/activity_30.json' do
    get activity_30_project_stats_path
    contents = JSON.parse(@response.body)
    assert_equal 'Active projects (created/updated within 30 days)',
                 contents[0]['name']
    assert_equal 4, contents.length
  end

  test 'Test /fr/project_stats/activity_30.json' do
    get activity_30_project_stats_path(locale: 'fr')
    contents = JSON.parse(@response.body)
    assert_equal(
      'Projets actifs (créés / mis à jour dans les 30 derniers jours)',
      contents[0]['name']
    )
    assert_equal 4, contents.length
  end

  test 'Test /en/project_stats/daily_activity.json' do
    get daily_activity_project_stats_path
    contents = JSON.parse(@response.body)
    assert_equal 4, contents.length
    assert_equal 'projects created since day before', contents[0]['name']
    assert_equal 2, contents[0]['data']['2013-05-19 17:44:18 UTC']
    assert_equal 0.8571428571428571, contents[1]['data']['2014-05-25 23:30:19 UTC']
    assert_equal 0.14285714285714285, contents[3]['data']['2014-05-25 23:30:19 UTC']
  end

  test 'Test /en/project_stats/reminders.json' do
    get reminders_project_stats_path
    # Verify that we can parse the result as JSON
    contents = JSON.parse(@response.body)
    # A lame simple sanity test
    assert_not contents.empty?
  end

  test 'Test /project_stats/silver.json' do
    assert '/project_stats/silver.json',
           silver_project_stats_path(locale: nil)
    get silver_project_stats_path(locale: nil)
    # Verify that we can parse the result as JSON
    contents = JSON.parse(@response.body)
    assert_equal 4, contents.length
    assert_not contents.first.empty?
  end

  test 'Test /project_stats/gold.json' do
    assert '/project_stats/gold.json',
           gold_project_stats_path(locale: nil)
    get gold_project_stats_path(locale: nil)
    # Verify that we can parse the result as JSON
    contents = JSON.parse(@response.body)
    assert_equal 4, contents.length
    assert_not contents.first.empty?
  end

  test 'Test /en/project_stats/silver_and_gold.json' do
    get silver_and_gold_project_stats_path
    # Verify that we can parse the result as JSON
    contents = JSON.parse(@response.body)
    assert_not contents.empty?
  end

  test 'Test /en/project_stats/percent_earning.json' do
    get percent_earning_project_stats_path
    # Verify that we can parse the result as JSON
    contents = JSON.parse(@response.body)
    assert_not contents.empty?
  end

  test 'Test /en/project_stats/user_statistics.json' do
    get user_statistics_project_stats_path
    # Verify that we can parse the result as JSON
    contents = JSON.parse(@response.body)
    assert_not contents.empty?
  end

  test 'Unit test of cache_time' do
    # Ensure that cache_time() produces correct answers
    controller = ProjectStatsController.new
    # We'll presume that logs are sent at 23:30 daily
    log_time = ((23 * 60) + 30) * 60
    assert_equal 120, controller.cache_time(log_time - 70)
    assert_equal 120, controller.cache_time(log_time + 70)
    assert_equal log_time, controller.cache_time(0)
    assert_equal log_time - 300, controller.cache_time(300)
    # Test case where time has passed log_time (negative time_left)
    # and we're outside the slop window. In this case, we should respond
    # with a cache for tomorrow's log_time.
    seconds_in_day = 24 * 60 * 60
    assert_equal seconds_in_day - 400, controller.cache_time(log_time + 400)
  end
end
# rubocop:enable Metrics/ClassLength
