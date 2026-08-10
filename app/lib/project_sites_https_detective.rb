# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Determine if project sites support HTTPS

class ProjectSitesHttpsDetective < Detective
  INPUTS = %i[repo_url homepage_url].freeze
  OUTPUTS = %i[
    sites_https_status osps_br_03_01_status osps_br_03_02_status
  ].freeze

  # This detective can override with high confidence when detecting
  # HTTP vs HTTPS usage (confidence 3-5), because http:// URL being listed
  # as an official source is a *problem*.
  OVERRIDABLE_OUTPUTS = %i[
    sites_https_status osps_br_03_01_status
  ].freeze

  HTTP_PATTERN = %r{\Ahttp://}i
  HTTPS_PATTERN = %r{\Ahttps://}i

  def analyze(_evidence, current)
    homepage_url = current[:homepage_url]
    repo_url = current[:repo_url]
    @results = {}

    if homepage_url =~ HTTP_PATTERN || repo_url =~ HTTP_PATTERN
      set_http_results
    elsif homepage_url.present? || repo_url.present?
      set_https_results if homepage_url =~ HTTPS_PATTERN ||
                           repo_url =~ HTTPS_PATTERN
    end
    @results
  end

  private

  # rubocop:disable Metrics/MethodLength
  def set_http_results
    @results[:sites_https_status] =
      {
        value: CriterionStatus::UNMET, confidence: 5,
        explanation: I18n.t('detectives.project_sites_https.given_http')
      }
    # Any official channel using http is a problem
    @results[:osps_br_03_01_status] =
      {
        value: CriterionStatus::UNMET, confidence: 5,
        explanation: I18n.t('detectives.project_sites_https.official_http')
      }
    # We don't know enough to be *certain* what the distribution channels
    # are; it's possible that the official distribution channels *are*
    # encrypted (authenticated). However, if we have any http: links, odds
    # are good that we have a distribution channel that's not
    # properly protected.
    @results[:osps_br_03_02_status] =
      {
        value: CriterionStatus::UNMET, confidence: 3,
        explanation: I18n.t('detectives.project_sites_https.url_uses_http')
      }
  end
  # rubocop:enable Metrics/MethodLength

  def met_result(explanation)
    { value: CriterionStatus::MET, confidence: 3, explanation: explanation }
  end

  def set_https_results
    @results[:sites_https_status] =
      met_result(I18n.t('detectives.project_sites_https.given_https'))
    @results[:osps_br_03_01_status] =
      met_result('Project URLs use HTTPS exclusively.')
    @results[:osps_br_03_02_status] =
      met_result('Distribution channels use HTTPS exclusively.')
  end
end
