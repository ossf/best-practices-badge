# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'
require 'minitest/mock'

# rubocop:disable Metrics/ClassLength
class EvidenceTest < ActiveSupport::TestCase
  setup do
    @project = projects(:perfect)
    @evidence = Evidence.new(@project)
  end

  test 'initialize sets project' do
    assert_equal @project, @evidence.project
  end

  test 'initialize sets default resolver' do
    assert_equal CachedDnsResolver, @evidence.instance_variable_get(:@resolver)
  end

  test 'get_secure uses CachedDnsResolver' do
    url = 'https://raw.githubusercontent.com/ossf/' \
          'best-practices-badge/main/README.md'

    # Verify integration: ensure it can still fetch data with the new default
    VCR.use_cassette('evidence_get_success') do
      result = @evidence.get(url)
      assert_not_nil result
    end
  end

  test 'get caches successful URL fetch' do
    url = 'https://raw.githubusercontent.com/ossf/' \
          'best-practices-badge/main/README.md'

    VCR.use_cassette('evidence_get_success') do
      result = @evidence.get(url)

      # Verify the result contains meta and body
      assert_not_nil result
      assert result.key?(:meta)
      assert result.key?(:body)

      # Verify it's cached (second call returns same object)
      result2 = @evidence.get(url)
      assert_same result, result2
    end
  end

  test 'get handles URL fetch errors gracefully' do
    url = 'https://example.invalid/nonexistent'

    result = @evidence.get(url)

    # Should return nil on error
    assert_nil result

    # Second call should also return nil (cached)
    result2 = @evidence.get(url)
    assert_nil result2
  end

  test 'get ignores dubious URLs' do
    url = 'http://127.0.0.1'

    # Should return nil for dubious URL
    result = @evidence.get(url)
    assert_nil result

    # Should be cached as nil
    result2 = @evidence.get(url)
    assert_nil result2
  end

  test 'get respects MAXREAD limit' do
    url = 'https://raw.githubusercontent.com/ossf/' \
          'best-practices-badge/main/README.md'

    VCR.use_cassette('evidence_get_success') do
      result = @evidence.get(url)

      # Verify body doesn't exceed MAXREAD
      assert result[:body].bytesize <= Evidence::MAXREAD
    end
  end

  test 'get blocks SSRF resolving to private IP (offline-safe)' do
    # nip.io is a service that resolves to the IP address in the subdomain.
    # In this test we intercept the DNS request with a mock
    # (so we don't actually do the lookup), but an attacker
    # really *could* use a domain name like this to redirect to localhost.
    url = 'http://127.0.0.1.nip.io'

    # Mock resolver resolves our target to a private IP
    mock_resolver =
      lambda do |hostname|
        hostname == '127.0.0.1.nip.io' ? [IPAddr.new('127.0.0.1')] : []
      end

    evidence_with_mock = Evidence.new(@project, resolver: mock_resolver)

    result = evidence_with_mock.get(url)
    assert_nil result
  end

  test 'get allows private IP if allow_private_ips is true' do
    # We'll use a URL that is NOT dubious but resolves to a private IP.
    url = 'http://private-target.local'

    evidence_insecure = Evidence.new(@project, allow_private_ips: true)

    # Mock the request using WebMock
    stub_request(:get, url).to_return(
      status: 200,
      body: 'Insecure content',
      headers: { 'Content-Type' => 'text/plain' }
    )

    result = evidence_insecure.get(url)
    assert_not_nil result
    assert_equal 'Insecure content', result[:body]
    # In open-uri, meta returns a hash-like object.
    # Our get_insecure uses file.meta directly.
    assert_not_nil result[:meta]
  end

  test 'get_insecure handles errors gracefully' do
    url = 'http://nonexistent.local'
    evidence_insecure = Evidence.new(@project, allow_private_ips: true)

    # URI.open will raise an error for nonexistent hosts
    result = evidence_insecure.get(url)
    assert_nil result
  end

  test 'get_insecure respects MAX_HEADER_SIZE' do
    url = 'http://big-headers.local'
    huge_headers = {}
    1000.times { |i| huge_headers["X-Header-#{i}"] = 'a' * 100 }

    evidence_insecure = Evidence.new(@project, allow_private_ips: true)

    stub_request(:get, url).to_return(
      status: 200,
      body: 'ok',
      headers: huge_headers
    )

    result = evidence_insecure.get(url)
    assert_not_nil result
    total_size = result[:meta].sum { |k, v| k.bytesize + v.bytesize }
    assert total_size <= Evidence::MAX_HEADER_SIZE
    assert_not_empty result[:meta]
  end

  test 'get respects MAX_TOTAL_TIME' do
    url = 'http://slow-server.com'
    # Mock the request to sleep. We use a short timeout for the test.
    # We use a real IP to avoid DNS issues in ssrf_filter
    mock_resolver = ->(_h) { [IPAddr.new('1.1.1.1')] }
    @evidence = Evidence.new(@project, resolver: mock_resolver)

    Timeout.stub :timeout, ->(_sec) { raise Timeout::Error } do
      result = @evidence.get(url)
      assert_nil result
    end
  end

  test 'get respects MAX_HEADER_SIZE' do
    url = 'http://big-headers.com'
    # Create enough headers to exceed 64KB
    huge_headers = {}
    1000.times { |i| huge_headers["X-Header-#{i}"] = 'a' * 100 }

    # Mock resolver to avoid DNS lookups
    mock_resolver = ->(_h) { [IPAddr.new('1.1.1.1')] }
    @evidence = Evidence.new(@project, resolver: mock_resolver)

    stub_request(:get, url).to_return(
      status: 200,
      body: 'ok',
      headers: huge_headers
    )

    result = @evidence.get(url)
    assert_not_nil result
    total_size = result[:meta].sum { |k, v| k.bytesize + v.bytesize }
    assert total_size <= Evidence::MAX_HEADER_SIZE
    # Verify we still got some headers
    assert_not_empty result[:meta]
  end

  test 'get sets User-Agent header' do
    url = 'http://check-ua.com'
    # Mock resolver to avoid DNS lookups
    mock_resolver = ->(_h) { [IPAddr.new('1.1.1.1')] }
    @evidence = Evidence.new(@project, resolver: mock_resolver)

    stub_request(:get, url).with(
      headers: { 'User-Agent' => USER_AGENT }
    ).to_return(status: 200, body: 'ok')

    result = @evidence.get(url)
    assert_not_nil result
  end

  test 'get returns frozen data' do
    url = 'http://frozen.example.com'
    mock_resolver = ->(_h) { [IPAddr.new('1.1.1.1')] }
    @evidence = Evidence.new(@project, resolver: mock_resolver)

    stub_request(:get, url).to_return(
      status: 200,
      body: 'ok',
      headers: { 'Content-Type' => 'text/plain' }
    )

    result = @evidence.get(url)
    assert_not_nil result
    assert result.frozen?
    assert result[:meta].frozen?
    assert result[:meta]['content-type'].frozen?
    assert result[:body].frozen?
  end

  test 'get_insecure returns frozen data' do
    url = 'http://insecure.example.com/frozen'
    evidence_insecure = Evidence.new(@project, allow_private_ips: true)

    stub_request(:get, url).to_return(
      status: 200,
      body: 'ok',
      headers: { 'Content-Type' => 'text/plain' }
    )

    result = evidence_insecure.get(url)
    assert_not_nil result
    assert result.frozen?
    assert result[:meta].frozen?
    assert result[:meta]['Content-Type'].frozen?
    assert result[:body].frozen?
  end
end
# rubocop:enable Metrics/ClassLength
