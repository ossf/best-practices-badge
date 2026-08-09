# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# rubocop:disable Metrics/ClassLength
class GithubContentAccessTest < ActiveSupport::TestCase
  # Mock Octokit client that raises NotFound (simulates empty repo)
  class MockOctokitEmpty
    def contents(_fullname, **)
      raise Octokit::NotFound
    end
  end

  # Mock Octokit client that returns normal contents
  class MockOctokitNormal
    CONTENTS = [
      { 'name' => 'README.md', 'type' => 'file', 'size' => 100 }
    ].freeze

    def contents(_fullname, **)
      CONTENTS
    end
  end

  test 'get_info returns empty array by default when repo returns NotFound' do
    access = GithubContentAccess.new(
      'owner/empty-repo', proc { MockOctokitEmpty.new }
    )
    assert_equal [], access.get_info('/')
  end

  test 'get_info returns nil when not_found_result: nil and repo returns NotFound' do
    access = GithubContentAccess.new(
      'owner/empty-repo', proc { MockOctokitEmpty.new }
    )
    assert_nil access.get_info('/', not_found_result: nil)
  end

  test 'get_info returns contents normally for non-empty repo' do
    access = GithubContentAccess.new(
      'owner/some-repo', proc { MockOctokitNormal.new }
    )
    result = access.get_info('/')

    assert_equal MockOctokitNormal::CONTENTS, result
  end

  # Tests for get_content method

  test 'get_content returns nil when file not found' do
    access = GithubContentAccess.new(
      'owner/repo', proc { MockOctokitEmpty.new }
    )
    result = access.get_content('missing.txt')

    assert_nil result
  end

  test 'get_content returns nil when path is a directory' do
    mock_client =
      Class.new do
        def contents(_fullname, **)
          { 'type' => 'dir', 'name' => 'src' }
        end
      end

    access = GithubContentAccess.new('owner/repo', proc { mock_client.new })
    result = access.get_content('src')

    assert_nil result
  end

  test 'get_content returns nil when file exceeds max_size' do
    mock_client =
      Class.new do
        def contents(_fullname, **)
          {
            'type' => 'file',
            'size' => 100_000, # 100KB
            'content' => Base64.encode64('x' * 100_000)
          }
        end
      end

    access = GithubContentAccess.new('owner/repo', proc { mock_client.new })
    result = access.get_content('huge.txt', max_size: 50_000)

    assert_nil result
  end

  test 'get_content logs at info level when file exceeds max_size' do
    mock_client =
      Class.new do
        def contents(_fullname, **)
          {
            'type' => 'file',
            'size' => 100_000, # 100KB
            'content' => Base64.encode64('x' * 100_000)
          }
        end
      end

    access = GithubContentAccess.new('owner/repo', proc { mock_client.new })

    log_output = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(log_output)
    begin
      result = access.get_content('huge.txt', max_size: 50_000)
    ensure
      Rails.logger = original_logger
    end

    assert_nil result
    assert_match(/huge\.txt exceeds max_size/, log_output.string)
    assert_match(/100000 bytes > 50000/, log_output.string)
  end

  test 'get_content returns nil when content is blank' do
    mock_client =
      Class.new do
        def contents(_fullname, **)
          { 'type' => 'file', 'size' => 0, 'content' => '' }
        end
      end

    access = GithubContentAccess.new('owner/repo', proc { mock_client.new })
    result = access.get_content('empty.txt')

    assert_nil result
  end

  test 'get_content returns nil when actual content exceeds reported size' do
    # Defense in depth: reject if GitHub's size claim doesn't match reality
    mock_client =
      Class.new do
        def contents(_fullname, **options)
          if options[:accept] == 'application/vnd.github.raw'
            # Return huge content (attacker scenario)
            'x' * 100_000
          else
            # Claim small size
            { 'type' => 'file', 'size' => 1000 }
          end
        end
      end

    access = GithubContentAccess.new('owner/repo', proc { mock_client.new })
    result = access.get_content('malicious.txt', max_size: 50_000)

    assert_nil result # Should reject due to actual size > max_size
  end

  test 'get_content logs at warn level when actual content exceeds reported size' do
    mock_client =
      Class.new do
        def contents(_fullname, **options)
          if options[:accept] == 'application/vnd.github.raw'
            # Attacker scenario: huge content under a small-size claim
            'x' * 100_000
          else
            { 'type' => 'file', 'size' => 1000 }
          end
        end
      end

    access = GithubContentAccess.new('owner/repo', proc { mock_client.new })

    log_output = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(log_output, level: Logger::WARN)
    begin
      result = access.get_content('lying.txt', max_size: 50_000)
    ensure
      Rails.logger = original_logger
    end

    assert_nil result
    assert_match(/lying\.txt actual size 100000/, log_output.string)
    assert_match(/possible GitHub size misreport or MITM/, log_output.string)
  end

  test 'get_content decodes valid base64 content' do
    test_content = 'Hello, World!'
    mock_client =
      Class.new do
        define_method(:contents) do |_fullname, **options|
          if options[:accept] == 'application/vnd.github.raw'
            # Return raw content
            test_content
          else
            # Return metadata
            {
              'type' => 'file',
              'size' => test_content.bytesize
            }
          end
        end
      end

    access = GithubContentAccess.new('owner/repo', proc { mock_client.new })
    result = access.get_content('test.txt')

    assert_equal test_content, result
  end

  test 'get_content returns nil when exception occurs' do
    mock_client =
      Class.new do
        def contents(_fullname, **)
          raise StandardError, 'API error'
        end
      end

    access = GithubContentAccess.new('owner/repo', proc { mock_client.new })
    result = access.get_content('error.txt')

    assert_nil result
  end
end
# rubocop:enable Metrics/ClassLength
