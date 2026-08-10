# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Determine how to open the development files in the repository,
# and set an appropriate :repo_files accessor.
# Currently we only handle GitHub; extend this to support other ways.

class HowAccessRepoFilesDetective < Detective
  # Individual detectives must identify their inputs, outputs
  INPUTS = [:repo_url].freeze
  OUTPUTS = [:repo_files].freeze # Ask :repo_files.get("FILENAME") for files.

  # This detective provides data access, not user-facing criteria values
  # Cannot override user input
  OVERRIDABLE_OUTPUTS = [].freeze

  GITHUB_REPO = %r{https?://github.com/([\w\.-]*)/([\w\.-]*)(.git|/)?}
  def analyze(_evidence, current)
    repo_url = current[:repo_url]
    return {} if repo_url.blank?

    github_match = repo_url.match(GITHUB_REPO)
    github_match ? assemble_result("#{github_match[1]}/#{github_match[2]}") : {}
  end

  def assemble_result(fullname)
    {
      repo_files:
                {
                  value: GithubContentAccess.new(fullname,
                                                 @octokit_client_factory),
                  confidence: 5
                }
    }
  end
end
