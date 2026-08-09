# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

class RakeTaskTest < ActiveSupport::TestCase
  test 'regression test for rake reminders' do
    assert_not_equal 0, Project.projects_to_remind.size

    # This tests the actual rake command as it would be used in production
    result = system('bundle exec rake reminders >/dev/null 2>&1')
    assert result, 'rake reminders command should succeed'

    # This should work but isn't reliable on David's dev system.
    # assert_equal 0, Project.projects_to_remind.size
  end
end
