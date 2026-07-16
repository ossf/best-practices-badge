# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Examine repository files at the top level and in key subdirectories
# (those conventionally used for source and documentation).
# Note that a key precondition is determining how to open repo files.

class SubdirFileContentsDetective < Detective
  INPUTS = [:repo_files].freeze
  OUTPUTS = %i[documentation_basics_status].freeze

  # This detective can override documentation criteria with moderate confidence
  OVERRIDABLE_OUTPUTS = %i[documentation_basics_status].freeze

  DOCS_BASICS = {
    folder: /\Adoc(s|umentation)?\Z/i,
    file: /(\.md|\.markdown|\.txt|\.html)?\Z/i,
    contents: [/install(ation)?/i, /us(e|ing)/i, /secur(e|ity)/i].freeze
  }.freeze

  def unmet_result(result_description)
    {
      value: CriterionStatus::UNMET, confidence: 1,
      explanation: I18n.t('detectives.subdir_files.no_files_found',
                          description: result_description)
    }
  end

  def unmet_result_folder(result_description)
    {
      value: CriterionStatus::UNMET, confidence: 3,
      explanation: I18n.t('detectives.subdir_files.no_folder_found',
                          description: result_description)
    }
  end

  def met_result(result_description)
    {
      value: CriterionStatus::MET, confidence: 3,
      explanation: I18n.t('detectives.subdir_files.some_contents_found',
                          description: result_description)
    }
  end

  def match_fso?(fso, type, name_pattern)
    fso['type'] == type && fso['name'].match(name_pattern)
  end

  def folder_named(name_pattern)
    @top_level.select do |fso|
      return fso['name'] if match_fso?(fso, 'dir', name_pattern)
    end
    nil
  end

  # Maximum size (bytes) of a repo file we will decode and scan for content
  # matches. Matches the cap used by the JSON and security-insights detectives
  # so a malicious repo cannot make us decode and scan an oversized file.
  # GitHub's contents API already inlines the (base64) content in the metadata
  # response, so we enforce the cap without an extra request.
  MAX_FILE_SIZE = 100_000

  # Fetch and decode the content of a single file entry.
  # Returns nil when get_info returns 404 ([] or nil), the entry has no
  # content, or the file exceeds MAX_FILE_SIZE (untrusted repo data).
  def fetch_file_content(repo_files, fso)
    file_entry = repo_files.get_info(fso['path'])
    return if file_entry.blank? || file_entry.is_a?(Array)
    return if file_entry['content'].blank?
    # Skip oversized files using GitHub's reported size before decoding.
    return if file_entry['size'].to_i > MAX_FILE_SIZE

    content = Base64.decode64(file_entry['content'])
    # Defense in depth: re-check the actual decoded size in case the reported
    # size was missing or understated.
    return if content.bytesize > MAX_FILE_SIZE

    content
  end

  def match_file_content(repo_files, folder, patterns, description)
    files = repo_files.get_info(folder)
    files = files.select { |f| match_fso?(f, 'file', patterns[:file]) }
    files.each do |fso|
      content = fetch_file_content(repo_files, fso)
      next if content.nil?
      return met_result description if patterns[:contents].any? { |p| content.match?(p) }
    end
    unmet_result description
  end

  def determine_content_results(repo_files, status, patterns, description)
    folder = folder_named(patterns[:folder])
    @results[status] =
      if folder.nil?
        unmet_result_folder description
      else
        match_file_content(repo_files, folder, patterns, description)
      end
  end

  def analyze(_evidence, current)
    repo_files = current[:repo_files]
    return {} if repo_files.blank?

    @results = {}

    # Top_level is iterable, contains a hash with name, size, type (file|dir).
    @top_level = repo_files.get_info('/')
    determine_content_results(
      repo_files, :documentation_basics_status, DOCS_BASICS,
      'documentation basics'
    )

    set_baseline_documentation_status

    @results
  end

  # Set baseline README criterion if documentation basics are met
  def set_baseline_documentation_status
    return unless @results[:documentation_basics_status]&.dig(:value) == CriterionStatus::MET
  end
end
