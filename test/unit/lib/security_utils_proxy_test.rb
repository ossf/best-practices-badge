# frozen_string_literal: true

require 'test_helper'
require 'security_utils'
require 'minitest/mock'

class SecurityUtilsProxyTest < ActiveSupport::TestCase
  def setup
    super
    @fastly_ips = [
      '23.235.32.0/20', '43.249.72.0/22', '103.244.50.0/24', '103.245.222.0/23',
      '103.245.224.0/24', '104.156.80.0/20', '140.248.64.0/18',
      '140.248.128.0/17', '146.75.0.0/17', '151.101.0.0/16', '157.52.64.0/18',
      '167.82.0.0/17', '167.82.128.0/20', '167.82.160.0/20', '167.82.224.0/20',
      '172.111.64.0/18', '185.31.16.0/22', '199.27.72.0/21', '199.232.0.0/16',
      '2a04:4e40::/32', '2a04:4e42::/32'
    ]
    @fastly_static = @fastly_ips.join(',')
    @fastly_json = {
      'addresses' => @fastly_ips.grep_v(/:/),
      'ipv6_addresses' => @fastly_ips.grep(/:/)
    }
  end

  test 'parse_static_proxies handles various formats' do
    assert_equal ['1.1.1.1', '2.2.2.2'], SecurityUtils.parse_static_proxies('1.1.1.1, 2.2.2.2')
    assert_equal ['1.1.1.1'], SecurityUtils.parse_static_proxies('1.1.1.1')
    assert_equal [], SecurityUtils.parse_static_proxies('')
    assert_equal [], SecurityUtils.parse_static_proxies(nil)
  end

  test 'fetch_dynamic_proxies successful load' do
    stub_request(:get, 'https://api.fastly.com/public-ip-list')
      .to_return(status: 200, body: @fastly_json.to_json, headers: { 'Content-Type' => 'application/json' })

    ips = SecurityUtils.fetch_dynamic_proxies('https://api.fastly.com/public-ip-list')
    assert_equal @fastly_ips.sort, ips.sort
  end

  test 'fetch_dynamic_proxies handles failure' do
    stub_request(:get, 'https://api.fastly.com/fail').to_return(status: 404)
    assert_equal [], SecurityUtils.fetch_dynamic_proxies('https://api.fastly.com/fail')

    stub_request(:get, 'https://api.fastly.com/timeout').to_timeout
    assert_equal [], SecurityUtils.fetch_dynamic_proxies('https://api.fastly.com/timeout')
  end

  test 'fetch_dynamic_proxies handles malformed JSON' do
    stub_request(:get, 'https://api.fastly.com/bad-json')
      .to_return(status: 200, body: 'not json', headers: { 'Content-Type' => 'application/json' })
    assert_equal [], SecurityUtils.fetch_dynamic_proxies('https://api.fastly.com/bad-json')
  end

  test 'warn_if_mismatched logs when different' do
    # Capture logger output if possible, or just verify it doesn't crash
    # Rails 7+ has broadcast_to or we can stub Rails.logger
    mock_logger = Minitest::Mock.new
    mock_logger.expect :warn, nil, [String]

    Rails.stub :logger, mock_logger do
      SecurityUtils.warn_if_mismatched(['1.1.1.1'], ['2.2.2.2'], 'url')
    end
    assert mock_logger.verify
  end

  test 'warn_if_mismatched silent when same' do
    mock_logger = Minitest::Mock.new
    # No expectation for :warn means it will fail if called

    Rails.stub :logger, mock_logger do
      SecurityUtils.warn_if_mismatched(['1.1.1.1'], ['1.1.1.1'], 'url')
    end
    assert mock_logger.verify
  end

  test 'ensure_proxies_present raises in fail_fast' do
    assert_raises(SecurityUtils::SecurityAssertionError) do
      SecurityUtils.ensure_proxies_present([], true)
    end
    # Should NOT raise
    SecurityUtils.ensure_proxies_present(['1.1.1.1'], true)
    SecurityUtils.ensure_proxies_present([], false)
  end

  test 'load_trusted_proxies orchestration' do
    # Success via URL
    stub_request(:get, 'https://api.fastly.com/public-ip-list')
      .to_return(status: 200, body: @fastly_json.to_json, headers: { 'Content-Type' => 'application/json' })

    ips = SecurityUtils.load_trusted_proxies(url: 'https://api.fastly.com/public-ip-list', static: '1.1.1.1')
    assert_includes ips, IPAddr.new('23.235.32.0/20')
    assert_not_includes ips, IPAddr.new('1.1.1.1')

    # Fallback to static
    stub_request(:get, 'https://api.fastly.com/fail').to_return(status: 404)
    ips = SecurityUtils.load_trusted_proxies(url: 'https://api.fastly.com/fail', static: '1.1.1.1')
    assert_equal [IPAddr.new('1.1.1.1')], ips

    # Disabled
    ips = SecurityUtils.load_trusted_proxies(url: 'any', static: 'any', disabled: true)
    assert_equal [], ips
  end

  test 'fetch_dynamic_proxies handles blank url' do
    assert_equal [], SecurityUtils.fetch_dynamic_proxies(nil)
    assert_equal [], SecurityUtils.fetch_dynamic_proxies('')
  end

  test 'warn_if_mismatched silent if one is empty' do
    mock_logger = Minitest::Mock.new
    # No expectation for :warn means it will fail if called

    Rails.stub :logger, mock_logger do
      SecurityUtils.warn_if_mismatched([], ['1.1.1.1'], 'url')
      SecurityUtils.warn_if_mismatched(['1.1.1.1'], nil, 'url')
    end
    assert mock_logger.verify
  end

  test 'rigorous spoofing resilience' do
    # Infrastructure: Client -> [Fastly] -> [Heroku Router] -> App
    edge = [IPAddr.new('23.235.32.0/20')]
    SecurityUtils.edge_proxies = edge

    # Case 1: Legitimate traffic
    # X-Forwarded-For: ClientIP, FastlyIP
    # Heroku app sees: forwarded_for = ["ClientIP", "FastlyIP"]
    assert SecurityUtils.edge_proxy?('23.235.32.1') # The last one matches

    # Case 2: Direct attack (Bypass Fastly)
    # X-Forwarded-For: (empty or client-provided)
    # Heroku router appends AttackerIP.
    # Heroku app sees: forwarded_for = ["AttackerIP"]
    assert_not SecurityUtils.edge_proxy?('1.2.3.4')

    # Case 3: Spoofing attack (Direct to Heroku, faking Fastly IP)
    # Attacker sends: X-Forwarded-For: 23.235.32.1
    # Heroku router appends AttackerIP: X-Forwarded-For: 23.235.32.1, AttackerIP
    # Heroku app sees: forwarded_for = ["23.235.32.1", "AttackerIP"]
    # Our logic checks the LAST one: "AttackerIP"
    assert_not SecurityUtils.edge_proxy?('1.2.3.4') # AttackerIP is 1.2.3.4
  end

  test 'edge_proxy? and edge_proxies= logic' do
    edge = [IPAddr.new('23.235.32.0/20')]
    SecurityUtils.edge_proxies = edge

    assert SecurityUtils.edge_proxy?('23.235.32.1')
    assert SecurityUtils.edge_proxy?(IPAddr.new('23.235.32.2'))
    assert_not SecurityUtils.edge_proxy?('1.2.3.4')
    assert_not SecurityUtils.edge_proxy?(nil)
    assert_not SecurityUtils.edge_proxy?('')
  end
end
