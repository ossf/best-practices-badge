# frozen_string_literal: true

# Copyright the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Test-only detective that produces automation results for specific URLs.
# Used to test override detection, non-forced auto-fill, and warning paths
# in projects_controller without needing to mock Chief behavior.
#
# Only active in test environment. Only triggers for specific test URLs.
class TestForcedDetective < Detective
  INPUTS = [:repo_url].freeze
  OUTPUTS = [:description_good_status].freeze
  OVERRIDABLE_OUTPUTS = [:description_good_status].freeze

  # Map of test URLs to their confidence levels.
  TEST_URLS = {
    'https://example.com/test/force-override' => 5, # Forced override
    'https://example.com/test/auto-fill' => 2       # Non-forced fill
  }.freeze

  # @return [Hash] Proposed change for specific test URLs, empty otherwise
  def analyze(_evidence, current)
    repo_url = current[:repo_url]

    # Special URL to test Chief exception handling
    if repo_url == 'https://example.com/test/chief-failure'
      raise StandardError, 'Test chief failure for coverage'
    end

    confidence = TEST_URLS[repo_url]
    return {} unless confidence

    { description_good_status: met_proposal(confidence) }
  end

  private

  # @param confidence [Integer] Confidence level for the proposal
  # @return [Hash] A proposal hash setting description_good_status to Met
  def met_proposal(confidence)
    {
      value: 'Met',
      confidence: confidence,
      explanation: I18n.t('detectives.test_forced.test_automation',
                          confidence: confidence)
    }
  end
end
