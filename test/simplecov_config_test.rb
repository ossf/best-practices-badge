# frozen_string_literal: true

# Copyright the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'English'
require 'test_helper'

# Coverage is *measured* by the test processes, but it is *merged* and
# reported by a separate rake process ('test:optimized' and
# 'test:coverage_gaps' in lib/tasks/default.rake) that only does
# `require 'simplecov'`; it never loads test/test_helper.rb. The two must
# agree on SimpleCov's configuration, which is why that configuration lives
# in `.simplecov`, a file SimpleCov auto-loads on require.
#
# When they silently disagreed, nothing failed loudly. The merging process
# fell back to SimpleCov's default 600-second merge_timeout, discarded the
# regular tests' results as "expired" once the slow system tests pushed a
# run past 10 minutes, and reported thoroughly tested code as never executed.
# These tests guard that invariant so it cannot rot back.
class SimplecovConfigTest < ActiveSupport::TestCase
  # Ask a bare Ruby process - one that requires simplecov and nothing else,
  # exactly as the merging rake task does - what configuration it sees.
  def merging_process_value(expression)
    value = `ruby -e 'require "simplecov"; print #{expression}'`
    assert_predicate $CHILD_STATUS, :success?,
                     'Could not load SimpleCov in a bare Ruby process'
    value
  end

  test 'merge_timeout outlasts an entire test:optimized run' do
    # A full run writes the regular tests' results, then runs the much
    # slower system tests, and only merges at the very end. Results older
    # than merge_timeout are dropped from the merged report, which looks
    # like untested code rather than like an error.
    assert_operator SimpleCov.merge_timeout, :>, 600
  end

  test 'coverage-merging process shares our SimpleCov configuration' do
    assert_equal SimpleCov.merge_timeout.to_s,
                 merging_process_value('SimpleCov.merge_timeout')
  end
end
