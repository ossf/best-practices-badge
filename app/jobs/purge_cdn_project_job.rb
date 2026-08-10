# frozen_string_literal: true

# Copyright the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

class PurgeCdnProjectJob < ApplicationJob
  # Raised when a CDN purge API call fails, triggering ActiveJob retry.
  class PurgeFailedError < StandardError; end

  queue_as :default

  # Retry with polynomial backoff on purge failure. After the synchronous
  # pre/post-save purges, this delayed job is the recovery path for race
  # condition re-caches; retrying handles transient Fastly API outages.
  retry_on PurgeFailedError, wait: :polynomially_longer, attempts: 5

  # Rails supports passing the project record directly as "project".
  # However, this is inefficient; we really only need the record_key
  # (which we use as the cdn_badge_key).
  def perform(cdn_badge_key)
    # Send purge message to CDN
    success = FastlyRails.purge_by_key(cdn_badge_key)
    raise PurgeFailedError, "CDN purge failed for key #{cdn_badge_key}" unless success
  end
end
