# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# A 'Detective' (analyzer) analyzes data from evidence and reports
# what it believes the new values should be.
# This is subclassed (one per each analyzer); an instance analyzes 1 project.
# Only the 'chief' decides when to update the proposed changes.

class Detective
  attr_writer :octokit_client_factory

  # Individual detectives must identify their inputs and outputs
  # as a list of field name symbols.
  INPUTS = [].freeze
  OUTPUTS = [].freeze

  # Individual detectives must identify which outputs can override user input
  # (when confidence >= Chief::CONFIDENCE_OVERRIDE).
  # Outputs not listed here will only fill in blank/'?' fields.
  OVERRIDABLE_OUTPUTS = [].freeze

  # Individual detectives must implement "analyze"
  # "Current" is a hash of current best estimates of fields and values.
  # We pass this separately from the evidence to reduce potential problems
  # from parallel execution (if we add that later).
  # The "analyze" method returns its best estimates in this form:
  # { fieldname1: { value: value, confidence: 1..5, explanation: text}, ...}
  # fieldnames can be proposed project value, or names of intermediate
  # values that later Detectives can use.

  def analyze(_evidence, _current); end
end
