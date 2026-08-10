# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'
require 'minitest/mock'
require_relative '../../lib/asset_staleness_middleware'

# Test the middleware itself. This is a little tricky, because we
# have to accept the middleware interface as it is. We end up doing
# some mocking to fully test it.
# rubocop:disable Lint/UnusedMethodArgument, Naming/PredicateMethod
# rubocop:disable Style/TrivialAccessors
class AssetStalenessMiddlewareTest < ActiveSupport::TestCase
  def setup
    super
    @app = ->(_env) { [200, {}, ['OK']] }
    @env = {}
  end

  test 'calls app and checks assets on first request' do
    # Mock checker to avoid actual staleness check
    checker = Object.new
    def checker.check_and_warn(env:)
      false
    end

    middleware = AssetStalenessMiddleware.new(@app)
    AssetStalenessChecker.stub :from_rails_config, checker do
      status, _headers, _body = middleware.call(@env)
      assert_equal 200, status
    end
  end

  test 'only checks assets once' do
    checker = Object.new
    def checker.check_and_warn(env:)
      @call_count ||= 0
      @call_count += 1
      false
    end

    def checker.call_count
      @call_count || 0
    end

    middleware = AssetStalenessMiddleware.new(@app)
    AssetStalenessChecker.stub :from_rails_config, checker do
      # First call checks
      middleware.call(@env)
      # Second call should not check again
      middleware.call(@env)
      assert_equal 1, checker.call_count, 'check_and_warn should only be called once'
    end
  end

  test 're-raises errors in development environment' do
    # Test line 34: raise if Rails.env.local?
    checker = Object.new
    def checker.check_and_warn(env:)
      raise StandardError, 'Test error'
    end

    middleware = AssetStalenessMiddleware.new(@app)
    AssetStalenessChecker.stub :from_rails_config, checker do
      Rails.stub :env, ActiveSupport::EnvironmentInquirer.new('development') do
        assert_raises(StandardError, 'Test error') { middleware.call(@env) }
      end
    end
  end

  test 're-raises errors in test environment' do
    # Test line 34: raise if Rails.env.local? (includes test environment)
    # This matches the AssetStalenessChecker's design to fail fast in test
    checker = Object.new
    def checker.check_and_warn(env:)
      raise StandardError, 'Test error in test env'
    end

    middleware = AssetStalenessMiddleware.new(@app)
    AssetStalenessChecker.stub :from_rails_config, checker do
      Rails.stub :env, ActiveSupport::EnvironmentInquirer.new('test') do
        assert_raises(StandardError, 'Test error in test env') { middleware.call(@env) }
      end
    end
  end

  test 'logs errors in production environment' do
    # Test line 36: Rails.logger.error(...) in production
    checker = Object.new
    def checker.check_and_warn(env:)
      raise StandardError, 'Test error in production'
    end

    logger = Object.new
    def logger.error(msg)
      @logged = msg
    end

    def logger.logged
      @logged
    end

    middleware = AssetStalenessMiddleware.new(@app)
    AssetStalenessChecker.stub :from_rails_config, checker do
      Rails.stub :env, ActiveSupport::EnvironmentInquirer.new('production') do
        Rails.stub :logger, logger do
          # Should not raise, just log
          status, _headers, _body = middleware.call(@env)
          assert_equal 200, status
          assert_match(/Asset staleness check failed/, logger.logged)
        end
      end
    end
  end
end
# rubocop:enable Lint/UnusedMethodArgument, Naming/PredicateMethod
# rubocop:enable Style/TrivialAccessors
