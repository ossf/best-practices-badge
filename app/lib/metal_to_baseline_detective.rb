# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# MetalToBaselineDetective - Translates metal (passing/silver/gold) criterion
# answers to OSPS Baseline criterion proposals, using the mapping defined in
# criteria/metal_to_baseline_map.yml.
#
# This detective is run explicitly late by Chief (after the normal topological-
# sort pipeline) so it benefits from all accumulated proposals — including
# auto-detected metal values from other detectives such as FlossLicenseDetective,
# RepoFilesExamineDetective, and SubdirFileContentsDetective.
#
# Chief ensures exactly one MappingDetective subclass runs per pipeline
# (see Chief#partition_mapping_detective), preventing circularity with a
# future BaselineToMetalDetective.
class MetalToBaselineDetective < MappingDetective
  MAPPINGS = load_mappings('criteria/metal_to_baseline_map.yml').freeze
  INPUTS   = MAPPINGS.map { |m| :"#{m['source_criterion']}_status" }.uniq.freeze
  OUTPUTS  = MAPPINGS.map { |m| :"#{m['target_criterion']}_status" }.uniq.freeze
  OVERRIDABLE_OUTPUTS = [].freeze
end
