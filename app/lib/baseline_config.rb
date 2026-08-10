# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Central configuration for the OpenSSF Baseline criteria version.
# Edit the constants below when upgrading the baseline criteria version.
#
# After changing CURRENT_VERSION, re-run script/generate_baseline_badges.rb
# to regenerate the badge images with the updated version text.
#
module BaselineConfig
  # CURRENT_VERSION:  The version whose criteria are currently shown.
  # Also appears in badge text: "openssf baseline CURRENT_VERSION".
  # Note that it begins with 'v' and uses '.' not '-'
  CURRENT_VERSION = 'v2026.02.19'

  # IN_TRANSITION:    Set to true during a version transition period.
  IN_TRANSITION = false

  # NEW_VERSION: (during transition only) The new version being adopted.
  NEW_VERSION = '' # used only during transition

  # ENFORCE_DATE: (during transition only) Date new criteria are enforced
  ENFORCE_DATE = '' # used only during transition, YYYY-MM-DD
end
