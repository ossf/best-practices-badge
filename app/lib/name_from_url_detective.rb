# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Guess project name from URLs.

class NameFromUrlDetective < Detective
  INPUTS = %i[repo_url homepage_url].freeze
  OUTPUTS = [:name].freeze

  # This detective suggests names but should not override user input
  # (confidence level 1 - suggestion only)
  OVERRIDABLE_OUTPUTS = [].freeze

  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def analyze(_evidence, current)
    homepage_url = current[:homepage_url]
    repo_url = current[:repo_url]
    @results = {}

    name_in_homepage_url_domain =
      %r{\Ahttps?://(www\.)?([A-Za-z0-9-]+)\.([A-Za-z0-9._-]*)/?\Z}
    name_in_url_tail = %r{[^/]/([A-Za-z0-9._-]*)/?\Z}

    if homepage_url.present?
      finding = name_in_homepage_url_domain.match(homepage_url)
      if finding && finding[2].present?
        @results[:name] =
          {
            value: finding[2], confidence: 1,
            explanation: I18n.t('detectives.name_from_url.domain_suggests')
          }
      else
        finding = name_in_url_tail.match(homepage_url)
        if finding
          @results[:name] =
            {
              value: finding[1], confidence: 1,
              explanation: I18n.t('detectives.name_from_url.tail_suggests')
            }
        end
      end
    end
    if !@results.key?(:name) && repo_url.present?
      finding = name_in_url_tail.match(repo_url)
      if finding
        @results[:name] =
          {
            value: finding[1], confidence: 1,
            explanation: I18n.t('detectives.name_from_url.repo_tail_suggests')
          }
      end
    end
    @results
  end
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
end
