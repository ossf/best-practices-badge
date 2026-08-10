# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# BaselineToMetalDetective - Translates OSPS Baseline criterion answers
# to metal (passing/silver/gold) criterion proposals, using the mapping
# defined in criteria/baseline_to_metal_map.yml.
#
# This detective is run explicitly late by Chief (after the normal topological-
# sort pipeline) so it benefits from all accumulated proposals — including
# auto-detected baseline values from other detectives.
#
# Chief ensures exactly one MappingDetective subclass runs per pipeline
# (see Chief#partition_mapping_detective), preventing circularity with
# MetalToBaselineDetective.
class BaselineToMetalDetective < MappingDetective
  MAPPINGS = load_mappings('criteria/baseline_to_metal_map.yml').freeze
  INPUTS   = MAPPINGS.map { |m| :"#{m['source_criterion']}_status" }.uniq.freeze
  OUTPUTS  = MAPPINGS.map { |m| :"#{m['target_criterion']}_status" }.uniq.freeze
  OVERRIDABLE_OUTPUTS = [].freeze
end
