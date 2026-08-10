# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Check for stale precompiled assets on first web request
# This helps catch cases where precompilation didn't run (e.g., on Heroku)
# By checking on first request instead of at startup, we avoid interfering
# with rake tasks like assets:precompile
# In development/test, raises on stale assets. In production, just warns.

require_relative '../../lib/asset_staleness_middleware'

# Add middleware to check assets on first request in all environments
Rails.application.config.middleware.use AssetStalenessMiddleware
