# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Cookie rotations allow existing sessions to remain valid after we change
# cookie encryption settings via config.load_defaults. Without these, every
# load_defaults step that changes cipher or key derivation would log out all
# users. Instead, Rails tries the new settings first, then falls back to each
# rotation in order, re-encrypting with the new settings on the next write.
#
# These rotations cover the transition from pre-load_defaults state to 7.0:
#   Old: AES-256-CBC cipher + SHA1 key generator
#   New (at 7.0): AES-256-GCM cipher + SHA256 key generator
#
# ROUTINE CLEANUP: Delete this file a few days after the load_defaults
# deployment (commit d17bdb84). The session TTL is 48 hours, so by then
# every active session will have been transparently re-encrypted in the new
# format on the user's first post-deployment visit. The tiny minority of
# cookies still in the old format will belong to sessions that are already
# server-side expired, so deleting this file causes no forced logouts.
# See config/initializers/session_store.rb for how to force a global logout
# if that is ever needed instead.
Rails.application.config.action_dispatch.cookies_rotations.tap do |cookies|
  cookies.rotate :encrypted, cipher: 'aes-256-cbc', digest: 'SHA1'
  cookies.rotate :signed,    digest: 'SHA1'
end
