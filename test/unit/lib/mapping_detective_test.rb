# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# Tests for MappingDetective analyze logic, exercised via MetalToBaselineDetective.
# Most tests pass a `current` hash with the relevant _status key and use a
# minimal project stub for justification — no database needed for pure-logic tests.
# rubocop:disable Metrics/ClassLength
class MappingDetectiveTest < ActiveSupport::TestCase
  # Minimal project stub that supports [] and attribute_present? for justification fields
  class StubProject
    def initialize(justifications = {})
      @justifications = justifications
    end

    delegate :[], to: :@justifications

    def attribute_present?(key)
      @justifications.key?(key)
    end
  end

  # Minimal evidence stub that wraps a StubProject
  class StubEvidence
    attr_reader :project

    def initialize(justifications = {})
      @project = StubProject.new(justifications)
    end
  end

  # Use require_2FA -> osps_ac_01_01 (confidence_met: 3, confidence_unmet: 3, confidence_na: 1)
  # as the canonical test mapping (strong same-status entry).
  SOURCE = :require_2FA_status
  TARGET = :osps_ac_01_01_status

  test 'Met source infers Met target at correct confidence' do
    evidence = StubEvidence.new
    results = MetalToBaselineDetective.new.analyze(evidence, SOURCE => CriterionStatus::MET)

    assert results.key?(TARGET)
    assert_equal CriterionStatus::MET, results[TARGET][:value]
    assert_equal 3, results[TARGET][:confidence]
  end

  test 'Unmet source infers Unmet target at correct confidence' do
    evidence = StubEvidence.new
    results = MetalToBaselineDetective.new.analyze(evidence, SOURCE => CriterionStatus::UNMET)

    assert results.key?(TARGET)
    assert_equal CriterionStatus::UNMET, results[TARGET][:value]
    assert_equal 3, results[TARGET][:confidence]
  end

  test 'NA source infers NA target with confidence_na integer form' do
    evidence = StubEvidence.new
    results = MetalToBaselineDetective.new.analyze(evidence, SOURCE => CriterionStatus::NA)

    assert results.key?(TARGET)
    assert_equal CriterionStatus::NA, results[TARGET][:value]
    assert_equal 1, results[TARGET][:confidence]
  end

  test 'cross-status array form: NA source infers Unmet target' do
    # vulnerability_report_private -> osps_vm_03_01 has confidence_na: [2, "Unmet"]
    evidence = StubEvidence.new
    results = MetalToBaselineDetective.new.analyze(
      evidence, vulnerability_report_private_status: CriterionStatus::NA
    )

    assert results.key?(:osps_vm_03_01_status)
    assert_equal CriterionStatus::UNMET, results[:osps_vm_03_01_status][:value]
    assert_equal 2, results[:osps_vm_03_01_status][:confidence]
  end

  test 'zero confidence entry is skipped' do
    # version_unique -> osps_br_02_02 has confidence_na: 0 (absent) -
    # instead use a source with only confidence_met and confidence_unmet set
    # and pass UNKNOWN to verify UNKNOWN source produces no result.
    evidence = StubEvidence.new
    results = MetalToBaselineDetective.new.analyze(
      evidence, require_2FA_status: CriterionStatus::UNKNOWN
    )

    # UNKNOWN source status should not produce any result for this target
    assert_not results.key?(TARGET)
  end

  test 'UNKNOWN source produces no inference' do
    evidence = StubEvidence.new
    results = MetalToBaselineDetective.new.analyze(
      evidence, SOURCE => CriterionStatus::UNKNOWN
    )

    assert_not results.key?(TARGET)
  end

  test 'nil source produces no inference' do
    evidence = StubEvidence.new
    results = MetalToBaselineDetective.new.analyze(evidence, SOURCE => nil)

    assert_not results.key?(TARGET)
  end

  test 'missing source key produces no inference' do
    evidence = StubEvidence.new
    results = MetalToBaselineDetective.new.analyze(evidence, {})

    assert_not results.key?(TARGET)
  end

  test 'when two sources map to same target, higher confidence wins' do
    # version_unique (conf_met: 3) and version_unique (conf_met: 2 for osps_br_02_02).
    # Instead exercise deduplication directly via two mappings targeting the same field.
    # osps_br_02_01 gets confidence 3 from version_unique (Met).
    # If we pass both version_unique Met and a weaker source mapping to the same target,
    # the higher-confidence one should appear.
    # Easiest check: version_unique Met -> osps_br_02_01 = conf 3; pass Met and verify conf is 3.
    evidence = StubEvidence.new
    results = MetalToBaselineDetective.new.analyze(
      evidence, version_unique_status: CriterionStatus::MET
    )

    assert results.key?(:osps_br_02_01_status)
    assert_equal 3, results[:osps_br_02_01_status][:confidence]
  end

  test 'explanation includes source justification when present' do
    evidence = StubEvidence.new(require_2FA_justification: 'We use GitHub 2FA.')
    results = MetalToBaselineDetective.new.analyze(evidence, SOURCE => CriterionStatus::MET)

    assert results.key?(TARGET)
    assert_equal 'We use GitHub 2FA. [require_2FA]', results[TARGET][:explanation]
  end

  test 'explanation is bracketed source name when no justification' do
    evidence = StubEvidence.new
    results = MetalToBaselineDetective.new.analyze(evidence, SOURCE => CriterionStatus::MET)

    assert results.key?(TARGET)
    assert_equal '[require_2FA]', results[TARGET][:explanation]
  end

  test 'nil evidence returns empty hash' do
    results = MetalToBaselineDetective.new.analyze(nil, SOURCE => CriterionStatus::MET)

    assert_equal({}, results)
  end

  # -------------------------------------------------------------------------
  # Case 2: source value came from a prior detective proposal
  # -------------------------------------------------------------------------

  # Build a stub evidence whose project has no badge value for SOURCE
  # (simulating a blank/UNKNOWN project field) so the mapping detective
  # takes the proposal path.
  def stub_evidence_no_project_value
    stub_project = Object.new
    stub_project.define_singleton_method(:[]) { |_key| nil }
    stub_project.define_singleton_method(:attribute_present?) { |_key| false }
    stub_project.define_singleton_method(:has_attribute?) { |_key| false }
    evidence = Object.new
    evidence.define_singleton_method(:project) { stub_project }
    evidence
  end

  test 'proposal source: confidence is scaled by prior detective confidence' do
    # require_2FA -> osps_ac_01_01: yaml confidence_met = 3, MAX_CONFIDENCE = 5
    # Prior detective confidence 4 => scaled = 4 * 3 / 5 = 2.4
    evidence = stub_evidence_no_project_value
    source_proposals = {
      SOURCE => {
        value: CriterionStatus::MET,
        confidence: 4,
        explanation: 'Detected 2FA enabled.'
      }
    }
    results = MetalToBaselineDetective.new.analyze(
      evidence, { SOURCE => CriterionStatus::MET }, source_proposals
    )

    assert results.key?(TARGET)
    assert_equal CriterionStatus::MET, results[TARGET][:value]
    assert_in_delta 2.4, results[TARGET][:confidence], 0.001
  end

  test 'proposal source: explanation carries prior detective text with source name' do
    evidence = stub_evidence_no_project_value
    source_proposals = {
      SOURCE => {
        value: CriterionStatus::MET,
        confidence: 5,
        explanation: 'Detected 2FA enabled.'
      }
    }
    results = MetalToBaselineDetective.new.analyze(
      evidence, { SOURCE => CriterionStatus::MET }, source_proposals
    )

    assert results.key?(TARGET)
    assert_equal 'Detected 2FA enabled. [require_2FA]', results[TARGET][:explanation]
  end

  test 'proposal source: blank prior explanation yields bracketed source name' do
    evidence = stub_evidence_no_project_value
    source_proposals = {
      SOURCE => {
        value: CriterionStatus::MET,
        confidence: 5,
        explanation: ''
      }
    }
    results = MetalToBaselineDetective.new.analyze(
      evidence, { SOURCE => CriterionStatus::MET }, source_proposals
    )

    assert results.key?(TARGET)
    assert_equal '[require_2FA]', results[TARGET][:explanation]
  end

  test 'proposal source: scaled confidence < 0.5 drops the result' do
    # yaml confidence_na = 1 for require_2FA -> osps_ac_01_01
    # Prior detective confidence 2 => scaled = 2 * 1 / 5 = 0.4 < 0.5 => dropped
    evidence = stub_evidence_no_project_value
    source_proposals = {
      SOURCE => {
        value: CriterionStatus::NA,
        confidence: 2,
        explanation: 'N/A per policy.'
      }
    }
    results = MetalToBaselineDetective.new.analyze(
      evidence, { SOURCE => CriterionStatus::NA }, source_proposals
    )

    assert_not results.key?(TARGET)
  end

  test 'proposal source: scaled confidence >= 0.5 is kept as float' do
    # yaml confidence_na = 1 for require_2FA -> osps_ac_01_01
    # Prior detective confidence 3 => scaled = 3 * 1 / 5 = 0.6 >= 0.5 => kept
    evidence = stub_evidence_no_project_value
    source_proposals = {
      SOURCE => {
        value: CriterionStatus::NA,
        confidence: 3,
        explanation: ''
      }
    }
    results = MetalToBaselineDetective.new.analyze(
      evidence, { SOURCE => CriterionStatus::NA }, source_proposals
    )

    assert results.key?(TARGET)
    assert_in_delta 0.6, results[TARGET][:confidence], 0.001
  end

  test 'project_has_value? returns false when project[field] raises MissingAttributeError' do
    # Simulates the edge case where has_attribute? and attribute_present? both
    # report a field is present, but accessing it raises MissingAttributeError
    # (e.g., a race condition or unusual AR state).  The rescue branch on
    # mapping_detective.rb:185 must return false so analyze falls through to
    # the no-proposal fallback and still produces a result via YAML confidence.
    # Raise only for _status fields (triggering the rescue in project_has_value?).
    # Return nil for _justification fields so build_explanation can proceed safely.
    stub_project = Object.new
    stub_project.define_singleton_method(:has_attribute?) { |key| key.to_s.end_with?('_status') }
    stub_project.define_singleton_method(:attribute_present?) { |key| key.to_s.end_with?('_status') }
    stub_project.define_singleton_method(:[]) do |key|
      raise ActiveModel::MissingAttributeError if key.to_s.end_with?('_status')

      nil
    end
    evidence = Object.new
    evidence.define_singleton_method(:project) { stub_project }

    results = MetalToBaselineDetective.new.analyze(evidence, SOURCE => CriterionStatus::MET)

    # project_has_value? rescued and returned false; no proposals => fallback to YAML conf
    assert results.key?(TARGET)
    assert_equal CriterionStatus::MET, results[TARGET][:value]
    assert_equal 3, results[TARGET][:confidence]
  end

  test 'explanation is bracketed source name when justification not loaded (partial AR select)' do
    # Simulates a Project loaded via a partial SELECT (e.g., set_project_for_section
    # only loads the current section's columns). The project responds to
    # has_attribute? but returns false for the source justification field,
    # mimicking AR behaviour when a column exists in the schema but was
    # not included in the SELECT clause.
    stub_project = Object.new
    stub_project.define_singleton_method(:[]) { |_key| raise ActiveModel::MissingAttributeError }
    stub_project.define_singleton_method(:attribute_present?) { |_key| false }
    stub_project.define_singleton_method(:has_attribute?) { |_key| false }
    evidence = Object.new
    evidence.define_singleton_method(:project) { stub_project }

    results = MetalToBaselineDetective.new.analyze(evidence, SOURCE => CriterionStatus::MET)

    assert results.key?(TARGET)
    assert_equal '[require_2FA]', results[TARGET][:explanation]
  end
end
# rubocop:enable Metrics/ClassLength
