# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# Spot-checks that BaselineToMetalDetective loads its YAML correctly
# and has the right constant shapes.
class BaselineToMetalDetectiveTest < ActiveSupport::TestCase
  test 'OUTPUTS is non-empty (YAML loaded at class load time)' do
    assert BaselineToMetalDetective::OUTPUTS.any?
  end

  test 'INPUTS is non-empty (derived from YAML source criteria)' do
    assert BaselineToMetalDetective::INPUTS.any?
  end

  test 'OUTPUTS includes known metal field' do
    assert_includes BaselineToMetalDetective::OUTPUTS, :require_2FA_status
  end

  test 'INPUTS includes known baseline source field' do
    assert_includes BaselineToMetalDetective::INPUTS, :osps_ac_01_01_status
  end

  test 'OVERRIDABLE_OUTPUTS is empty (never forces overrides)' do
    assert_equal [], BaselineToMetalDetective::OVERRIDABLE_OUTPUTS
  end

  test 'all INPUTS start with osps_ (only sources baseline criteria)' do
    BaselineToMetalDetective::INPUTS.each do |field|
      assert field.to_s.start_with?('osps_'),
             "Expected #{field} to start with 'osps_'"
    end
  end

  test 'no OUTPUTS start with osps_ (only targets metal criteria)' do
    BaselineToMetalDetective::OUTPUTS.each do |field|
      assert_not field.to_s.start_with?('osps_'),
                 "Expected #{field} NOT to start with 'osps_'"
    end
  end

  test 'INPUTS and OUTPUTS have no overlap (no self-referential mapping)' do
    inputs  = BaselineToMetalDetective::INPUTS.to_set
    outputs = BaselineToMetalDetective::OUTPUTS.to_set
    overlap = (inputs & outputs).to_a
    assert overlap.empty?, "INPUTS and OUTPUTS overlap: #{overlap.inspect}"
  end

  test 'MAPPINGS array matches INPUTS and OUTPUTS sizes' do
    expected_inputs  = BaselineToMetalDetective::MAPPINGS
                       .map { |m| :"#{m['source_criterion']}_status" }.uniq
    expected_outputs = BaselineToMetalDetective::MAPPINGS
                       .map { |m| :"#{m['target_criterion']}_status" }.uniq
    assert_equal expected_inputs,  BaselineToMetalDetective::INPUTS
    assert_equal expected_outputs, BaselineToMetalDetective::OUTPUTS
  end

  test 'Met source infers Met target at confidence 3 for osps_ac_01_01 -> require_2FA' do
    evidence = mapping_detective_stub_evidence
    results  = BaselineToMetalDetective.new.analyze(
      evidence, osps_ac_01_01_status: CriterionStatus::MET
    )

    assert results.key?(:require_2FA_status)
    assert_equal CriterionStatus::MET, results[:require_2FA_status][:value]
    assert_equal 3, results[:require_2FA_status][:confidence]
  end

  test 'Unmet source infers Unmet target for osps_ac_01_01 -> require_2FA' do
    evidence = mapping_detective_stub_evidence
    results  = BaselineToMetalDetective.new.analyze(
      evidence, osps_ac_01_01_status: CriterionStatus::UNMET
    )

    assert results.key?(:require_2FA_status)
    assert_equal CriterionStatus::UNMET, results[:require_2FA_status][:value]
    assert_equal 3, results[:require_2FA_status][:confidence]
  end

  test 'NA source infers NA target with confidence 1 for osps_ac_01_01 -> require_2FA' do
    evidence = mapping_detective_stub_evidence
    results  = BaselineToMetalDetective.new.analyze(
      evidence, osps_ac_01_01_status: CriterionStatus::NA
    )

    assert results.key?(:require_2FA_status)
    assert_equal CriterionStatus::NA, results[:require_2FA_status][:value]
    assert_equal 1, results[:require_2FA_status][:confidence]
  end

  test 'UNKNOWN source produces no inference' do
    evidence = mapping_detective_stub_evidence
    results  = BaselineToMetalDetective.new.analyze(
      evidence, osps_ac_01_01_status: CriterionStatus::UNKNOWN
    )

    assert_not results.key?(:require_2FA_status)
  end

  test 'nil evidence returns empty hash' do
    results = BaselineToMetalDetective.new.analyze(nil, osps_ac_01_01_status: CriterionStatus::MET)

    assert_equal({}, results)
  end

  private

  # Minimal evidence stub with a project that has no justification fields set.
  def mapping_detective_stub_evidence
    stub_project = Object.new
    stub_project.define_singleton_method(:[]) { |_key| nil }
    stub_project.define_singleton_method(:attribute_present?) { |_key| false }
    evidence = Object.new
    evidence.define_singleton_method(:project) { stub_project }
    evidence
  end
end
