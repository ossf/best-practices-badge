# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Remove DATABASE_URL from the process environment once Active Record
# has already resolved it into a cached connection config. Rails reads
# config/database.yml (merging in DATABASE_URL automatically) in an
# Active Record initializer that always runs before any file in
# config/initializers, and every later reconnect in this process
# reuses that cached config, not ENV again. So nothing downstream
# needs the raw value, here or in a "heroku run" migration/console
# process, each of which resolves and caches its own config the same
# way before this file loads. Confirmed empirically, not just by
# reading Rails' source: a 2026-09-15 incident raised this exact
# question, and a fresh connection pool built from the cached config
# AFTER deleting ENV['DATABASE_URL'] still used the original resolved
# host. This file was not the cause of that incident; see
# lib/database_url_guard.rb below for the fail-fast check the same
# incident did motivate.
#
# This eliminates a specific leak vector: a bug that dumps ENV (a debug
# or error page showing ENV.inspect, say) can no longer reveal this
# vital key. It does *not* protect against an attacker with actual code
# execution: Linux's /proc/self/environ reflects the environment as of
# execve(), not later in-process setenv/unsetenv calls, so the value
# stays readable there regardless. It also does nothing against
# `heroku config:get DATABASE_URL` or any log/backup capture taken at
# boot time, since those read Heroku's own config-var store or the
# value as it existed at startup, not this process's current memory.
# See docs/login-session-18.md's "Honest limits, restated" for the
# full reasoning. This is cheap defense in depth, not something that
# fully closes the DATABASE_URL gap discussed there (we take other
# steps to better address it).
#
# Guarded to production, which covers both the staging and production
# Heroku apps (see docs/secrets-policy.md's BADGEAPP_REAL_PRODUCTION
# entry for how those two are told apart), so development and test
# consoles keep DATABASE_URL visible for debugging. Neither sets it
# anyway, so the guard changes no behavior there beyond stating intent.
#
if Rails.env.production?
  # require IS NEEDED before referencing DatabaseUrlGuard: Zeitwerk's
  # main autoloader is only set up in Rails' Finisher, which runs after
  # all of config/initializers, so a bare reference here raises
  # "uninitialized constant DatabaseUrlGuard" instead of autoloading.
  require 'database_url_guard'
  DatabaseUrlGuard.check!(database_url: ENV.fetch('DATABASE_URL', nil))
  ENV.delete('DATABASE_URL')
end
