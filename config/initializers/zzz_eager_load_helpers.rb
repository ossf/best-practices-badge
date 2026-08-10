# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Eager initialization of expensive helper computations
#
# WHY THIS IS NEEDED:
# Some helpers compute expensive data structures by calling I18n.t() for all
# available locales. These must be lazy-loaded (not constants) to avoid
# initialization order problems - constants are computed at class load time,
# but I18n isn't fully configured until initializers run.
#
# However, lazy memoization using ||= is not thread-safe. With Puma's thread
# pool (default 5 threads), multiple threads could compute the value
# simultaneously during the first request.
#
# SOLUTION:
# Eagerly trigger these lazy computations during app boot when we're still
# single-threaded. Rails runs initializers in order, then starts the web
# server. By calling the helper methods here in after_initialize:
#   1. I18n is fully configured (all initializers have run)
#   2. We're still single-threaded (Puma hasn't started its thread pool yet)
#   3. First request will hit the already-computed memoized value
#   4. No race conditions, no mutex overhead, simple code
#
# This initializer is named with 'zz_' prefix to ensure it runs last,
# after all other initializers including I18n setup.

Rails.application.config.after_initialize do
  # Trigger computation of navigation sections dropdown data
  # (See ApplicationHelper.project_nav_sections)
  ApplicationHelper.project_nav_sections
end
