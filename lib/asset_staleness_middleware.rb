# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require_relative 'asset_staleness_checker'

# Rack middleware that checks for stale precompiled assets on first request
# This avoids interfering with rake tasks while still catching stale assets
class AssetStalenessMiddleware
  def initialize(app)
    @app = app
    @checked = false
  end

  def call(env)
    # Only check once per server lifetime
    unless @checked
      @checked = true
      check_assets
    end

    @app.call(env)
  end

  private

  def check_assets
    checker = AssetStalenessChecker.from_rails_config(Rails.application)
    checker&.check_and_warn(env: Rails.env)
  rescue StandardError => e
    # Re-raise in development and test to fail fast
    raise if Rails.env.local?

    # In production, just log the error
    Rails.logger.error("Asset staleness check failed: #{e.message}")
  end
end
