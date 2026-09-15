# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Retry the first database connection at boot, before Rails' own
# eager loading (config.eager_load, production-only) forces one by
# loading a model with a class-level query, such as Project's default
# scope. The module implementation is in lib/database_boot_retry.rb.
#
# Guarded to production only, with no exemption for asset
# precompilation: eager loading already requires a working database
# connection on any production-flagged boot regardless of this file
# (see lib/database_url_guard.rb's docstring for why), so there is
# nothing to skip here that eager loading would not already need
# anyway. This never tries to reach a database in local development or
# the test suite, since neither runs with Rails.env.production?.
DatabaseBootRetry.connect_with_retry if Rails.env.production?
