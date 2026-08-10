# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# Test the BaselineDetective placeholder.
# BaselineDetective currently has no INPUTS/OUTPUTS; all baseline
# automation is handled by existing detectives (GithubBasicDetective,
# RepoFilesExamineDetective, FlossLicenseDetective, etc.).
class BaselineDetectiveTest < ActiveSupport::TestCase
  setup do
    @detective = BaselineDetective.new
  end

  test 'has empty inputs and outputs' do
    assert_equal [], BaselineDetective::INPUTS
    assert_equal [], BaselineDetective::OUTPUTS
    assert_equal [], BaselineDetective::OVERRIDABLE_OUTPUTS
  end

  test 'analyze returns empty hash' do
    results = @detective.analyze(nil, {})

    assert results.is_a?(Hash)
    assert results.empty?
  end

  test 'analyze returns empty hash with arbitrary inputs' do
    results = @detective.analyze(nil, license: 'MIT', repo_files: 'something')

    assert results.is_a?(Hash)
    assert results.empty?
  end
end
