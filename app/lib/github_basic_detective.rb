# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'json'

# If it's a GitHub repo, grab easily-acquired data from GitHub API and
# use it to determine key values for project.

# WARNING: The JSON parser generates a 'normal' Ruby hash.
# Be sure to use strings, NOT symbols, as a key when accessing JSON-parsed
# results (because strings and symbols are distinct in basic Ruby).

# rubocop:disable Metrics/ClassLength
class GithubBasicDetective < Detective
  # Individual detectives must identify their inputs, outputs
  INPUTS = [:repo_url].freeze
  OUTPUTS = %i[
    name license discussion_status repo_public_status repo_track_status
    repo_distributed_status contribution_status implementation_languages
    osps_do_02_01_status osps_gv_02_01_status
    osps_ac_01_01_status
    osps_qa_01_01_status osps_qa_01_02_status
  ].freeze

  # This detective can override with high confidence for repo-based criteria
  # name and implementation_languages are lower confidence (suggestions)
  OVERRIDABLE_OUTPUTS = %i[
    repo_track_status repo_distributed_status
  ].freeze

  EXCLUDE_IMPLEMENTATION_LANGUAGES = [
    :HTML, :CSS, :Roff, :'DIGITAL Command Language'
  ].freeze

  # Take JSON data of form {:language => lines_of_code, ...}
  # and return a cleaned-up string representing it.  We forcibly sort
  # it by LOC (GitHub returns it that way, but I don't see any guarantee,
  # so we sort it to make sure).  We also exclude languages that most people
  # wouldn't expect to see listed.
  # Currently we include *all* languages listed; if it's a long list, the
  # later ones are more likely to be a mistake, but it's hard to figure out
  # where to cut things off.
  def language_cleanup(raw_language_data)
    return '' if raw_language_data.blank?

    full_list = raw_language_data.sort_by(&:last).reverse.map(&:first)
    shorter_list = full_list - EXCLUDE_IMPLEMENTATION_LANGUAGES
    shorter_list.join(', ')
  end

  # Individual detectives must implement "analyze"
  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def analyze(_evidence, current)
    repo_url = current[:repo_url]
    return {} if repo_url.nil?

    results = {}
    # Has form https://github.com/:user/:name?
    # e.g.: https://github.com/ossf/best-practices-badge
    # Note: this limits what's accepted, otherwise we'd have to worry
    # about URL escaping.
    # rubocop:disable Metrics/BlockLength
    repo_url.match(
      %r{\Ahttps://github.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)/?\Z}
    ) do |m|
      # We have a github repo.
      results[:repo_public_status] = {
        value: CriterionStatus::MET, confidence: 3,
        explanation: I18n.t('detectives.github.repo_public')
      }
      results[:repo_track_status] = {
        value: CriterionStatus::MET, confidence: 4,
        explanation: I18n.t('detectives.github.repo_track')
      }
      results[:repo_distributed_status] = {
        value: CriterionStatus::MET, confidence: 4,
        explanation: I18n.t('detectives.github.repo_distributed')
      }
      results[:contribution_status] = {
        value: CriterionStatus::MET, confidence: 2,
        explanation: I18n.t('detectives.github.contribution')
      }
      results[:discussion_status] = {
        value: CriterionStatus::MET, confidence: 3,
        explanation: I18n.t('detectives.github.discussion')
      }
      # Baseline: public discussion mechanisms (same evidence as discussion_status)
      results[:osps_gv_02_01_status] = {
        value: CriterionStatus::MET, confidence: 3,
        explanation: I18n.t('detectives.github.osps_gv_02_01')
      }
      # Baseline criteria - defect reporting instructions (low confidence)
      results[:osps_do_02_01_status] = {
        value: CriterionStatus::MET, confidence: 2,
        explanation: I18n.t('detectives.github.osps_do_02_01')
      }
      # 2FA required by GitHub. An organization *might* use multiple repo
      # hosts, but given our information, 2FA seems highly likely.
      results[:osps_ac_01_01_status] = {
        value: CriterionStatus::MET, confidence: 3,
        explanation: I18n.t('detectives.github.osps_ac_01_01')
      }
      # Publicly readable, if we can read it. It's possible it's not current,
      # but if this really is the "main" repo (as claimed) then this is met.
      results[:osps_qa_01_01_status] = {
        value: CriterionStatus::MET, confidence: 3,
        explanation: I18n.t('detectives.github.osps_qa_01_01')
      }
      # If the main repo is on GitHub, then git will store this
      results[:osps_qa_01_02_status] = {
        value: CriterionStatus::MET, confidence: 3,
        explanation: I18n.t('detectives.github.osps_qa_01_02')
      }

      # Get basic evidence
      fullname = m[1] + '/' + m[2]
      client = Octokit::Client.new
      return results unless client

      basic_repo_data = client.repository fullname

      return results unless basic_repo_data

      if basic_repo_data[:name]
        results[:name] = {
          value: basic_repo_data[:name],
          confidence: 3, explanation: I18n.t('detectives.github.name')
        }
      end
      if basic_repo_data[:description]
        results[:description] = {
          value: basic_repo_data[:description].gsub(
            /(\A|\s)\:[a-zA-Z]+\:(\s|\Z)/, ' '
          ).strip,
          confidence: 3, explanation: I18n.t('detectives.github.description')
        }
      end
      # rubocop:enable Metrics/BlockLength

      # Ask GitHub what the license is. GitHub uses the licensee gem and
      # returns the SPDX identifier in spdx_id with correct case.
      # NOASSERTION means GitHub could not identify the license; skip it.
      license_spdx_id = basic_repo_data[:license]&.dig(:spdx_id)
      if license_spdx_id.present? && license_spdx_id != 'NOASSERTION'
        results[:license] = {
          value: license_spdx_id,
          confidence: 3, explanation: I18n.t('detectives.github.license')
        }
      end

      # Fill in programming languages
      raw_language_data = client.languages(fullname) # Download
      implementation_languages = language_cleanup(raw_language_data)
      results[:implementation_languages] = {
        value: implementation_languages,
        confidence: 3,
        explanation: I18n.t('detectives.github.implementation_languages')
      }
    end

    results
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
end
# rubocop:enable Metrics/ClassLength
