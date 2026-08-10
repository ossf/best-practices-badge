# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# rubocop:disable Metrics/ClassLength
class HardenedSitesDetectiveTest < ActiveSupport::TestCase
  setup do
    @project = projects(:perfect)
    @detective = HardenedSitesDetective.new
    @evidence = Evidence.new(@project)
  end

  test 'missing_security_fields detects all missing fields' do
    headers = {}
    missing = @detective.missing_security_fields(headers)

    assert_includes missing, 'content-security-policy'
    assert_includes missing, 'strict-transport-security'
    assert_includes missing, 'x-content-type-options'
  end

  test 'missing_security_fields returns empty when all present' do
    headers = {
      'content-security-policy' => 'default-src self',
      'strict-transport-security' => 'max-age=31536000',
      'x-content-type-options' => 'nosniff'
    }
    missing = @detective.missing_security_fields(headers)

    assert_empty missing
  end

  test 'missing_frame_options returns empty when x-frame-options present' do
    headers = { 'x-frame-options' => 'DENY' }
    missing = @detective.missing_frame_options(headers)

    assert_empty missing
  end

  test 'missing_frame_options returns empty when CSP has frame-ancestors' do
    headers = {
      'content-security-policy' => "default-src 'self'; frame-ancestors 'none'"
    }
    missing = @detective.missing_frame_options(headers)

    assert_empty missing
  end

  test 'missing_frame_options detects missing frame protection' do
    headers = { 'content-security-policy' => "default-src 'self'" }
    missing = @detective.missing_frame_options(headers)

    assert_equal ['x-frame-options'], missing
  end

  test 'response_headers returns lowercase keys' do
    url = 'https://www.bestpractices.dev/'

    VCR.use_cassette('hardened_sites_headers') do
      headers = @detective.response_headers(@evidence, url)

      # All keys should be lowercase
      headers.each_key do |key|
        assert_equal key, key.downcase
      end
    end
  end

  test 'response_headers handles failed requests' do
    url = 'https://invalid.example.com/'
    headers = @detective.response_headers(@evidence, url)

    assert_equal({}, headers)
  end

  test 'problems_in_url returns empty array when all headers present' do
    url = 'https://secure.example.com/'

    # Stub the fetch cache so get_headers returns all required headers.
    @evidence.instance_variable_set(:@cached_data, {
                                      url => {
                                        meta: {
                                          'content-security-policy' => "default-src 'self'; frame-ancestors 'none'",
                                          'strict-transport-security' => 'max-age=31536000',
                                          'x-content-type-options' => 'nosniff'
                                        },
                                        body_raw: nil, encoding: nil
                                      }
                                    })

    problems = @detective.problems_in_url(@evidence, url)

    assert_empty problems
  end

  test 'problems_in_url reports missing headers with URL' do
    url = 'https://insecure.example.com/'

    # Stub the fetch cache so get_headers returns headers without the
    # required security headers.
    @evidence.instance_variable_set(:@cached_data, {
                                      url => {
                                        meta: {},
                                        body_raw: nil, encoding: nil
                                      }
                                    })

    problems = @detective.problems_in_url(@evidence, url)

    assert_equal 1, problems.size
    assert_match(/#{Regexp.escape(url)}/, problems.first)
    assert_match(/content-security-policy/, problems.first)
  end

  test 'problems_in_urls collects problems from multiple URLs' do
    url1 = 'https://site1.example.com/'
    url2 = 'https://site2.example.com/'

    @evidence.instance_variable_set(:@cached_data, {
                                      url1 => { meta: {}, body_raw: nil, encoding: nil },
      url2 => { meta: {}, body_raw: nil, encoding: nil }
                                    })

    problems = @detective.problems_in_urls(@evidence, [url1, url2])

    assert_equal 2, problems.size
  end

  test 'analyze returns MET when all security headers present' do
    homepage_url = 'https://secure.example.com/'
    repo_url = 'https://github.com/example/repo'

    @evidence.instance_variable_set(:@cached_data, {
                                      homepage_url => {
                                        meta: {
                                          'content-security-policy' => "default-src 'self'; frame-ancestors 'none'",
                                          'strict-transport-security' => 'max-age=31536000',
                                          'x-content-type-options' => 'nosniff'
                                        },
                                        body_raw: nil, encoding: nil
                                      },
      repo_url => {
        meta: {
          'content-security-policy' => "default-src 'self'; frame-ancestors 'none'",
          'strict-transport-security' => 'max-age=31536000',
          'x-content-type-options' => 'nosniff'
        },
        body_raw: nil, encoding: nil
      }
                                    })

    result = @detective.analyze(
      @evidence,
      { homepage_url: homepage_url, repo_url: repo_url }
    )

    assert_equal CriterionStatus::MET, result[:hardened_site_status][:value]
    assert_equal 3, result[:hardened_site_status][:confidence]
  end

  test 'analyze returns UNMET when security headers missing' do
    homepage_url = 'https://insecure.example.com/'
    repo_url = 'https://github.com/example/repo'

    @evidence.instance_variable_set(:@cached_data, {
                                      homepage_url => { meta: {}, body_raw: nil, encoding: nil },
      repo_url => { meta: {}, body_raw: nil, encoding: nil }
                                    })

    result = @detective.analyze(
      @evidence,
      { homepage_url: homepage_url, repo_url: repo_url }
    )

    assert_equal CriterionStatus::UNMET, result[:hardened_site_status][:value]
    assert_equal 5, result[:hardened_site_status][:confidence]
    assert_match(/Required security hardening headers missing/,
                 result[:hardened_site_status][:explanation])
  end

  test 'analyze returns empty when homepage_url missing' do
    result = @detective.analyze(
      @evidence,
      { homepage_url: nil, repo_url: 'https://github.com/example/repo' }
    )

    assert_equal({}, result)
  end

  test 'analyze returns empty when repo_url missing' do
    result = @detective.analyze(
      @evidence,
      { homepage_url: 'https://example.com/', repo_url: nil }
    )

    assert_equal({}, result)
  end
end
# rubocop:enable Metrics/ClassLength
