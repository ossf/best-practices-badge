# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Baseline Detective - Reserved for baseline-specific automated checks that
# don't have equivalents in the metal series. Currently all baseline
# automation is handled by extending existing detectives
# (FlossLicenseDetective, RepoFilesExamineDetective,
# GithubBasicDetective, ProjectSitesHttpsDetective) to output both metal
# and baseline fields from a single analysis.
#
# Metal→baseline criterion translation is handled by MetalToBaselineDetective
# (a MappingDetective subclass), which reads criteria/metal_to_baseline_map.yml.
#
# This detective is kept as a placeholder for future baseline-unique checks.
class BaselineDetective < Detective
  INPUTS = [].freeze
  OUTPUTS = [].freeze
  OVERRIDABLE_OUTPUTS = [].freeze

  def analyze(_evidence, _current)
    {}
  end
end
