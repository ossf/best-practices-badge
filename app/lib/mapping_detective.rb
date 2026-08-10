# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# MappingDetective - Abstract base class for criterion-mapping detectives.
# Subclasses translate answers from one set of criteria (source) to proposed
# answers for another set (target) using a YAML-defined confidence map.
#
# Subclasses must define:
#   MAPPINGS - Array of mapping hashes loaded from a YAML file via load_mappings
#   INPUTS   - Source criterion _status fields (derived from MAPPINGS)
#   OUTPUTS  - Target criterion _status fields (derived from MAPPINGS)
#
# MappingDetective subclasses are treated specially by Chief: they are
# partitioned out of the normal detective pool (see Chief#partition_mapping_detective)
# and exactly one is selected and run explicitly late, after all other detectives,
# via Chief#propose_mapping_change (not the standard propose_one_change), so it
# receives the fully-accumulated current_proposal for confidence scaling and
# explanation text.
class MappingDetective < Detective
  INPUTS = [].freeze
  OUTPUTS = [].freeze
  OVERRIDABLE_OUTPUTS = [].freeze
  MAPPINGS = [].freeze

  # Load a YAML mapping file and return the 'mappings' array.
  # Called at class definition time in subclasses.
  # @param file [String] path relative to Rails.root
  # @return [Array<Hash>] array of mapping hashes
  def self.load_mappings(file)
    YAML.safe_load_file(
      Rails.root.join(file),
      permitted_classes: [],
      aliases: true
    )['mappings']
  end

  # Translate source criterion answers to target criterion proposals.
  #
  # Source values come from two possible origins:
  #   (1) The project's own badge data (user-entered). Detected by checking
  #       whether the project has a real, non-UNKNOWN value for the source field.
  #       In this case the YAML confidence is used as-is, and any justification
  #       text the user wrote for the source criterion is carried forward.
  #   (2) A proposal from a prior detective (auto-detected value). Detected when
  #       the project value is blank/UNKNOWN but source_proposals contains an
  #       entry for the field.
  #       In this case the confidence is scaled:
  #         scaled = source_conf * yaml_conf / Chief::MAX_CONFIDENCE
  #       If scaled < 0.5 the result is treated as confidence 0 and dropped.
  #       Otherwise the fractional value is kept and the prior detective's
  #       explanation text is carried forward (with the source criterion name
  #       appended in brackets).
  #
  # Chief calls this via propose_mapping_change, which passes the full
  # current_proposal as source_proposals so origin and confidence are available.
  #
  # @param evidence [Evidence] project evidence wrapper; used for justification
  # @param current [Hash] current best status values for INPUTS fields
  # @param source_proposals [Hash] full current_proposal from Chief (may be empty)
  # @return [Hash] proposed target criterion _status values
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def analyze(evidence, current, source_proposals = {})
    return {} if evidence.nil?

    project = evidence.project
    results = {}

    self.class::MAPPINGS.each do |mapping|
      source_criterion = mapping['source_criterion']
      target_criterion = mapping['target_criterion']
      source_field     = :"#{source_criterion}_status"

      source_status = current[source_field]
      yaml_conf, target_status = resolve_confidence(mapping, source_status)
      next if yaml_conf.zero?

      from_project = project_has_value?(project, source_field)
      proposal     = source_proposals[source_field]
      confidence, explanation =
        if from_project || proposal.nil?
          # Case 1: value is from the project's own badge data (user-entered),
          # OR no proposal metadata is available.  The latter is unreachable in
          # production (compute_current only surfaces a value when it came from
          # the project or a prior proposal), but occurs in tests that pass
          # `current` directly without source_proposals.  Use YAML confidence.
          [yaml_conf, build_explanation(project, source_criterion)]
        else
          # Case 2: value came from a prior detective proposal.  Scale confidence
          # and carry the prior detective's explanation forward.
          scaled = scale_confidence(proposal[:confidence], yaml_conf)
          next if scaled.zero?

          [scaled, build_proposal_explanation(proposal, source_criterion)]
        end

      target_field = :"#{target_criterion}_status"
      next if results.key?(target_field) &&
              confidence <= results[target_field][:confidence]

      results[target_field] = {
        value: target_status,
        confidence: confidence,
        explanation: explanation
      }
    end

    results
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  private

  # Determine inference confidence and target status from a mapping entry
  # and the source criterion's current status.
  #
  # Each confidence field in the YAML is either:
  #   - An integer (0-3): same-status inference (target gets same status as source)
  #   - A [confidence, "StatusName"] array: cross-status inference
  #
  # @param mapping [Hash] a single mapping entry from the YAML
  # @param source_status [Integer, nil] source criterion status integer
  # @return [Array(Integer, Integer)] [yaml_confidence (0-3), target_status integer]
  #   confidence 0 means "no inference; skip this entry"
  # rubocop:disable Metrics/MethodLength
  def resolve_confidence(mapping, source_status)
    conf_key =
      case source_status
      when CriterionStatus::MET   then 'confidence_met'
      when CriterionStatus::UNMET then 'confidence_unmet'
      when CriterionStatus::NA    then 'confidence_na'
      else return [0, nil]
      end

    spec = mapping[conf_key]
    return [0, nil] if spec.nil?

    if spec.is_a?(Array)
      confidence = spec.first
      target_status = CriterionStatus.parse(spec[1])
    else
      confidence = spec
      target_status = source_status
    end
    return [0, nil] if confidence.zero?

    [confidence, target_status]
  end
  # rubocop:enable Metrics/MethodLength

  # Scale a YAML confidence value by a prior detective's source confidence.
  # Returns the fractional product if >= 0.5, or 0 (meaning "drop this result").
  #
  # Formula: source_conf * yaml_conf / Chief::MAX_CONFIDENCE
  #
  # @param source_conf [Numeric, nil] confidence of the prior detective's proposal
  # @param yaml_conf [Integer] raw YAML confidence for this mapping (1-3)
  # @return [Numeric] scaled confidence (>= 0.5) or 0
  def scale_confidence(source_conf, yaml_conf)
    return 0 if source_conf.nil? || source_conf.zero?

    scaled = source_conf * yaml_conf.to_f / Chief::MAX_CONFIDENCE
    scaled < 0.5 ? 0 : scaled
  end

  # True if the project has a real, non-UNKNOWN, non-blank value for +field+.
  # Guards against partial SELECT (has_attribute? returns false when a column
  # was not loaded) and test stubs (which may not implement has_attribute?).
  #
  # @param project [Project] the ActiveRecord project (or test stub)
  # @param field [Symbol] the _status field to check
  # @return [Boolean]
  def project_has_value?(project, field)
    if project.respond_to?(:has_attribute?) && !project.has_attribute?(field)
      return false
    end
    return false unless project.respond_to?(:attribute_present?) &&
                        project.attribute_present?(field)

    v = project[field]
    v.present? && v != CriterionStatus::UNKNOWN
  rescue ActiveModel::MissingAttributeError
    false
  end

  # Build the explanation string when the source value came from the project's
  # own badge data (user-entered). Carries over any justification text the user
  # wrote for the source criterion, appending the source name in brackets.
  #
  # Uses has_attribute? to guard against partial SELECT queries.
  #
  # @param project [Project] the ActiveRecord project
  # @param source_criterion [String] source criterion name
  # @return [String] explanation text
  def build_explanation(project, source_criterion)
    justification_key = :"#{source_criterion}_justification"
    existing =
      if project.respond_to?(:has_attribute?) && !project.has_attribute?(justification_key)
        ''
      else
        project[justification_key].to_s.strip
      end
    existing.empty? ? "[#{source_criterion}]" : "#{existing} [#{source_criterion}]"
  end

  # Build the explanation string when the source value came from a prior
  # detective's proposal. Carries the prior detective's explanation text
  # forward, appending the source criterion name in brackets.
  #
  # @param proposal [Hash, nil] prior detective proposal ({value:, confidence:, explanation:})
  # @param source_criterion [String] source criterion name
  # @return [String] explanation text
  def build_proposal_explanation(proposal, source_criterion)
    prior = proposal&.dig(:explanation).to_s.strip
    prior.empty? ? "[#{source_criterion}]" : "#{prior} [#{source_criterion}]"
  end
end
