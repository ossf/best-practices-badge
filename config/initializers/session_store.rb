# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Be sure to restart your server when you modify this file.

# FORCING A GLOBAL LOGOUT (invalidating all active sessions at once):
# See docs/secrets-policy.md for the full rotation procedure.
#
# Option 1 — rotate SECRET_KEY_BASE (preferred): change the env var and redeploy.
# Option 2 — rename the cookie key below (e.g. '_BadgeApp_session_v2'): deploy;
#   old cookies are ignored, all users are silently logged out.

Rails.application.config.session_store :cookie_store, key: '_BadgeApp_session'
