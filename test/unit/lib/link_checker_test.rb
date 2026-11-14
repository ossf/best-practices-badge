# frozen_string_literal: true

# Copyright 2015-2026, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# rubocop:disable-next Metrics/ClassLength
class LinkCheckerTest < ActiveSupport::TestCase
  setup { stub_link_check_dns }

  test 'extract_urls extracts valid URLs and strips trailing punctuation' do
    assert_equal(
      ['https://www.example.org/docs', 'https://example.org/contributing'],
      LinkChecker.extract_urls(
        'See <https://www.example.org/docs>. Also [guide](https://example.org/contributing)!'
      )
    )
    wiki_url = 'https://en.wikipedia.org/wiki/C_(programming_language)'
    assert_equal(
      [wiki_url],
      LinkChecker.extract_urls("Bare #{wiki_url}, markdown [C](#{wiki_url}), and (prose #{wiki_url}).")
    )
    ipv6_url = 'http://[2606:4700:4700::1111]/docs'
    assert_equal(
      [ipv6_url],
      LinkChecker.extract_urls(
        "Bare #{ipv6_url}], markdown [IPv6](#{ipv6_url}), and [#{ipv6_url}]"
      )
    )
    assert_equal [], LinkChecker.extract_urls(nil)
    assert_equal [], LinkChecker.extract_urls('')
    assert_equal [], LinkChecker.extract_urls('// https://www.example.org/comment')
  end

  test 'extract_urls_including_flagged and marker helpers' do
    flagged = LinkChecker.format_broken_prefix(
      'See https://www.example.org/doc.', 'https://www.example.org/doc'
    )
    assert_equal(
      '// Broken link: <https://www.example.org/doc>. See https://www.example.org/doc.',
      flagged
    )
    assert_equal(
      ['https://www.example.org/doc'],
      LinkChecker.extract_urls_including_flagged(flagged)
    )
    assert_equal(
      'See https://www.example.org/doc.',
      LinkChecker.strip_broken_link_markers(flagged)
    )

    grace_text = LinkChecker.format_grace_warning(
      'See https://www.example.org/doc.', 'https://www.example.org/doc', '2026-10-01'
    )
    assert_equal Date.iso8601('2026-10-01'), LinkChecker.grace_detected_date(grace_text)
    assert_nil LinkChecker.grace_detected_date(
      'See https://www.example.org/doc. (// Broken link <https://www.example.org/doc> detected on 2026-99-99)'
    )
    assert_equal(
      'See https://www.example.org/doc.',
      LinkChecker.strip_broken_link_markers(grace_text)
    )
    assert_equal(
      '// Broken link: <https://www.example.org/doc>.',
      LinkChecker.format_broken_prefix('', 'https://www.example.org/doc')
    )
  end

  test 'url_ok? returns true for 200 OK and caches result' do
    url = 'https://www.example.org/working'
    stub = stub_request(:get, url).to_return(status: 200, body: 'ok')

    checker = LinkChecker.new
    assert checker.url_ok?(url)
    assert checker.url_ok?(url)
    assert_requested stub, times: 1
  end

  test 'url_ok? does not read response bodies' do
    response = Net::HTTPOK.new('1.1', '200', 'OK')
    response.define_singleton_method(:read_body) { raise IOError, 'body read' }
    request = ->(_url, **_options, &block) { block.call(response) }

    SsrfFilter.stub(:get, request) do
      assert LinkChecker.new.url_ok?('https://www.example.org/large')
    end
  end

  test 'url_ok? follows redirects including relative Location headers' do
    start_url = 'https://www.example.org/old-doc'
    dest_url = 'https://www.example.org/new-doc'
    stub_request(:get, start_url)
      .to_return(status: 301, headers: { 'Location' => '/new-doc' })
    stub_request(:get, dest_url)
      .to_return(status: 200, body: 'moved content')

    checker = LinkChecker.new
    assert checker.url_ok?(start_url)
  end

  test 'url_ok? returns false for 404 Not Found without retrying' do
    url = 'https://www.example.org/missing'
    stub = stub_request(:get, url).to_return(status: 404, body: 'not found')

    checker = LinkChecker.new(retries: 2)
    assert_not checker.url_ok?(url)
    assert_requested stub, times: 1
  end

  test 'url_ok? retries on transient 500 error and succeeds if recovered' do
    url = 'https://www.example.org/flaky'
    stub = stub_request(:get, url)
           .to_return(status: 503)
           .then.to_return(status: 200, body: 'recovered')

    checker = LinkChecker.new(retries: 2)
    assert checker.url_ok?(url)
    assert_requested stub, times: 2
  end

  test 'url_ok? returns false when transient errors persist past retries' do
    url = 'https://www.example.org/down'
    stub = stub_request(:get, url).to_return(status: 502)

    checker = LinkChecker.new(retries: 1)
    assert_not checker.url_ok?(url)
    assert_requested stub, times: 2
  end

  test 'url_ok? rejects invalid URLs and private/local addresses' do
    checker = LinkChecker.new
    assert_not checker.url_ok?('')
    assert_not checker.url_ok?(nil)
    assert_not checker.url_ok?('ftp://example.org/file')
    assert_not checker.url_ok?('https://[::1]:badport/secret')
    assert_not checker.url_ok?('https://user:pass@example.org/secret')
    assert_not checker.url_ok?('http://localhost/admin')
    assert_not checker.url_ok?('http://127.0.0.1/admin')
    assert_not checker.url_ok?('http://169.254.169.254/latest/meta-data/')
    assert_not checker.url_ok?('http://192.168.1.1/status')
    assert_not checker.url_ok?('http://[::1]/status')
  end

  test 'DNS names resolving to private addresses are rejected without a request' do
    url = 'https://private.example.org/secret'
    checker = LinkChecker.new(resolver: ->(_host) { [IPAddr.new('127.0.0.1')] })
    assert_not checker.url_ok?(url)
    assert_not_requested :get, url
  end

  test 'redirects into private DNS addresses are rejected without fetching the target' do
    url = 'https://public.example.org/start'
    target = 'https://private.example.org/secret'
    resolver = ->(host) { [IPAddr.new(host.start_with?('private') ? '10.0.0.1' : '1.1.1.1')] }
    stub_request(:get, url).to_return(status: 302, headers: { 'Location' => target })
    checker = LinkChecker.new(resolver: resolver)
    assert_not checker.url_ok?(url)
    assert_requested :get, url
    assert_not_requested :get, target
  end

  test 'redirect loops and malformed redirect locations fail cleanly' do
    url = 'https://public.example.org/loop'
    stub = stub_request(:get, url).to_return(status: 302, headers: { 'Location' => url })
    checker = LinkChecker.new(redirect_limit: 2, resolver: ->(_host) { [IPAddr.new('1.1.1.1')] })
    assert_not checker.url_ok?(url)
    assert_requested stub, times: 2

    bad_redirect_url = 'https://public.example.org/bad-redirect'
    stub_request(:get, bad_redirect_url)
      .to_return(status: 302, headers: { 'Location' => 'http://[::1]:badport' })
    assert_not checker.url_ok?(bad_redirect_url)
  end

  test 'network errors and test-harness blocks are handled' do
    resolver = ->(_host) { [IPAddr.new('1.1.1.1')] }
    checker = LinkChecker.new(retries: 0, resolver: resolver)

    err_url = 'https://public.example.org/socket-error'
    stub_request(:get, err_url).to_raise(SocketError.new('connection reset'))
    assert_not checker.url_ok?(err_url)

    blocked_url = 'https://public.example.org/unstubbed'
    assert_equal :skipped, checker.url_status(blocked_url)
    assert_not checker.url_ok?(blocked_url)

    # Verify fatal exceptions still propagate outside the retry handler.
    # rubocop:disable-next Lint/InheritException
    fatal_exception = Class.new(Exception)
    fatal_url = 'https://public.example.org/fatal-error'
    stub_request(:get, fatal_url).to_raise(fatal_exception)
    assert_raises(fatal_exception) { checker.url_status(fatal_url) }
  end

  test 'WebMock blocks are skipped when VCR is disabled' do
    VCR.turned_off do
      checker = LinkChecker.new
      assert_equal :skipped, checker.url_status('https://public.example.org/blocked')
    end
  end

  test 'url_status distinguishes skipped checks from verified success' do
    checker = LinkChecker.new(max_total_duration: -1)
    skipped_url = 'https://www.example.org/skipped'

    assert_equal :skipped, checker.url_status(skipped_url)
    assert_not checker.url_ok?(skipped_url)
  end

  test 'max_total_duration bounds link checks and stops when deadline is exceeded' do
    url = 'https://www.example.org/bounded'
    stub = stub_request(:get, url).to_return(status: 200, body: 'ok')

    active_checker = LinkChecker.new(max_total_duration: 5)
    assert active_checker.url_ok?(url)
    assert_requested stub, times: 1

    expired_checker = LinkChecker.new(max_total_duration: -1)
    skipped_url = 'https://www.example.org/never-called'
    assert_equal :skipped, expired_checker.url_status(skipped_url)
    assert_not_requested :get, skipped_url
    assert_in_delta 0.001, expired_checker.send(:request_timeout_budget), 0.0001
  end
end
