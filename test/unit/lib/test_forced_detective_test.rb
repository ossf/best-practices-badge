# frozen_string_literal: true

# Copyright the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

class TestForcedDetectiveTest < ActiveSupport::TestCase
  test 'returns forced override for trigger URL' do
    detective = TestForcedDetective.new
    project = Project.new(repo_url: 'https://example.com/test/force-override')
    evidence = Evidence.new(project)
    current = { repo_url: 'https://example.com/test/force-override' }

    result = detective.analyze(evidence, current)

    assert_equal 'Met', result[:description_good_status][:value]
    assert_equal 5, result[:description_good_status][:confidence]
  end

  test 'returns empty for other URLs' do
    detective = TestForcedDetective.new
    project = Project.new(repo_url: 'https://example.com/other/repo')
    evidence = Evidence.new(project)
    current = { repo_url: 'https://example.com/other/repo' }

    result = detective.analyze(evidence, current)

    assert_empty result
  end
end
