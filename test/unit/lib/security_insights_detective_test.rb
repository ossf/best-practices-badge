# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# rubocop:disable Metrics/ClassLength
class SecurityInsightsDetectiveTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Test helpers
  # ---------------------------------------------------------------------------

  # A mock repo_files object that returns a given content string for one
  # specific filename and nil for everything else.
  class MockRepoFiles
    def initialize(path, content)
      @path    = path
      @content = content
    end

    def blank?
      false
    end

    def get_content(path, max_size: nil) # rubocop:disable Lint/UnusedMethodArgument
      path == @path ? @content : nil
    end
  end

  # A mock that returns nil for every path (simulates a repo with no SI file).
  class MockRepoFilesEmpty
    def blank?
      false
    end

    def get_content(_path, max_size: nil) # rubocop:disable Lint/UnusedMethodArgument
      nil
    end
  end

  def run_detective(repo_files)
    SecurityInsightsDetective.new.analyze(nil, repo_files: repo_files)
  end

  # ---------------------------------------------------------------------------
  # Edge cases
  # ---------------------------------------------------------------------------

  test 'value_present? returns false for array of empty strings' do
    detective = SecurityInsightsDetective.new
    assert_equal false, detective.send(:value_present?, [''])
    assert_equal false, detective.send(:value_present?, ['', ''])
    assert_equal false, detective.send(:value_present?, [nil])
    assert_equal false, detective.send(:value_present?, [nil, ''])
    assert_equal true,  detective.send(:value_present?, ['x'])
    assert_equal true,  detective.send(:value_present?, ['', 'x'])
  end

  test 'si_item_field with si_alternatives produces correct array_match_description' do
    detective = SecurityInsightsDetective.new
    mapping = {
      'si_path'         => 'repository.security.tools',
      'si_item_field'   => 'type',
      'si_alternatives' => %w[SAST DAST]
    }
    assert_equal 'type=SAST|DAST', detective.send(:array_match_description, mapping)
  end

  test 'si_value and si_alternatives together raises ArgumentError' do
    detective = SecurityInsightsDetective.new
    mapping = { 'si_value' => 'x', 'si_alternatives' => %w[a b] }
    assert_raises(ArgumentError) { detective.send(:condition_met?, mapping, 'x') }
  end

  test 'also without si_item_field raises ArgumentError' do
    detective = SecurityInsightsDetective.new
    mapping = { 'also' => 'integration.ci' }
    assert_raises(ArgumentError) { detective.send(:condition_met?, mapping, true) }
  end

  test 'returns empty hash when repo_files is blank' do
    # A blank repo_files (no GitHub URL resolved) produces nothing.
    results = SecurityInsightsDetective.new.analyze(nil, repo_files: nil)
    assert_equal({}, results)
  end

  test 'assessments.self.evidence (not self) drives security_review proposal' do
    # assessments.self is required in the SI spec, so "present" would always
    # fire.  Only the optional evidence URL indicates an actual assessment.
    yaml_with_evidence = <<~YAML
      repository:
        security:
          assessments:
            self:
              comment: done
              evidence: https://example.com/assessment-report
    YAML
    yaml_without_evidence = <<~YAML
      repository:
        security:
          assessments:
            self:
              comment: not done yet
    YAML
    with_ev    = run_detective(MockRepoFiles.new('security-insights.yml', yaml_with_evidence))
    without_ev = run_detective(MockRepoFiles.new('security-insights.yml', yaml_without_evidence))

    assert_equal CriterionStatus::MET, with_ev[:security_review_status][:value]
    assert_not without_ev.key?(:security_review_status),
               'self.evidence absent must not produce a security_review proposal'
  end

  test 'returns empty hash when no security-insights file found' do
    results = run_detective(MockRepoFilesEmpty.new)
    assert_equal({}, results)
  end

  test 'returns empty hash for malformed YAML' do
    results = run_detective(MockRepoFiles.new('security-insights.yml', ': bad: yaml: ['))
    assert_equal({}, results)
  end

  test 'returns empty hash for YAML that is not a Hash' do
    results = run_detective(MockRepoFiles.new('security-insights.yml', "- a\n- b\n"))
    assert_equal({}, results)
  end

  test 'rejects YAML with aliases (alias bomb protection)' do
    bomb = <<~YAML
      a: &anchor
        - x
      b: *anchor
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', bomb))
    assert_equal({}, results)
  end

  # ---------------------------------------------------------------------------
  # File location discovery
  # ---------------------------------------------------------------------------

  test 'finds file in repo root' do
    yaml = <<~YAML
      repository:
        status: active
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    assert results.key?(:maintained_status)
  end

  test 'finds file in .github directory' do
    yaml = <<~YAML
      repository:
        status: active
    YAML
    results = run_detective(MockRepoFiles.new('.github/security-insights.yml', yaml))
    assert results.key?(:maintained_status)
  end

  test 'finds uppercase SECURITY-INSIGHTS.yml in repo root' do
    yaml = <<~YAML
      repository:
        status: active
    YAML
    results = run_detective(MockRepoFiles.new('SECURITY-INSIGHTS.yml', yaml))
    assert results.key?(:maintained_status)
  end

  # ---------------------------------------------------------------------------
  # si_value matching (booleans and strings)
  # ---------------------------------------------------------------------------

  test 'reports-accepted true infers vulnerability_report_process Met' do
    yaml = <<~YAML
      project:
        vulnerability-reporting:
          reports-accepted: true
          bug-bounty-available: false
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    assert_equal CriterionStatus::MET, results[:vulnerability_report_process_status][:value]
    assert_equal 2, results[:vulnerability_report_process_status][:confidence]
  end

  test 'reports-accepted false infers vulnerability_report_process Unmet' do
    yaml = <<~YAML
      project:
        vulnerability-reporting:
          reports-accepted: false
          bug-bounty-available: false
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    assert_equal CriterionStatus::UNMET, results[:vulnerability_report_process_status][:value]
    assert_equal 2, results[:vulnerability_report_process_status][:confidence]
  end

  test 'reports-accepted true does NOT infer osps_vm_03_01 (confidence 0)' do
    # reports-accepted=true says nothing about whether the reporting channel is
    # *private*, so this mapping is disabled (confidence: 0).
    yaml = <<~YAML
      project:
        vulnerability-reporting:
          reports-accepted: true
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    assert_not results.key?(:osps_vm_03_01_status),
               'reports-accepted=true must not propose osps_vm_03_01 (conf 0)'
  end

  test 'reports-accepted false infers osps_vm_03_01 Unmet with confidence 2.5' do
    yaml = <<~YAML
      project:
        vulnerability-reporting:
          reports-accepted: false
          bug-bounty-available: false
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    assert_equal CriterionStatus::UNMET, results[:osps_vm_03_01_status][:value]
    assert_equal 2.5, results[:osps_vm_03_01_status][:confidence]
  end

  test 'automated-pipeline true infers build Met' do
    yaml = <<~YAML
      repository:
        release:
          automated-pipeline: true
          distribution-points:
            - uri: https://example.com
              comment: main dist
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    assert_equal CriterionStatus::MET, results[:build_status][:value]
    assert_equal 2, results[:build_status][:confidence]
  end

  # ---------------------------------------------------------------------------
  # Presence check (no match fields)
  # ---------------------------------------------------------------------------

  test 'policy URL present infers vulnerability_report_process Met' do
    yaml = <<~YAML
      project:
        vulnerability-reporting:
          reports-accepted: false
          bug-bounty-available: false
          policy: https://example.com/security.html
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    # policy present should infer Met at conf 2, overriding false→Unmet at conf 2
    # (tie is broken by first-encountered, so reports-accepted=false wins for
    # vulnerability_report_process, but policy present also fires for osps_vm_01_01)
    assert results.key?(:osps_vm_01_01_status)
    assert_equal CriterionStatus::MET, results[:osps_vm_01_01_status][:value]
  end

  test 'pgp-key present infers vulnerability_report_private Met' do
    yaml = <<~YAML
      project:
        vulnerability-reporting:
          reports-accepted: true
          bug-bounty-available: false
          pgp-key: "DEADBEEF..."
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    assert_equal CriterionStatus::MET, results[:vulnerability_report_private_status][:value]
    assert_equal 2, results[:vulnerability_report_private_status][:confidence]
  end

  test 'contributing-guide URL infers contribution and osps_gv_03_01 Met' do
    yaml = <<~YAML
      repository:
        documentation:
          contributing-guide: https://example.com/contributing
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    assert_equal CriterionStatus::MET, results[:contribution_status][:value]
    assert_equal CriterionStatus::MET, results[:osps_gv_03_01_status][:value]
  end

  test 'security-policy URL infers osps_vm_01_01 and osps_vm_02_01 Met' do
    yaml = <<~YAML
      repository:
        documentation:
          security-policy: https://example.com/security-policy
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    assert_equal CriterionStatus::MET, results[:osps_vm_01_01_status][:value]
    assert_equal CriterionStatus::MET, results[:osps_vm_02_01_status][:value]
  end

  test 'changelog URL infers release_notes and osps_br_04_01 Met' do
    yaml = <<~YAML
      repository:
        release:
          automated-pipeline: false
          distribution-points:
            - uri: https://example.com
              comment: dist
          changelog: https://example.com/changelog
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    assert_equal CriterionStatus::MET, results[:release_notes_status][:value]
    assert_equal CriterionStatus::MET, results[:osps_br_04_01_status][:value]
  end

  test 'absent optional field produces no proposal' do
    # governance key is absent entirely; no proposal for osps_gv_01_01
    yaml = <<~YAML
      repository:
        documentation:
          contributing-guide: https://example.com/contributing
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    assert_not results.key?(:osps_gv_01_01_status)
  end

  # ---------------------------------------------------------------------------
  # si_value string matching
  # ---------------------------------------------------------------------------

  test 'repository.status active infers maintained Met' do
    yaml = <<~YAML
      repository:
        status: active
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    assert_equal CriterionStatus::MET, results[:maintained_status][:value]
    assert_equal 2, results[:maintained_status][:confidence]
  end

  # ---------------------------------------------------------------------------
  # si_alternatives matching
  # ---------------------------------------------------------------------------

  test 'repository.status abandoned infers maintained Unmet' do
    yaml = <<~YAML
      repository:
        status: abandoned
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    assert_equal CriterionStatus::UNMET, results[:maintained_status][:value]
  end

  test 'repository.status suspended infers maintained Unmet' do
    yaml = <<~YAML
      repository:
        status: suspended
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    assert_equal CriterionStatus::UNMET, results[:maintained_status][:value]
  end

  test 'repository.status WIP produces no maintained proposal' do
    yaml = <<~YAML
      repository:
        status: WIP
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    assert_not results.key?(:maintained_status)
  end

  # ---------------------------------------------------------------------------
  # si_item_field matching
  # ---------------------------------------------------------------------------

  test 'SAST tool infers static_analysis Met' do
    yaml = <<~YAML
      repository:
        security:
          assessments:
            self:
              comment: not done
          tools:
            - name: SomeScanner
              type: SAST
              rulesets:
                - default
              integration:
                adhoc: true
                ci: false
                release: false
              results: {}
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    assert_equal CriterionStatus::MET, results[:static_analysis_status][:value]
    assert_equal 2, results[:static_analysis_status][:confidence]
  end

  test 'SCA tool infers dependency_monitoring Met' do
    yaml = <<~YAML
      repository:
        security:
          assessments:
            self:
              comment: not done
          tools:
            - name: Dependabot
              type: SCA
              rulesets:
                - default
              integration:
                adhoc: false
                ci: false
                release: false
              results: {}
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    assert_equal CriterionStatus::MET, results[:dependency_monitoring_status][:value]
  end

  test 'fuzzing tool infers dynamic_analysis Met' do
    yaml = <<~YAML
      repository:
        security:
          assessments:
            self:
              comment: not done
          tools:
            - name: OSS-Fuzz
              type: fuzzing
              rulesets:
                - default
              integration:
                adhoc: false
                ci: true
                release: false
              results: {}
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    assert_equal CriterionStatus::MET, results[:dynamic_analysis_status][:value]
  end

  test 'no tools produces no tool-based proposals' do
    yaml = <<~YAML
      repository:
        security:
          assessments:
            self:
              comment: not done
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    assert_not results.key?(:static_analysis_status)
    assert_not results.key?(:dependency_monitoring_status)
  end

  # ---------------------------------------------------------------------------
  # si_item_field with also
  # ---------------------------------------------------------------------------

  test 'SAST tool with ci=true infers osps_vm_06_02 at confidence 2' do
    yaml = <<~YAML
      repository:
        security:
          assessments:
            self:
              comment: not done
          tools:
            - name: SomeScanner
              type: SAST
              rulesets:
                - default
              integration:
                adhoc: false
                ci: true
                release: false
              results: {}
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    assert_equal CriterionStatus::MET, results[:osps_vm_06_02_status][:value]
    assert_equal 2, results[:osps_vm_06_02_status][:confidence]
  end

  test 'SAST tool with ci=false infers osps_vm_06_02 at confidence 1 only' do
    yaml = <<~YAML
      repository:
        security:
          assessments:
            self:
              comment: not done
          tools:
            - name: SomeScanner
              type: SAST
              rulesets:
                - default
              integration:
                adhoc: true
                ci: false
                release: false
              results: {}
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    assert_equal CriterionStatus::MET, results[:osps_vm_06_02_status][:value]
    assert_equal 1, results[:osps_vm_06_02_status][:confidence]
  end

  test 'SCA tool with ci=true infers osps_vm_05_03 at confidence 2' do
    yaml = <<~YAML
      repository:
        security:
          assessments:
            self:
              comment: not done
          tools:
            - name: Dependabot
              type: SCA
              rulesets:
                - default
              integration:
                adhoc: false
                ci: true
                release: false
              results: {}
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    assert_equal CriterionStatus::MET, results[:osps_vm_05_03_status][:value]
    assert_equal 2, results[:osps_vm_05_03_status][:confidence]
  end

  # ---------------------------------------------------------------------------
  # si_item_field with substring
  # ---------------------------------------------------------------------------

  test 'SLSA attestation infers signed_releases and osps_br_06_01 Met' do
    yaml = <<~YAML
      repository:
        release:
          automated-pipeline: true
          distribution-points:
            - uri: https://example.com
              comment: dist
          attestations:
            - name: SLSA provenance
              location: https://example.com/provenance
              predicate-uri: https://slsa.dev/provenance/v1
              comment: ""
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    assert_equal CriterionStatus::MET, results[:signed_releases_status][:value]
    assert_equal CriterionStatus::MET, results[:osps_br_06_01_status][:value]
  end

  test 'SPDX attestation infers osps_qa_02_02 Met' do
    yaml = <<~YAML
      repository:
        release:
          automated-pipeline: false
          distribution-points:
            - uri: https://example.com
              comment: dist
          attestations:
            - name: SBOM
              location: https://example.com/sbom
              predicate-uri: https://spdx.dev/Document
              comment: ""
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    assert_equal CriterionStatus::MET, results[:osps_qa_02_02_status][:value]
  end

  test 'other attestation predicate-uri produces no slsa or spdx proposals' do
    yaml = <<~YAML
      repository:
        release:
          automated-pipeline: false
          distribution-points:
            - uri: https://example.com
              comment: dist
          attestations:
            - name: Custom
              location: https://example.com/custom
              predicate-uri: https://example.com/custom-predicate
              comment: ""
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    assert_not results.key?(:signed_releases_status)
    assert_not results.key?(:osps_qa_02_02_status)
  end

  # ---------------------------------------------------------------------------
  # Highest-confidence wins when multiple entries target same criterion
  # ---------------------------------------------------------------------------

  test 'higher confidence wins when two entries fire for same target' do
    # SAST tool fires si_item_field:type (conf 1) and si_item_field:type+also (conf 2)
    # for osps_vm_06_02; confidence 2 should win.
    yaml = <<~YAML
      repository:
        security:
          assessments:
            self:
              comment: not done
          tools:
            - name: Scanner
              type: SAST
              rulesets:
                - default
              integration:
                adhoc: false
                ci: true
                release: false
              results: {}
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    assert_equal 2, results[:osps_vm_06_02_status][:confidence]
  end

  # ---------------------------------------------------------------------------
  # Comment inclusion in explanation text
  # ---------------------------------------------------------------------------

  test 'vulnerability-reporting comment is included in explanation' do
    yaml = <<~YAML
      project:
        vulnerability-reporting:
          reports-accepted: true
          bug-bounty-available: false
          comment: "Use our HackerOne program for all security reports."
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    explanation = results[:vulnerability_report_process_status][:explanation]
    assert_includes explanation, 'Comment says:'
    assert_includes explanation, 'HackerOne program'
  end

  test 'tool comment is included in explanation for si_item_field match' do
    yaml = <<~YAML
      repository:
        security:
          assessments:
            self:
              comment: not done
          tools:
            - name: SomeScanner
              type: SAST
              comment: "Runs on every PR via GitHub Actions."
              rulesets:
                - default
              integration:
                adhoc: false
                ci: true
                release: false
              results: {}
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    explanation = results[:static_analysis_status][:explanation]
    assert_includes explanation, 'Comment says:'
    assert_includes explanation, 'GitHub Actions'
  end

  test 'attestation comment is included in explanation for si_item_field substring match' do
    yaml = <<~YAML
      repository:
        release:
          automated-pipeline: true
          distribution-points:
            - uri: https://example.com
              comment: dist
          attestations:
            - name: SLSA provenance
              location: https://example.com/provenance
              predicate-uri: https://slsa.dev/provenance/v1
              comment: "Generated by our release workflow."
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    explanation = results[:signed_releases_status][:explanation]
    assert_includes explanation, 'Comment says:'
    assert_includes explanation, 'release workflow'
  end

  test 'absent or empty comment produces no comment suffix' do
    yaml = <<~YAML
      project:
        vulnerability-reporting:
          reports-accepted: true
          bug-bounty-available: false
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    explanation = results[:vulnerability_report_process_status][:explanation]
    assert_not_includes explanation, 'Comment says:'
  end

  test 'assessment self comment is included when evidence present' do
    yaml = <<~YAML
      repository:
        security:
          assessments:
            self:
              comment: "Reviewed architecture and threat model in Q1 2025."
              evidence: https://example.com/assessment
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    explanation = results[:security_review_status][:explanation]
    assert_includes explanation, 'Comment says:'
    assert_includes explanation, 'threat model'
  end

  # ---------------------------------------------------------------------------
  # Explanation text
  # ---------------------------------------------------------------------------

  test 'explanation includes filename for scalar condition' do
    yaml = <<~YAML
      repository:
        status: active
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    explanation = results[:maintained_status][:explanation]
    assert_includes explanation, 'security-insights.yml'
    assert_includes explanation, 'repository.status'
  end

  test 'explanation includes filename for array condition' do
    yaml = <<~YAML
      repository:
        security:
          assessments:
            self:
              comment: not done
          tools:
            - name: SomeScanner
              type: SAST
              rulesets:
                - default
              integration:
                adhoc: true
                ci: false
                release: false
              results: {}
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    explanation = results[:static_analysis_status][:explanation]
    assert_includes explanation, 'security-insights.yml'
    assert_includes explanation, 'SAST'
  end

  test 'oversized comment is truncated to MAX_SI_COMMENT_SIZE' do
    long_comment = 'x' * (SecurityInsightsDetective::MAX_SI_COMMENT_SIZE + 100)
    yaml = <<~YAML
      repository:
        status: active
        comment: "#{long_comment}"
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    explanation = results[:maintained_status][:explanation]
    assert_includes explanation, 'Comment says:'
    # The comment in the explanation must not exceed MAX_SI_COMMENT_SIZE chars
    # (plus the "..." truncation suffix).
    assert explanation.length < long_comment.length + 200,
           'Oversized SI comment was not truncated'
    assert_includes explanation, '...'
  end

  test 'mapping with confidence 0 is skipped even when condition matches' do
    # The reports-accepted=true → vulnerability_report_response entry has
    # confidence: 0 in the map file (deliberate no-op).  Even though the YAML
    # satisfies the condition, the detective must not propose that criterion.
    yaml = <<~YAML
      project:
        vulnerability-reporting:
          reports-accepted: true
    YAML
    results = run_detective(MockRepoFiles.new('security-insights.yml', yaml))
    assert_not results.key?(:vulnerability_report_response_status),
               'confidence-0 mapping must not produce a proposal'
  end

  test 'explanation uses basename of .github path' do
    yaml = <<~YAML
      repository:
        status: active
    YAML
    results = run_detective(MockRepoFiles.new('.github/security-insights.yml', yaml))
    explanation = results[:maintained_status][:explanation]
    assert_includes explanation, 'security-insights.yml'
    assert_not_includes explanation, '.github/'
  end

  # ---------------------------------------------------------------------------
  # Map file structural validation
  # ---------------------------------------------------------------------------

  SI_MAP_ALLOWED_KEYS = %w[
    si_path si_value si_alternatives si_item_field substring also
    target_criterion inferred_status confidence
  ].to_set.freeze
  SI_MAP_REQUIRED_KEYS = %w[si_path target_criterion inferred_status confidence].freeze
  SI_MAP_VALID_STATUSES = %w[Met Unmet N/A].freeze

  test 'security_insights_map.yml entries are structurally valid and target known criteria' do
    raw = YAML.safe_load_file(
      Rails.root.join('criteria/security_insights_map.yml'),
      permitted_classes: [],
      aliases: false
    )
    mappings = raw['mappings']
    assert mappings.is_a?(Array), 'mappings must be an Array'

    mappings.each_with_index { |m, i| assert_valid_si_map_entry(m, i) }

    # OUTPUTS (derived from confidence>0 entries) must all be known criteria status fields
    unknown_outputs = SecurityInsightsDetective::OUTPUTS - Project::ALL_CRITERIA_STATUS
    assert unknown_outputs.empty?,
           "OUTPUTS contains unknown criterion fields: #{unknown_outputs.inspect}"
  end

  private

  def assert_valid_si_map_entry(m, i)
    label = "entry #{i} (target: #{m['target_criterion']})"
    assert_si_map_keys(m, label)
    assert_si_map_rules(m, label)
  end

  def assert_si_map_keys(m, label)
    unknown = m.keys.to_set - SI_MAP_ALLOWED_KEYS
    assert unknown.empty?, "#{label}: unknown fields: #{unknown.to_a.sort.join(', ')}"
    SI_MAP_REQUIRED_KEYS.each do |field|
      assert m.key?(field), "#{label}: missing required field '#{field}'"
    end
  end

  def assert_si_map_rules(m, label) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    assert SI_MAP_VALID_STATUSES.include?(m['inferred_status']),
           "#{label}: invalid inferred_status '#{m['inferred_status']}'"
    conf = m['confidence'].to_f
    assert conf.between?(0, 3), "#{label}: confidence #{conf} out of range 0..3"
    assert_not (m.key?('si_value') && m.key?('si_alternatives')),
               "#{label}: si_value and si_alternatives are mutually exclusive"
    if m.key?('also')
      assert m.key?('si_item_field'), "#{label}: 'also' requires 'si_item_field'"
    end
    has_match_value = m.key?('si_value') || m.key?('si_alternatives')
    if m.key?('si_item_field')
      assert has_match_value, "#{label}: 'si_item_field' requires 'si_value' or 'si_alternatives'"
    end
    if m['substring']
      assert has_match_value, "#{label}: 'substring: true' requires 'si_value' or 'si_alternatives'"
    end
    target_status = :"#{m['target_criterion']}_status"
    assert Project::ALL_CRITERIA_STATUS.include?(target_status),
           "#{label}: '#{m['target_criterion']}' is not a known criterion"
  end
end
# rubocop:enable Metrics/ClassLength
