# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'
require 'minitest/mock'
require 'zlib'
require 'stringio'

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
      result = @evidence.get_headers(url)
      assert_not_nil result
    end
  end

  test 'get_headers caches successful URL fetch' do
    url = 'https://raw.githubusercontent.com/ossf/' \
          'best-practices-badge/main/README.md'

    VCR.use_cassette('evidence_get_success') do
      result = @evidence.get_headers(url)

      # get_headers returns the headers hash directly.
      assert_not_nil result
      assert_kind_of Hash, result

      # Verify it's cached (second call returns same object)
      result2 = @evidence.get_headers(url)
      assert_same result, result2
    end
  end

  test 'get handles URL fetch errors gracefully' do
    url = 'https://example.invalid/nonexistent'

    result = @evidence.get_headers(url)

    # Should return nil on error
    assert_nil result

    # Second call should also return nil (cached)
    result2 = @evidence.get_headers(url)
    assert_nil result2
  end

  test 'get ignores dubious URLs' do
    url = 'http://127.0.0.1'

    # Should return nil for dubious URL
    result = @evidence.get_headers(url)
    assert_nil result

    # Should be cached as nil
    result2 = @evidence.get_headers(url)
    assert_nil result2
  end

  test 'get_body respects MAXREAD limit' do
    url = 'https://raw.githubusercontent.com/ossf/' \
          'best-practices-badge/main/README.md'

    VCR.use_cassette('evidence_get_success') do
      body = @evidence.get_body(url)

      # Verify body doesn't exceed MAXREAD
      assert body.bytesize <= Evidence::MAXREAD
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

    result = evidence_with_mock.get_headers(url)
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

    result = evidence_insecure.get_headers(url)
    assert_not_nil result
    # The body is fetched separately, only on demand.
    assert_equal 'Insecure content', evidence_insecure.get_body(url)
  end

  test 'get_insecure handles errors gracefully' do
    url = 'http://nonexistent.local'
    evidence_insecure = Evidence.new(@project, allow_private_ips: true)

    # URI.open will raise an error for nonexistent hosts
    result = evidence_insecure.get_headers(url)
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

    result = evidence_insecure.get_headers(url)
    assert_not_nil result
    total_size = result.sum { |k, v| k.bytesize + v.bytesize }
    assert total_size <= Evidence::MAX_HEADER_SIZE
    assert_not_empty result
  end

  test 'get respects MAX_TOTAL_TIME' do
    url = 'http://slow-server.com'
    # Mock the request to sleep. We use a short timeout for the test.
    # We use a real IP to avoid DNS issues in ssrf_filter
    mock_resolver = ->(_h) { [IPAddr.new('1.1.1.1')] }
    @evidence = Evidence.new(@project, resolver: mock_resolver)

    Timeout.stub :timeout, ->(_sec) { raise Timeout::Error } do
      result = @evidence.get_headers(url)
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

    result = @evidence.get_headers(url)
    assert_not_nil result
    total_size = result.sum { |k, v| k.bytesize + v.bytesize }
    assert total_size <= Evidence::MAX_HEADER_SIZE
    # Verify we still got some headers
    assert_not_empty result
  end

  test 'get sets User-Agent header' do
    url = 'http://check-ua.com'
    # Mock resolver to avoid DNS lookups
    mock_resolver = ->(_h) { [IPAddr.new('1.1.1.1')] }
    @evidence = Evidence.new(@project, resolver: mock_resolver)

    stub_request(:get, url).with(
      headers: { 'User-Agent' => USER_AGENT }
    ).to_return(status: 200, body: 'ok')

    result = @evidence.get_headers(url)
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

    result = @evidence.get_headers(url)
    assert_not_nil result
    assert result.frozen?
    assert result['content-type'].frozen?
    assert @evidence.get_body(url).frozen?
  end

  test 'get_insecure returns frozen data' do
    url = 'http://insecure.example.com/frozen'
    evidence_insecure = Evidence.new(@project, allow_private_ips: true)

    stub_request(:get, url).to_return(
      status: 200,
      body: 'ok',
      headers: { 'Content-Type' => 'text/plain' }
    )

    result = evidence_insecure.get_headers(url)
    assert_not_nil result
    assert result.frozen?
    assert result['Content-Type'].frozen?
    assert evidence_insecure.get_body(url).frozen?
  end

  # The whole point of get_headers/get_body: a default get_headers must not pull
  # the body into memory. We assert both that no raw body was stashed and that
  # the decoded-body cache stays empty until get_body is called.
  test 'get_headers defers body extraction until get_body' do
    url = 'http://split.example.com/'
    mock_resolver = ->(_h) { [IPAddr.new('1.1.1.1')] }
    evidence = Evidence.new(@project, resolver: mock_resolver)
    stub_request(:get, url).to_return(
      status: 200, body: 'the body',
      headers: { 'Content-Type' => 'text/plain' }
    )

    headers = evidence.get_headers(url)
    assert_not_nil headers
    # No raw body stashed by a default get_headers, and nothing decoded yet.
    assert_nil evidence.instance_variable_get(:@cached_data)[url][:body_raw]
    assert_empty evidence.instance_variable_get(:@decoded_bodies)

    assert_equal 'the body', evidence.get_body(url)
  end

  # store_body: true stashes the body in the same request, so a following
  # get_body needs no second fetch (the point of the flag).
  test 'get_headers store_body true lets get_body reuse one request' do
    url = 'http://combined.example.com/'
    mock_resolver = ->(_h) { [IPAddr.new('1.1.1.1')] }
    evidence = Evidence.new(@project, resolver: mock_resolver)
    stub_request(:get, url).to_return(status: 200, body: 'shared body')

    evidence.get_headers(url, store_body: true)
    assert_equal 'shared body', evidence.get_body(url)
    # Exactly one network request served both headers and body.
    assert_equal 1, evidence.instance_variable_get(:@fetch_count)
  end

  # A failed body upgrade must not wipe headers we already fetched successfully.
  test 'a failed body fetch preserves previously good headers' do
    url = 'http://flaky.example.com/'
    mock_resolver = ->(_h) { [IPAddr.new('1.1.1.1')] }
    evidence = Evidence.new(@project, resolver: mock_resolver)
    stub_request(:get, url)
      .to_return(
        status: 200, body: 'ok', headers: { 'Content-Type' => 'text/plain' }
      ).then.to_raise(SocketError)

    assert_not_nil evidence.get_headers(url) # first request caches headers
    assert_nil evidence.get_body(url)        # body upgrade (2nd request) fails
    # The good headers survived the failed body upgrade.
    assert_not_nil evidence.get_headers(url)
  end

  # We accept gzip (see REQUEST_HEADERS) but never auto-inflate; get_body
  # inflates the stashed gzip body through SafeInflate on demand.
  test 'get_body inflates a gzip-encoded body' do
    url = 'http://gz.example.com/'
    mock_resolver = ->(_h) { [IPAddr.new('1.1.1.1')] }
    evidence = Evidence.new(@project, resolver: mock_resolver)
    payload = 'documentation ' * 100
    stub_request(:get, url).to_return(
      status: 200, body: Zlib.gzip(payload),
      headers: { 'Content-Encoding' => 'gzip' }
    )

    # payload is ASCII-only, so it compares equal to the binary result.
    assert_equal payload, evidence.get_body(url)
  end

  # Security: a gzip *bomb* body must be refused (get_body returns nil) rather
  # than inflated in full. SafeInflate caps output at MAXREAD, raising, which
  # the fetch treats as a failed fetch.
  test 'get_body refuses a gzip bomb, returning nil' do
    url = 'http://bomb.example.com/'
    mock_resolver = ->(_h) { [IPAddr.new('1.1.1.1')] }
    evidence = Evidence.new(@project, resolver: mock_resolver)
    bomb = Zlib.gzip('A' * (200 * 1024 * 1024))
    assert bomb.bytesize < Evidence::MAXREAD, 'bomb is small compressed'
    stub_request(:get, url).to_return(
      status: 200, body: bomb,
      headers: { 'Content-Encoding' => 'gzip' }
    )

    assert_nil evidence.get_body(url)
  end

  # Security: one project analysis must never become an unbounded
  # outbound-request amplifier. At the MAX_FETCHES ceiling, a further distinct
  # URL is refused without touching the network. We fast-forward @fetch_count
  # to the boundary so the test asserts the invariant regardless of the
  # (deliberately large) budget value.
  test 'get enforces the MAX_FETCHES budget per instance' do
    mock_resolver = ->(_h) { [IPAddr.new('1.1.1.1')] }
    evidence = Evidence.new(@project, resolver: mock_resolver)
    stub_request(:get, 'http://last.example.com/')
      .to_return(status: 200, body: 'ok')
    stub_request(:get, 'http://over.example.com/')
      .to_return(status: 200, body: 'ok')

    # Fast-forward to one fetch below the budget.
    evidence.instance_variable_set(:@fetch_count, Evidence::MAX_FETCHES - 1)

    # The fetch that reaches the budget still succeeds.
    assert_not_nil evidence.get_headers('http://last.example.com/')
    # The next distinct URL exceeds the budget: refused (nil) and cached,
    # without ever hitting the network.
    assert_nil evidence.get_headers('http://over.example.com/')
    assert_nil evidence.get_headers('http://over.example.com/') # cached, still nil
    assert_not_requested :get, 'http://over.example.com/'
  end

  # Security: fetching the same URL repeatedly stays within budget (it is
  # cached), so a legitimate re-check is never starved by the cap.
  test 'repeated fetch of one URL does not consume extra budget' do
    mock_resolver = ->(_h) { [IPAddr.new('1.1.1.1')] }
    evidence = Evidence.new(@project, resolver: mock_resolver)
    stub_request(:get, 'http://repeat.example.com/')
      .to_return(status: 200, body: 'ok')

    (Evidence::MAX_FETCHES * 2).times do
      assert_not_nil evidence.get_headers('http://repeat.example.com/')
    end
    assert_equal 1, evidence.instance_variable_get(:@fetch_count)
  end

  # Security: the unfiltered (open-uri) path must be impossible on the real
  # production site, even if ALLOW_PRIVATE_IPS is set by misconfiguration.
  test 'insecure path is force-disabled on the real production site' do
    original = ENV.fetch('BADGEAPP_REAL_PRODUCTION', nil)
    ENV['BADGEAPP_REAL_PRODUCTION'] = 'true'
    evidence = Evidence.new(@project, allow_private_ips: true)
    assert_equal false, evidence.instance_variable_get(:@allow_private_ips)
  ensure
    ENV['BADGEAPP_REAL_PRODUCTION'] = original
  end

  # Security: the secure fetch pins scheme and redirect limits explicitly,
  # so our outbound policy cannot silently drift to a library default.
  test 'get_secure passes explicit scheme and redirect limits' do
    captured = nil
    fake_get =
      lambda do |_url, options, &_block|
        captured = options
        nil
      end

    SsrfFilter.stub :get, fake_get do
      @evidence.get_headers('http://opts.example.com/')
    end

    assert_equal Evidence::MAX_REDIRECTS, captured[:max_redirects]
    assert_equal Evidence::ALLOWED_SCHEMES, captured[:scheme_whitelist]
  end

  # Security (anti "zip bomb"): we advertise gzip (and only gzip) but set the
  # header ourselves, which keeps Net::HTTP's decode_content off so nothing is
  # auto-inflated. get_body later inflates on demand via SafeInflate (capped).
  test 'get_secure advertises gzip content-encoding' do
    captured = nil
    fake_get =
      lambda do |_url, options, &_block|
        captured = options
        nil
      end

    SsrfFilter.stub :get, fake_get do
      @evidence.get_headers('http://enc.example.com/')
    end

    assert_equal 'gzip', captured[:headers]['Accept-Encoding']
  end

  # A gzip body that would inflate beyond MAXREAD is refused by get_body: the
  # cap is enforced during inflation (via SafeInflate), so an over-cap payload
  # can never expand past MAXREAD in memory. This uses a streaming GzipWriter
  # (distinct from Zlib.gzip) at a size just over the cap, complementing the
  # extreme 200 MB bomb case above.
  test 'get_body never inflates a gzip body past MAXREAD' do
    raw = 'A' * (5 * 1024 * 1024) # would be 5 MB inflated, over MAXREAD
    gz = StringIO.new
    Zlib::GzipWriter.wrap(gz) { |w| w.write(raw) }
    over_cap = gz.string

    url = 'http://gzip.example.com/'
    mock_resolver = ->(_h) { [IPAddr.new('1.1.1.1')] }
    evidence = Evidence.new(@project, resolver: mock_resolver)
    stub_request(:get, url).to_return(
      status: 200, body: over_cap,
      headers: { 'Content-Encoding' => 'gzip' }
    )

    assert_nil evidence.get_body(url)
  end
end
# rubocop:enable Metrics/ClassLength
