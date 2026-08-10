# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

class BuildDetectiveTest < ActiveSupport::TestCase
  setup do
    @full_name = 'linuxfoundation/cii-best-practices-badge'
    @human_name = 'Core Infrastructure Initiative Best Practices Badge'
    @evidence = Evidence.new({})
    @repo_url = "https://github.com/#{@full_name}"
  end

  test 'Build' do
    results = BuildDetective.new.analyze(@evidence, repo_url: @repo_url)
    assert results == {}
  end

  # Mock repo_files that simulates an empty GitHub repo.
  # GithubContentAccess#get_info returns [] for empty repos.
  class MockEmptyRepoFiles
    def blank?
      false
    end

    def get_info(_path)
      []
    end
  end

  test 'empty repo returns empty results' do
    repo_files = MockEmptyRepoFiles.new
    results = BuildDetective.new.analyze(
      @evidence, repo_url: @repo_url, repo_files: repo_files
    )
    assert_equal({}, results)
  end
end
