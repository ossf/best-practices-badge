# frozen_string_literal: true

# Copyright the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require_relative '../../lib/fingerprinted_asset_cache_middleware'

# Wrap the static file server so we see (and can adjust) its responses.
Rails.application.config.middleware.insert_before(
  ActionDispatch::Static, FingerprintedAssetCacheMiddleware
)
