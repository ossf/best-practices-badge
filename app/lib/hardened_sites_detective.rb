# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Determine if project sites support HTTPS

class HardenedSitesDetective < Detective
  # All of the security-hardening headers that need to be present to pass.
  # They're listed in the same order as the criteria text.
  # We don't list 'x-frame-options' here because there's a CSP alternative.
  # Technically 'x-content-type-options' must be 'nosniff' but if you can
  # set it at all, you can set it correctly, so we don't bother to dig further.
  # Field names must be in lowercase here.
  REQUIRED_FIELDS = %w[
    content-security-policy strict-transport-security
    x-content-type-options
  ].freeze

  def met_result
    {
      value: CriterionStatus::MET, confidence: 3,
      explanation: I18n.t('detectives.hardened_sites.all_headers_found')
    }
  end

  def unmet_missing_result
    {
      value: CriterionStatus::UNMET, confidence: 5,
      explanation: I18n.t('detectives.hardened_sites.headers_missing')
    }
  end

  INPUTS = %i[repo_url homepage_url].freeze
  OUTPUTS = [:hardened_site_status].freeze

  # This detective can override hardened site detection with high confidence
  OVERRIDABLE_OUTPUTS = [:hardened_site_status].freeze

  # Check the given hash of header values to make sure that all expected
  # keys are present. Return a list of missing fields (preferably empty).
  def missing_security_fields(headers)
    result = []
    REQUIRED_FIELDS.each do |required_item|
      if !headers.key?(required_item)
        result.append(required_item.to_s)
      end
    end
    result
  end

  # Return a list of missing frame-options fields (preferably empty).
  # Using content-security-policy's frame-ancestors is a valid way to do it.
  # Instead of parsing content-security-policy,
  # we just check for the string 'frame-ancestors'. That can be fooled by
  # weird CSPs, but this isn't expected to be a problem, and people who do
  # that are just hurting themselves.
  def missing_frame_options(headers)
    if headers.key?('x-frame-options') ||
       (headers.key?('content-security-policy') &&
        headers['content-security-policy'].include?('frame-ancestors'))
      []
    else
      ['x-frame-options']
    end
  end

  # Perform GET request, and return either an empty hash (if the GET is
  # unsuccessful) or a hash of the HTTP response header keys and values.
  # Note: in the returned hash all field names are ASCII *lowercase*, so that
  # we can easily do case-insensitive matches (HTTP field names are
  # case-insensitive, see RFC 2616 section 4.2).
  def response_headers(evidence, url)
    # We only need the response headers here, so use get_headers (no body).
    results = evidence.get_headers(url) || {}
    # Return a version with keys in lowercase; we do *not* modify the original.
    # We use ":ascii" so that Turkic locales don't cause oddities. That
    # shouldn't matter anyway, since the user's locale is in I18n.locale,
    # but it's safer to be defensive.
    results.transform_keys { |k| k.to_s.downcase(:ascii) }
  end

  # Given evidence and a URL, return the list of problems with it.
  def problems_in_url(evidence, url)
    headers = response_headers(evidence, url)
    problems = missing_security_fields(headers)
    problems += missing_frame_options(headers)
    if problems.empty?
      problems
    else
      ["#{url}: #{problems.join(', ')}"]
    end
  end

  # Given evidence and set of URLs, return the list of problems with the URLs
  def problems_in_urls(evidence, urls)
    all_problems = []
    urls.each do |url|
      all_problems += problems_in_url(evidence, url)
    end
    all_problems
  end

  # Internal method that does the inspection work for the 'analyze' method.
  # rubocop:disable Metrics/MethodLength
  def report_on_check_urls(evidence, homepage_url, repo_url)
    results = {}
    # Only complain if we have *both* a homepage_url AND repo_url.
    # When that isn't true other criteria will catch it first.
    if homepage_url.present? && repo_url.present?
      urls = [homepage_url, repo_url].to_set
      all_problems = problems_in_urls(evidence, urls)
      results[:hardened_site_status] =
        if all_problems.empty?
          met_result
        else
          answer = unmet_missing_result
          answer[:explanation] += all_problems.join(', ')
          answer
        end
    end
    results
  end
  # rubocop:enable Metrics/MethodLength

  # Analyze the home page and repository URLs to make sure that security
  # hardening headers are returned in the headers of a GET response.
  def analyze(evidence, current)
    report_on_check_urls(evidence, current[:homepage_url], current[:repo_url])
  end
end
