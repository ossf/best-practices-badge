# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# Spot-checks that MetalToBaselineDetective loads its YAML correctly
# and has the right constant shapes.
class MetalToBaselineDetectiveTest < ActiveSupport::TestCase
  test 'OUTPUTS is non-empty (YAML loaded at class load time)' do
    assert MetalToBaselineDetective::OUTPUTS.any?
  end

  test 'INPUTS is non-empty (derived from YAML source criteria)' do
    assert MetalToBaselineDetective::INPUTS.any?
  end

  test 'OUTPUTS includes known baseline field' do
    assert_includes MetalToBaselineDetective::OUTPUTS, :osps_ac_01_01_status
  end

  test 'INPUTS includes known metal source field' do
    assert_includes MetalToBaselineDetective::INPUTS, :require_2FA_status
  end

  test 'OVERRIDABLE_OUTPUTS is empty (never forces overrides)' do
    assert_equal [], MetalToBaselineDetective::OVERRIDABLE_OUTPUTS
  end

  test 'all OUTPUTS start with osps_ (only targets baseline criteria)' do
    MetalToBaselineDetective::OUTPUTS.each do |field|
      assert field.to_s.start_with?('osps_'),
             "Expected #{field} to start with 'osps_'"
    end
  end

  test 'INPUTS and OUTPUTS have no overlap (no self-referential mapping)' do
    inputs  = MetalToBaselineDetective::INPUTS.to_set
    outputs = MetalToBaselineDetective::OUTPUTS.to_set
    overlap = (inputs & outputs).to_a
    assert overlap.empty?, "INPUTS and OUTPUTS overlap: #{overlap.inspect}"
  end

  test 'MAPPINGS array matches INPUTS and OUTPUTS sizes' do
    expected_inputs  = MetalToBaselineDetective::MAPPINGS
                       .map { |m| :"#{m['source_criterion']}_status" }.uniq
    expected_outputs = MetalToBaselineDetective::MAPPINGS
                       .map { |m| :"#{m['target_criterion']}_status" }.uniq
    assert_equal expected_inputs,  MetalToBaselineDetective::INPUTS
    assert_equal expected_outputs, MetalToBaselineDetective::OUTPUTS
  end
end
