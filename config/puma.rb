# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Puma can serve each request in a thread from an internal thread pool.
# The `threads` method setting takes two numbers a minimum and maximum.
# Any libraries that use thread pools should be configured to match
# the maximum value specified for Puma. Default is set to 5 threads for minimum
# and maximum, this matches the default thread size of Active Record.
#
threads_count = ENV.fetch('RAILS_MAX_THREADS') { 5 }
                   .to_i
threads threads_count, threads_count

# Specifies the `port` that Puma will listen on to receive requests, default is
# 3000.
#
port        ENV.fetch('PORT') { 3000 }

# Specifies the `environment` that Puma will run in.
#
environment ENV.fetch('RAILS_ENV') { 'development' }

# Specifies the number of `workers` to boot in clustered mode.
# Workers are forked webserver processes. If using threads and workers together
# the concurrency of the application would be max `threads` * `workers`.
# Workers do not work on JRuby or Windows (both of which do not support
# processes).
#
# workers ENV.fetch("WEB_CONCURRENCY") { 2 }

# Use the `preload_app!` method when specifying a `workers` number.
# This directive tells Puma to first boot the application and load code
# before forking the application. This takes advantage of Copy On Write
# process behavior so workers use less memory. If you use this option
# you need to make sure to reconnect any threads in the `on_worker_boot`
# block.
#
# preload_app!

# The code in the `before_worker_boot` will be called if you are using
# clustered mode by specifying a number of `workers`. After each worker
# process is booted this block will be run, if you are using `preload_app!`
# option you will want to use this block to reconnect to any threads
# or connections that may have been created at application boot, Ruby
# cannot share connections between processes.
# Note: In Puma 7+, the hook was renamed from `on_worker_boot` to
# `before_worker_boot`.
#
# before_worker_boot do
#   ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
# end

# After the web server boots a new release, refresh the shared CDN cache of
# "unchanging" pages (home, cookies, criteria pages) so a deploy's
# content/translation changes become visible. after_booted fires once, only in
# the server process -- not in `rails console`, rake tasks, or tests -- so no
# guard is needed. (Puma 7 deprecated the older on_booted name.)
# See docs/cdn-cache-not-logged-in.md Section 10.
after_booted do
  if ApplicationController::CACHE_UNCHANGING_PAGES
    key = ApplicationController::UNCHANGING_SURROGATE_KEY
    # Immediate purge. purge_by_key catches its own errors and returns false
    # (never raises), and is a no-op without Fastly credentials, so a Fastly
    # hiccup (or a non-production boot) cannot break startup.
    FastlyRails.purge_by_key(key)
    # Delayed re-purge closes the rolling-deploy race: an old, still-draining
    # process can repopulate the cache just after the immediate purge. This is
    # the same recovery path PurgeCdnProjectJob provides for project edits.
    PurgeCdnProjectJob
      .set(wait: ApplicationController::BADGE_PURGE_DELAY.seconds)
      .perform_later(key)
  end
end

# Allow puma to be restarted by `rails restart` command.
plugin :tmp_restart

# Use solid_queue as the ActiveJob backend. This stores jobs in a database,
# so scheduled jobs will happen even if the system crashes.
# Set the environment variable if you want it activated (e.g., in production)
plugin :solid_queue if ENV['SOLID_QUEUE_IN_PUMA'] # || Rails.env.development?
