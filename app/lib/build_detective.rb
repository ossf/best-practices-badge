# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# require 'json' # uncomment if you need to access GitHub
# require 'nokogiri'  # For future use to search more thoroughly
# require 'open-uri'  # For future use to search more thoroughly
# WARNING: The JSON parser generates a 'normal' Ruby hash.
# Be sure to use strings, NOT symbols, as a key when accessing JSON-parsed
# results (because strings and symbols are distinct in basic Ruby).
# rubocop:disable Metrics/MethodLength
class BuildDetective < Detective
  # Individual detectives must identify their inputs, outputs
  INPUTS = %i[repo_url repo_files].freeze # repo_url for future use
  OUTPUTS = %i[build_status build_common_tools_status].freeze

  # This detective can override build tool detection with moderate confidence
  OVERRIDABLE_OUTPUTS = %i[build_status build_common_tools_status].freeze

  def files_named(name_pattern)
    @top_level.select do |fso|
      fso['type'] == 'file' && fso['name'].match(name_pattern)
    end
  end

  def met_result(result_description, html_url)
    {
      value: CriterionStatus::MET, confidence: 3,
      explanation: I18n.t('detectives.repo_files.file_found',
                          description: result_description, url: html_url)
    }
  end

  def determine_results(status, name_pattern, result_description)
    found_files = files_named(name_pattern)
    if found_files.empty?
    else
      @results[status] =
        met_result result_description, found_files.first['html_url']
    end
  end

  def analyze(_evidence, current)
    # repo_url = current[:repo_url] # For future use to search more thoroughly
    # doc = Nokogiri::HTML(open(repo_url)) # For future use to search
    # more thoroughly
    repo_files = current[:repo_files]
    @results = {} # Blank results for return
    return {} if repo_files.blank?

    # Top_level is iterable, contains a hash with name, size, type (file|dir).
    @top_level = repo_files.get_info('/')
    # doc.css('a').each do |link| # For future use to search more thoroughly
    # TODO perform search on actual tree rather than just top level.
    determine_results(
      :build_status,
      /\A(
          Makefile|                 # Make
          GNUmakefile|              # GNU make specific
          autoconf.ac|automake.am|  # autotools
          CMakeLists\.txt|          # cmake
          Rakefile|                 # rake, common for Ruby
          pom\.xml|                 # Maven, common for Java
          build\.xml|               # Ant, common for Java
          .*\.proj|                 # msbuild
          build\.sbt|               # SBT, for Scala
          SConstruct|               # SCONS. Uses Python.
          wscript                   # WAF build system
        )\Z
      /ix, 'build'
    )
    # If we can detect it, it's common enough to be considered common.
    if @results.key?(:build_status)
      @results[:build_common_tools_status] = @results[:build_status]
    end

    @results
  end
end
# rubocop:enable Metrics/MethodLength
