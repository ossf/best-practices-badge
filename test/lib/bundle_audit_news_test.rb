# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# No require_relative, for the reason given in
# test/lib/heroku_ruby_availability_test.rb: lib/ autoloads, and
# requiring it here would load it in the parent process and hide its
# coverage.
class BundleAuditNewsTest < ActiveSupport::TestCase
  # bundle-audit's real output shape, trimmed to two advisories.
  REPORT = <<~REPORT
    Updating ruby-advisory-db ...
    ruby-advisory-db:
      advisories:\t1234 advisories

    Name: rack
    Version: 3.2.7
    GHSA: GHSA-5v64-555j-wjxm
    Criticality: High
    URL: https://github.com/rack/rack/security/advisories/GHSA-5v64-555j-wjxm
    Title: Multipart parser retains parsed data
    Solution: update to '>= 3.2.8'

    Name: loofah
    Version: 2.25.2
    CVE: CVE-2026-12345
    GHSA: GHSA-345x-3rq2-jfrm
    Criticality: Medium
    URL: https://example.org/loofah
    Title: Possible XSS
    Solution: update to '>= 2.25.3'

    Vulnerabilities found!
  REPORT

  CODEOWNERS = <<~OWNERS
    # A comment naming /Gemfile.lock @nobody
    /Gemfile                 @alice
    /Gemfile.lock            @old-owner
    /Gemfile.lock            @alice @ossf/badge-team someone@example.org
  OWNERS

  test 'parse reads each advisory and skips the preamble' do
    rack, loofah = BundleAuditNews.parse(REPORT)
    assert_equal 2, BundleAuditNews.parse(REPORT).size
    assert_equal ['GHSA-5v64-555j-wjxm'], rack[:ids]
    assert_equal 'High', rack[:criticality]
    assert_equal '3.2.7', rack[:version]
    assert_equal %w[CVE-2026-12345 GHSA-345x-3rq2-jfrm], loofah[:ids]
  end

  # Each row: what the issue body already said, and which packages are
  # still news.
  test 'fresh reports only advisories the issue did not list' do
    {
      'empty body' => ['', %w[rack loofah]],
      'GHSA known' => ['... GHSA-5v64-555j-wjxm ...', %w[loofah]],
      'CVE alone known' => ['CVE-2026-12345', %w[rack]],
      'all known' => [REPORT, []]
    }.each do |label, (previous, expected)|
      names = BundleAuditNews.fresh(REPORT, previous).pluck(:name)
      assert_equal expected, names, label
    end
  end

  test 'severe? is true only for High or Critical' do
    advisories = BundleAuditNews.parse(REPORT)
    assert BundleAuditNews.severe?(advisories)
    assert_not BundleAuditNews.severe?(advisories.drop(1))
    assert_not BundleAuditNews.severe?([])
  end

  test 'owners takes the last matching line and skips non-handles' do
    assert_equal %w[@alice @ossf/badge-team],
                 BundleAuditNews.owners(CODEOWNERS)
    assert_equal [], BundleAuditNews.owners("/Gemfile @alice\n")
  end

  test 'parse keeps an advisory repeated per platform only once' do
    twice = REPORT.sub('Vulnerabilities found!', REPORT.split("\n\n")[1])
    assert_equal 2, BundleAuditNews.parse(twice).size
  end

  test 'comment lists severe advisories and mentions owners' do
    advisories = BundleAuditNews.parse(REPORT)
    text = BundleAuditNews.comment(advisories, %w[@alice @bob])
    assert text.start_with?('@alice @bob bundle-audit found 2 new advisories.')
    assert_includes text, '- **High** rack 3.2.7: Multipart parser retains'
    assert text.end_with?('Below High: 1 new advisory, in loofah.')
  end

  test 'comment on milder advisories mentions nobody' do
    one = BundleAuditNews.parse(REPORT).drop(1)
    assert_equal 'bundle-audit found 1 new advisory. The issue body has ' \
                 "the full report.\n\nBelow High: 1 new advisory, in loofah.",
                 BundleAuditNews.comment(one, %w[@alice])
    assert_nil BundleAuditNews.comment([], %w[@alice])
  end
end
