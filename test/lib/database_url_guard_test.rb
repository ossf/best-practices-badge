# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# NO require_relative HERE, DELIBERATELY. lib/ is an autoload path (see
# config/application.rb), so naming the constant loads the file inside
# the worker process running these tests, not the parent, which is what
# keeps the load-time lines (constants, def headers) counted as tested.
class DatabaseUrlGuardTest < ActiveSupport::TestCase
  test 'does nothing on a real boot that has DATABASE_URL' do
    assert_nil(
      DatabaseUrlGuard.check!(database_url: 'postgresql://host/db')
    )
  end

  test 'raises on a real boot with no DATABASE_URL at all' do
    error =
      assert_raises(DatabaseUrlGuard::MissingDatabaseUrl) do
        DatabaseUrlGuard.check!(database_url: nil)
      end
    assert_match(/DATABASE_URL is not set/, error.message)
  end
end
