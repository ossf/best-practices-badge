# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# Tests for the cached unfiltered projects-index count and its invalidation.
# Transactional tests are disabled here because after_commit callbacks (which
# perform the invalidation) do not fire when the surrounding test transaction
# is rolled back. We clean up created rows and the cache key in teardown.
class ProjectCountCacheTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup { Rails.cache.delete(Project::INDEX_COUNT_CACHE_KEY) }

  teardown do
    Project.where('name LIKE ?', 'CountCache %').delete_all
    Rails.cache.delete(Project::INDEX_COUNT_CACHE_KEY)
  end

  test 'cached_index_count returns the total and populates the cache' do
    base = Project.count
    assert_equal base, Project.cached_index_count(60)
    assert_equal base, Rails.cache.read(Project::INDEX_COUNT_CACHE_KEY)
  end

  test 'creating a project invalidates the cached count' do
    Project.cached_index_count(60) # populate
    assert_not_nil Rails.cache.read(Project::INDEX_COUNT_CACHE_KEY)
    create_count_cache_project
    assert_nil Rails.cache.read(Project::INDEX_COUNT_CACHE_KEY),
               'create should bust the cached count'
  end

  test 'destroying a project invalidates the cached count' do
    project = create_count_cache_project
    Project.cached_index_count(60) # populate
    assert_not_nil Rails.cache.read(Project::INDEX_COUNT_CACHE_KEY)
    project.destroy!
    assert_nil Rails.cache.read(Project::INDEX_COUNT_CACHE_KEY),
               'destroy should bust the cached count'
  end

  private

  def create_count_cache_project
    Project.create!(
      name: 'CountCache project', user: users(:test_user),
      repo_url: 'https://github.com/test/countcache',
      homepage_url: 'https://example.com/countcache'
    )
  end
end
