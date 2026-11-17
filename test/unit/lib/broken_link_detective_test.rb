# frozen_string_literal: true

# Copyright 2015-2026, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# rubocop:disable-next Metrics/ClassLength
class BrokenLinkDetectiveTest < ActiveSupport::TestCase
  setup do
    stub_link_check_dns
    @evidence = Evidence.new({})
  end

  test 'starts a dated grace period for criteria with broken links' do
    good_url = 'https://www.example.org/good'
    bad_url = 'https://www.example.org/broken'
    stub_request(:get, good_url).to_return(status: 200)
    stub_request(:get, bad_url).to_return(status: 404)

    current = {
      homepage_url: good_url,
      repo_url: good_url,
      contribution_status: CriterionStatus::MET,
      contribution_justification: "See #{bad_url} for details.",
      interact_status: CriterionStatus::MET,
      interact_justification: "Details at #{good_url}.",
      floss_license_osi_status: CriterionStatus::MET,
      floss_license_osi_justification: "License at #{bad_url}"
    }

    results = BrokenLinkDetective.new(
      current_date: Date.iso8601('2026-10-10')
    ).analyze(@evidence, current)

    assert_nil results[:contribution_status]
    assert_equal(
      "See #{bad_url} for details. (// Broken link <#{bad_url}> detected on 2026-10-10)",
      results[:contribution_justification][:value]
    )
    assert_nil results[:interact_status]
    assert_nil results[:floss_license_osi_status]
    assert_includes results[:floss_license_osi_justification][:value], bad_url
  end

  test 'starts grace periods for broken homepage and base URLs' do
    bad_home = 'https://www.example.org/bad-home'
    bad_repo = 'https://www.example.org/bad-repo'
    stub_request(:get, bad_home).to_return(status: 404)
    stub_request(:get, bad_repo).to_return(status: 404)

    current = {
      homepage_url: bad_home,
      repo_url: bad_repo,
      sites_https_status: CriterionStatus::MET,
      repo_public_status: CriterionStatus::MET
    }

    results = BrokenLinkDetective.new.analyze(@evidence, current)

    assert_nil results[:homepage_url_status]
    assert_nil results[:sites_https_status]
    assert_nil results[:repo_public_status]
    assert_includes results[:homepage_url_justification][:value], bad_home
    assert_includes results[:repo_public_justification][:value], bad_repo
    assert LinkChecker.grace_detected_date(
      results[:homepage_url_justification][:value]
    )
    assert LinkChecker.grace_detected_date(
      results[:repo_public_justification][:value]
    )
  end

  test 'cleans broken link marker once URL is fixed' do
    fixed_url = 'https://www.example.org/fixed'
    stub_request(:get, fixed_url).to_return(status: 200)

    current = {
      contribution_status: CriterionStatus::MET,
      contribution_justification:
        "// Broken link: <https://www.example.org/old>. See #{fixed_url}"
    }

    results = BrokenLinkDetective.new.analyze(@evidence, current)

    assert_nil results[:contribution_status]
    assert_equal "See #{fixed_url}", results[:contribution_justification][:value]
  end

  test 'keeps criterion marked broken when flagged URL is still broken' do
    still_bad_url = 'https://www.example.org/still-bad'
    stub_request(:get, still_bad_url).to_return(status: 404)

    current = {
      contribution_status: CriterionStatus::UNMET,
      contribution_justification:
        "// Broken link: <#{still_bad_url}>. See #{still_bad_url}"
    }

    results = BrokenLinkDetective.new.analyze(@evidence, current)

    assert_equal CriterionStatus::UNMET, results[:contribution_status][:value]
    assert_equal(
      "// Broken link: <#{still_bad_url}>. See #{still_bad_url}",
      results[:contribution_justification][:value]
    )
  end

  test 'preserves existing markers when a URL check is skipped' do
    broken_url = 'https://www.example.org/still-broken'
    flagged_justification =
      "// Broken link: <#{broken_url}>. See #{broken_url}"
    current = {
      homepage_url: broken_url,
      homepage_url_justification: LinkChecker.format_broken_prefix('', broken_url),
      contribution_status: CriterionStatus::UNMET,
      contribution_justification: flagged_justification
    }

    results = BrokenLinkDetective.new(
      LinkChecker.new(max_total_duration: -1)
    ).analyze(@evidence, current)

    assert_nil results[:homepage_url_status]
    assert_nil results[:homepage_url_justification]
    assert_nil results[:contribution_status]
    assert_nil results[:contribution_justification]
  end

  test 'honors active grace period and keeps base URL state combined with justification URLs' do
    bad_home = 'https://www.example.org/bad-home'
    good_doc = 'https://www.example.org/good-doc'
    stub_request(:get, bad_home).to_return(status: 404)
    stub_request(:get, good_doc).to_return(status: 200)

    grace_home = LinkChecker.format_grace_warning('', bad_home, '2026-10-10')
    grace_sites = LinkChecker.format_grace_warning(
      "Docs at #{good_doc}", bad_home, '2026-10-10'
    )
    current = {
      homepage_url: bad_home,
      homepage_url_justification: grace_home,
      sites_https_status: CriterionStatus::MET,
      sites_https_justification: grace_sites
    }

    # During the 14-day grace period, neither homepage_url nor sites_https is forced Unmet
    active_detective = BrokenLinkDetective.new(
      nil, grace_days: 14, current_date: Date.iso8601('2026-10-15')
    )
    active_results = active_detective.analyze(@evidence, current)
    assert_nil active_results[:homepage_url_status]
    assert_nil active_results[:sites_https_status]

    # Once the grace period expires, both are marked Unmet even though good_doc is reachable
    expired_detective = BrokenLinkDetective.new(
      nil, grace_days: 14, current_date: Date.iso8601('2026-10-25')
    )
    expired_results = expired_detective.analyze(@evidence, current)
    assert_equal 'Unmet', expired_results[:homepage_url_status][:value]
    assert_equal CriterionStatus::UNMET, expired_results[:sites_https_status][:value]

    # When grace_days <= 0, grace period is inactive immediately
    zero_grace_detective = BrokenLinkDetective.new(
      nil, grace_days: 0, current_date: Date.iso8601('2026-10-10')
    )
    zero_results = zero_grace_detective.analyze(@evidence, current)
    assert_equal 'Unmet', zero_results[:homepage_url_status][:value]

    # When homepage_url is fixed, homepage_url_justification marker is cleaned
    stub_request(:get, bad_home).to_return(status: 200)
    recovered_results = active_detective.analyze(@evidence, current)
    assert_equal '', recovered_results[:homepage_url_justification][:value]
    assert_equal "Docs at #{good_doc}", recovered_results[:sites_https_justification][:value]
  end

  test 'starts a new grace period when a different URL breaks' do
    old_url = 'https://www.example.org/previously-broken'
    new_url = 'https://www.example.org/newly-broken'
    stub_request(:get, new_url).to_return(status: 404)
    current = {
      homepage_url: new_url,
      homepage_url_justification:
        LinkChecker.format_grace_warning('', old_url, '2026-10-10'),
      contribution_status: CriterionStatus::MET,
      contribution_justification: LinkChecker.format_grace_warning(
        "See #{new_url}", old_url, '2026-10-10'
      )
    }

    results = BrokenLinkDetective.new(
      nil, grace_days: 14, current_date: Date.iso8601('2026-10-15')
    ).analyze(@evidence, current)

    assert_nil results[:homepage_url_status]
    assert_equal(
      LinkChecker.format_grace_warning('', new_url, '2026-10-15'),
      results[:homepage_url_justification][:value]
    )
    assert_nil results[:contribution_status]
    assert_equal(
      LinkChecker.format_grace_warning(
        "See #{new_url}", new_url, '2026-10-15'
      ),
      results[:contribution_justification][:value]
    )
  end

  test 'starts a grace period when a URL replacing an expired one breaks' do
    old_url = 'https://www.example.org/expired'
    new_url = 'https://www.example.org/replacement'
    stub_request(:get, new_url).to_return(status: 404)
    current = {
      contribution_status: CriterionStatus::MET,
      contribution_justification: "// Broken link: <#{old_url}>. See #{new_url}"
    }

    results = BrokenLinkDetective.new(
      nil, grace_days: 14, current_date: Date.iso8601('2026-10-15')
    ).analyze(@evidence, current)

    assert_nil results[:contribution_status]
    assert_equal(
      LinkChecker.format_grace_warning("See #{new_url}", new_url, '2026-10-15'),
      results[:contribution_justification][:value]
    )
  end

  test 'restarts the grace period when the marker is dated in the future' do
    bad_url = 'https://www.example.org/broken'
    stub_request(:get, bad_url).to_return(status: 404)
    current = {
      contribution_status: CriterionStatus::MET,
      contribution_justification: LinkChecker.format_grace_warning(
        "See #{bad_url}", bad_url, '2099-01-01'
      )
    }

    results = BrokenLinkDetective.new(
      nil, grace_days: 14, current_date: Date.iso8601('2026-10-15')
    ).analyze(@evidence, current)

    assert_nil results[:contribution_status]
    assert_equal(
      LinkChecker.format_grace_warning("See #{bad_url}", bad_url, '2026-10-15'),
      results[:contribution_justification][:value]
    )
  end
end
