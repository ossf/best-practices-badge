# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# Regression test for the same defect covered by
# test/config/initializers/database_boot_retry_test.rb: this
# initializer also referenced an autoloaded lib/ constant
# (DatabaseUrlGuard) with no preceding require, so it would have hit
# the identical "uninitialized constant" boot failure under
# RAILS_ENV=production, one initializer after database_boot_retry.rb
# in load order. The 2026-09-15 deploy never got far enough to reveal
# this one; precompile aborted on database_boot_retry.rb first.
class RedactDatabaseUrlInitializerTest < ActiveSupport::TestCase
  test 'requires database_url_guard before referencing the constant' do
    source =
      Rails.root.join('config/initializers/redact_database_url.rb').read
    require_line = source.index("require 'database_url_guard'")
    reference_line = source.index('DatabaseUrlGuard.check!')
    assert require_line, "missing require 'database_url_guard'"
    assert reference_line, 'missing DatabaseUrlGuard.check! call'
    assert_operator require_line, :<, reference_line,
                    'require must precede the DatabaseUrlGuard reference'
  end
end
