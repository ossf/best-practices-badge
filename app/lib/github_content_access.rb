# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Accessor to GitHub so we can read (file) content info from GitHub.
# Use this indirect class so that we can later plug in other accessors to
# read data from other locations.
class GithubContentAccess
  def initialize(fullname, octokit_client_factory)
    @fullname = fullname
    @octokit_client_factory = octokit_client_factory
    @octokit_client = nil
  end

  # The GitHub contents API is defined here:
  # https://developer.github.com/v3/repos/contents/
  # Basically: https://api.github.com/repos/:owner/:repo/contents/:path
  # E.G.: https://api.github.com/repos/
  # linuxfoundation/cii-best-practices-badge/contents
  # We use the Octokit gem to simplify access.

  EMPTY = [].freeze

  # Given a filename, reply with information about it.
  # - For files (type='file') this is a hash of data
  #   Fields include: name, path, size, html_url.
  # - For directories (type='dir') this is an iterable set of hashes;
  #   each hash represents a filesystem object (see above)
  # The GitHub contents API returns 404 in several situations:
  # private repos accessed without auth (GitHub returns 404, not 403, to
  # avoid revealing that the repo exists), deleted repos, and occasionally
  # transient errors. Note: empty repos return 409 Conflict, not 404.
  #
  # @param not_found_result [Object] value to return when the GitHub API
  #   returns 404. Defaults to EMPTY (a frozen []) so callers can iterate
  #   safely. Pass nil when the caller needs to distinguish a successful
  #   (possibly empty) scan from an inaccessible repo.
  def get_info(filename, not_found_result: EMPTY)
    @octokit_client = @octokit_client_factory.call if @octokit_client.nil?
    @octokit_client.contents @fullname, path: filename
  rescue Octokit::NotFound
    not_found_result
  end

  # Get the actual content of a file (not just metadata).
  # @param filename [String] path to file
  # @param max_size [Integer] maximum file size in bytes
  # @return [String, nil] file content or nil if not found/too large/error
  #
  # SECURITY NOTE: DoS Protection Limitation
  # =========================================
  # This method CANNOT truly limit bytes read from the network. The GitHub API
  # (via Octokit gem) reads the entire HTTP response into memory before
  # returning to us. By the time we have the content, it's already in RAM.
  #
  # Our DoS protection strategy relies on TRUSTING GitHub's size field:
  # 1. We check GitHub's reported size BEFORE fetching content (first API call)
  # 2. If size > max_size, we don't fetch content (avoiding the second call)
  # 3. After fetching, we verify actual size matches (defense in depth)
  #
  # This trust assumption is acceptable because:
  # - GitHub's API over HTTPS (not user-supplied data)
  # - GitHub has no incentive to misreport file sizes
  # - We verify the actual content size after receiving it
  #
  # However, this means a compromised GitHub or MITM attack could still cause
  # us to load oversized content into memory. If this is unacceptable, the
  # only solution is HTTP streaming with size limits at a lower level than
  # the Octokit gem provides.
  # rubocop:disable Metrics/MethodLength
  def get_content(filename, max_size: 100_000)
    # First, get metadata to check size BEFORE fetching content
    file_info = get_info(filename)
    return if file_info.blank? || file_info.is_a?(Array)
    return if file_info['type'] != 'file'

    # Trust but verify: Check GitHub's reported size before fetching
    if file_info['size'] > max_size
      Rails.logger.info(
        "GithubContentAccess: #{filename} exceeds max_size " \
        "(#{file_info['size']} bytes > #{max_size}); skipping fetch"
      )
      return
    end

    # Now fetch raw content. GitHub already told us the size is OK.
    # Use raw API to get unencoded content (avoids base64 overhead).
    @octokit_client = @octokit_client_factory.call if @octokit_client.nil?
    content = @octokit_client.contents(
      @fullname,
      path: filename,
      accept: 'application/vnd.github.raw'
    )

    # Defense in depth: Verify actual size matches GitHub's claim
    if content.bytesize > max_size
      Rails.logger.warn(
        "GithubContentAccess: #{filename} actual size #{content.bytesize} " \
        "bytes exceeds reported #{file_info['size']} and max_size #{max_size}; " \
        'rejecting (possible GitHub size misreport or MITM)'
      )
      return
    end

    content
  rescue StandardError
    nil
  end
  # rubocop:enable Metrics/MethodLength
end
