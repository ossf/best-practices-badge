# frozen_string_literal: true

# Copyright the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'
require 'open3'

# CI runs script/validate_branch_name on $CIRCLE_BRANCH before using it.
class ValidateBranchNameTest < ActiveSupport::TestCase
  SCRIPT = Rails.root.join('script/validate_branch_name').to_s

  def valid?(name)
    _out, _err, status = Open3.capture3(SCRIPT, name)
    status.success?
  end

  test 'accepts ordinary branch names' do
    %w[main staging production feature/x].each { |name| assert valid?(name), name }
  end

  test 'rejects empty names and leading dash or slash' do
    ['', '-x', '/x'].each { |name| assert_not valid?(name), name.inspect }
  end
end
