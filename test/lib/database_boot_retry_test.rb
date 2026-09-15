# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'
require 'minitest/mock'

# NO require_relative HERE, DELIBERATELY. lib/ is an autoload path (see
# config/application.rb), so naming the constant loads the file inside
# the worker process running these tests, not the parent, which is what
# keeps the load-time lines (constants, def headers) counted as tested.
class DatabaseBootRetryTest < ActiveSupport::TestCase
  test 'ping really queries the actual database connection' do
    # Every other test here stubs ping itself, to test connect_with_retry's
    # retry logic in isolation. This is the one test that lets ping's real
    # body run, against the test database that's actually available in
    # this environment, so that line is not just theoretically correct.
    assert DatabaseBootRetry.ping
  end

  test 'succeeds immediately when the first ping works' do
    calls = 0
    DatabaseBootRetry.stub(:ping, -> { calls += 1 }) do
      DatabaseBootRetry.stub(:sleep, ->(_) { flunk 'should not sleep' }) do
        assert DatabaseBootRetry.connect_with_retry
      end
    end
    assert_equal 1, calls
  end

  test 'retries past a transient PG::ConnectionBad and then succeeds' do
    calls = 0
    slept = []
    flaky_ping =
      lambda do
        calls += 1
        raise PG::ConnectionBad, 'no host' if calls < 3

        true
      end
    DatabaseBootRetry.stub(:ping, flaky_ping) do
      DatabaseBootRetry.stub(:sleep, ->(seconds) { slept << seconds }) do
        DatabaseBootRetry.stub(:warn, ->(_) {}) do
          assert DatabaseBootRetry.connect_with_retry(max_attempts: 3, delay: 2)
        end
      end
    end
    assert_equal 3, calls
    assert_equal [2, 2], slept
  end

  test 'retries past ActiveRecord::ConnectionNotEstablished too' do
    calls = 0
    flaky_ping =
      lambda do
        calls += 1
        raise ActiveRecord::ConnectionNotEstablished, 'gone' if calls < 2

        true
      end
    DatabaseBootRetry.stub(:ping, flaky_ping) do
      DatabaseBootRetry.stub(:sleep, ->(_) {}) do
        DatabaseBootRetry.stub(:warn, ->(_) {}) do
          assert DatabaseBootRetry.connect_with_retry(max_attempts: 3, delay: 0)
        end
      end
    end
    assert_equal 2, calls
  end

  test 'raises the last error once max_attempts is exhausted' do
    calls = 0
    always_fails =
      lambda do
        calls += 1
        raise PG::ConnectionBad, 'still no host'
      end
    DatabaseBootRetry.stub(:ping, always_fails) do
      DatabaseBootRetry.stub(:sleep, ->(_) {}) do
        DatabaseBootRetry.stub(:warn, ->(_) {}) do
          assert_raises(PG::ConnectionBad) do
            DatabaseBootRetry.connect_with_retry(max_attempts: 3, delay: 0)
          end
        end
      end
    end
    assert_equal 3, calls
  end

  test 'does not rescue an unrelated error' do
    DatabaseBootRetry.stub(:ping, -> { raise ArgumentError, 'unrelated' }) do
      DatabaseBootRetry.stub(:sleep, ->(_) { flunk 'should not sleep' }) do
        assert_raises(ArgumentError) do
          DatabaseBootRetry.connect_with_retry(max_attempts: 3, delay: 0)
        end
      end
    end
  end
end
