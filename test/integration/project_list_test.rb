# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

class ProjectListTest < ActionDispatch::IntegrationTest
  setup do
    # @user = users(:test_user)
  end

  test 'get project list and sort by name' do
    get '/en/projects'
    assert_response :success
    assert_select(
      +'table>tbody>tr:first-child>td:nth-child(2)',
      'Pathfinder OS'
    )

    get '/en/projects?sort=name'
    assert_response :success
    assert_select(
      +'table>tbody>tr:first-child>td:nth-child(2)',
      'Another Ascent Vehicle (AAV)'
    )

    get '/en/projects?sort=name&sort_direction=desc'
    assert_response :success
    assert_select(
      +'table>tbody>tr:first-child>td:nth-child(2)',
      'Unjustified perfect project'
    )
  end

  test 'pagination works correctly on project list' do
    # Create additional projects to ensure pagination is triggered
    user = users(:test_user)
    original_count = Project.count
    projects_to_create = 32 - original_count # Ensure we have >30 projects

    if projects_to_create.positive?
      projects_to_create.times do |i|
        Project.create!(
          name: "Test Project #{i}",
          description: "Test description #{i}",
          user: user,
          repo_url: "https://github.com/test/project#{i}",
          homepage_url: "https://example.com/project#{i}"
        )
      end
    end

    get '/en/projects'
    assert_response :success

    # Now we should have pagination
    assert_select '.pagination', minimum: 1
    assert_select '.pagination a[href*="page=2"]', minimum: 1

    # Test that page 2 works
    get '/en/projects?page=2'
    assert_response :success
    # Should still have the main table structure
    assert_select 'table tbody tr', minimum: 1
  end

  # Create enough extra projects to force multiple pages (the limit is 20).
  def create_paginating_projects(total: 45)
    user = users(:test_user)
    [total - Project.count, 0].max.times do |i|
      Project.create!(
        name: "Pager #{i}", user: user,
        repo_url: "https://github.com/test/pager#{i}",
        homepage_url: "https://example.com/pager#{i}"
      )
    end
  end

  test 'canonical link omits page=1 on first page, present on later pages' do
    create_paginating_projects
    get '/en/projects'
    assert_response :success
    assert_select 'link[rel=canonical]', count: 1 do |els|
      # Page 1 must canonicalize to the bare URL (this is what the removed
      # pagy "trim" extra used to ensure).
      assert_no_match(/[?&]page=1\b/, els.first['href'])
      assert_match(%r{/en/projects\z}, els.first['href'])
    end
    get '/en/projects?page=2'
    assert_select 'link[rel=canonical][href*="page=2"]', count: 1
  end

  test 'first and last jump links appear on a middle page' do
    create_paginating_projects # 45 projects => 3 pages of 20
    get '/en/projects?page=2'
    assert_response :success
    assert_select 'a[rel=first]', minimum: 1
    assert_select 'a[rel=last]', minimum: 1
  end

  test 'out-of-range page serves an empty page without error' do
    get '/en/projects?page=99999'
    assert_response :success
    assert_select 'table tbody tr', count: 0
  end

  test 'pagination nav renders in a non-English locale' do
    create_paginating_projects
    get '/fr/projects?page=2'
    assert_response :success
    assert_select 'nav.pagy-bootstrap.series-nav', minimum: 1
  end

  test 'filtered index recounts instead of using the cached total' do
    create_paginating_projects
    # Prime the unfiltered cache with the full count.
    get '/en/projects'
    assert_response :success
    # A text-search filter (already-canonical URL, so no redirect) exercises
    # the recount (count: nil) branch in select_data_subset rather than the
    # cached unfiltered total.
    get '/en/projects?q=Pager'
    assert_response :success
    assert_select 'table tbody tr', minimum: 1
  end
end
