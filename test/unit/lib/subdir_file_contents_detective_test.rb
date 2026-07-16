# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# CII Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# rubocop:disable Metrics/ClassLength
class SubdirFileContentsDetectiveTest < ActiveSupport::TestCase
  def setup
    super
    @full_name = 'linuxfoundation/cii-best-practices-badge'
    @human_name = 'Core Infrastructure Initiative Best Practices Badge'
    @evidence = Evidence.new({})
    @repo_url = "https://github.com/#{@full_name}"
    @full_name2 = 'david-a-wheeler/test-badge-project'
    @human_name2 = 'A test for transferring projects'
    @evidence2 = Evidence.new({})
    @repo_url = "https://github.com/#{@full_name2}"
  end

  test 'Subdir File Contents Detective Test' do
    VCR.use_cassette('unit_test_subdir_file_contents_detective') do
      results = SubdirFileContentsDetective.new.analyze(
        @evidence,
        repo_files: GithubContentAccess.new(
          'linuxfoundation/cii-best-practices-badge',
          proc { Octokit::Client.new }
        )
      )
      assert results.key?(:documentation_basics_status)
      dbs = results[:documentation_basics_status]
      assert dbs.key?(:explanation)
      assert_equal(
        'Some documentation basics file contents found.',
        dbs[:explanation]
      )
      assert dbs.key?(:value)
      assert_equal CriterionStatus::MET, dbs[:value]
    end
  end

  test 'Subdir File Contents Detective Test for no subdir' do
    VCR.use_cassette('unit_test_subdir_file_contents_detective_unmet') do
      results = SubdirFileContentsDetective.new.analyze(
        @evidence,
        repo_files: GithubContentAccess.new(
          'david-a-wheeler/test-badge-project',
          proc { Octokit::Client.new }
        )
      )
      assert results.key?(:documentation_basics_status)
      dbs = results[:documentation_basics_status]
      assert dbs.key?(:explanation)
      assert_equal(
        'No documentation basics file(s) found.',
        dbs[:explanation]
      )
      assert dbs.key?(:value)
      assert_equal CriterionStatus::UNMET, dbs[:value]
    end
  end

  test 'file fetch returning 404 does not crash' do
    # Regression test: get_info returns [] when a listed file subsequently
    # returns 404 (race condition or transient error). Must return UNMET
    # rather than raising on Base64.decode64(nil).
    mock_repo_files = Object.new
    mock_repo_files.define_singleton_method(:blank?) { false }
    mock_repo_files.define_singleton_method(:get_info) do |path|
      case path
      when '/'
        [{ 'name' => 'docs', 'type' => 'dir' }]
      when 'docs'
        [{ 'name' => 'guide.md', 'type' => 'file', 'path' => 'docs/guide.md' }]
      else
        [] # file fetch returns 404
      end
    end

    results = SubdirFileContentsDetective.new.analyze(
      @evidence, repo_files: mock_repo_files
    )

    assert results.key?(:documentation_basics_status)
    assert_equal CriterionStatus::UNMET, results[:documentation_basics_status][:value]
  end

  # Build a mock repo_files exposing one docs/guide.md file whose GitHub
  # metadata reports the given size and (base64) content.
  def mock_repo_with_file(size:, content:)
    guide = { 'name' => 'g.md', 'type' => 'file', 'path' => 'docs/g.md' }
    responses = {
      '/' => [{ 'name' => 'docs', 'type' => 'dir' }],
      'docs' => [guide],
      'docs/g.md' => guide.merge('size' => size, 'content' => content)
    }
    mock = Object.new
    mock.define_singleton_method(:blank?) { false }
    mock.define_singleton_method(:get_info) { |path| responses.fetch(path, []) }
    mock
  end

  # Control: a small file within the cap is decoded and scanned, and its
  # matching content ("installation") yields MET. This proves the cap does not
  # over-block and that the surrounding mock wiring is correct.
  test 'small documentation file within cap is scanned' do
    mock = mock_repo_with_file(
      size: 20, content: Base64.strict_encode64('installation')
    )
    results = SubdirFileContentsDetective.new.analyze(
      @evidence, repo_files: mock
    )
    assert_equal CriterionStatus::MET,
                 results[:documentation_basics_status][:value]
  end

  # Security: a file whose GitHub-reported size exceeds MAX_FILE_SIZE is
  # skipped without being decoded, even though its content would have matched.
  test 'oversized documentation file is skipped by reported size' do
    mock = mock_repo_with_file(
      size: SubdirFileContentsDetective::MAX_FILE_SIZE + 1,
      content: Base64.strict_encode64('installation')
    )
    results = SubdirFileContentsDetective.new.analyze(
      @evidence, repo_files: mock
    )
    assert_equal CriterionStatus::UNMET,
                 results[:documentation_basics_status][:value]
  end

  # Security: even if GitHub understates the size, the decoded-bytesize
  # re-check catches an oversized file (defense in depth).
  test 'oversized documentation file is skipped when size is understated' do
    huge = 'installation ' * 10_000 # > 100 KB, contains matching text
    mock = mock_repo_with_file(
      size: 10, content: Base64.strict_encode64(huge)
    )
    results = SubdirFileContentsDetective.new.analyze(
      @evidence, repo_files: mock
    )
    assert_equal CriterionStatus::UNMET,
                 results[:documentation_basics_status][:value]
  end

  test 'empty repo returns unmet results without crashing' do
    # GithubContentAccess#get_info returns [] for empty/inaccessible repos
    mock_repo_files = Object.new
    mock_repo_files.define_singleton_method(:blank?) { false }
    mock_repo_files.define_singleton_method(:get_info) { |_path| [] }

    results = SubdirFileContentsDetective.new.analyze(
      @evidence, repo_files: mock_repo_files
    )

    assert results.key?(:documentation_basics_status)
    dbs = results[:documentation_basics_status]
    assert_match(/No appropriate folder found/, dbs[:explanation])
    assert_equal CriterionStatus::UNMET, dbs[:value]
  end

  test 'Subdir File Contents Detective Test for no matching folder' do
    # Mock repo_files that has no matching documentation folder
    mock_repo_files = Object.new
    mock_repo_files.define_singleton_method(:blank?) { false }
    mock_repo_files.define_singleton_method(:get_info) do |path|
      if path == '/'
        # Return top-level with no doc/docs/documentation folder
        [
          { 'name' => 'README.md', 'type' => 'file' },
          { 'name' => 'src', 'type' => 'dir' },
          { 'name' => 'test', 'type' => 'dir' }
        ]
      else
        []
      end
    end

    results = SubdirFileContentsDetective.new.analyze(
      @evidence,
      repo_files: mock_repo_files
    )

    assert results.key?(:documentation_basics_status)
    dbs = results[:documentation_basics_status]
    assert dbs.key?(:explanation)
    assert_match(/No appropriate folder found/, dbs[:explanation])
    assert dbs.key?(:value)
    assert_equal CriterionStatus::UNMET, dbs[:value]
  end
end
# rubocop:enable Metrics/ClassLength
