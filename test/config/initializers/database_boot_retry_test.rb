# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# Regression test for the 2026-09-15 staging deploy failure: this
# initializer referenced DatabaseBootRetry (an autoloaded lib/
# constant) with no preceding require, so it raised "uninitialized
# constant DatabaseBootRetry" at boot under RAILS_ENV=production,
# where Zeitwerk's main autoloader is not yet set up (it is set up in
# Rails' Finisher, which runs after all of config/initializers). Every
# other test in this suite runs after boot completes, once
# DatabaseBootRetry is already loaded, so none of them exercise this
# ordering; only reading the initializer's own source, as this test
# does, catches a future edit that drops the require and reintroduces
# the failure.
class DatabaseBootRetryInitializerTest < ActiveSupport::TestCase
  test 'requires database_boot_retry before referencing the constant' do
    source =
      Rails.root.join('config/initializers/database_boot_retry.rb').read
    require_line = source.index("require 'database_boot_retry'")
    reference_line = source.index('DatabaseBootRetry.connect_with_retry')
    assert require_line, "missing require 'database_boot_retry'"
    assert reference_line, 'missing DatabaseBootRetry.connect_with_retry call'
    assert_operator require_line, :<, reference_line,
                    'require must precede the DatabaseBootRetry reference'
  end
end
