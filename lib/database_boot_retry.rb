# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Retries the first real database connection a few times with a short
# pause between attempts, absorbing a brief platform-side hiccup instead
# of crashing the whole process on it.
#
# WHY THIS EXISTS. On 2026-09-15, a Heroku release-phase dyno and,
# separately, the first web dyno to boot that same release both crashed
# because DATABASE_URL was unavailable to the process for a few seconds
# at boot (root cause on Heroku's side; never reproduced outside their
# platform, and confirmed not caused by
# config/initializers/redact_database_url.rb, which was suspected first
# and tested directly). Both crashes happened the first time something
# forced a real connection: db:migrate's schema check, and, on the web
# dyno, Project's class-level default scope during eager loading.
# Retrying absorbs exactly that kind of transient window instead of
# taking the whole dyno down on the first attempt.
#
# ERRORS RESCUED. PG::ConnectionBad is what the pg gem raises directly;
# ActiveRecord::ConnectionNotEstablished is how Active Record wraps it in
# some call paths. Both forms showed up in the 2026-09-15 crash logs,
# depending on exactly which code triggered the first connection.
# Anything else is a real failure, not a transient one, and is not
# rescued here: it raises immediately rather than spending the retry
# budget on it.
module DatabaseBootRetry
  MAX_ATTEMPTS = 3
  RETRY_DELAY_SECONDS = 2

  RESCUED_ERRORS = [
    PG::ConnectionBad, ActiveRecord::ConnectionNotEstablished
  ].freeze

  module_function

  # @param max_attempts [Integer] total attempts before giving up
  # @param delay [Numeric] seconds to sleep between attempts
  # @return [Boolean] true once a connection succeeds
  # @raise [PG::ConnectionBad, ActiveRecord::ConnectionNotEstablished] the
  #   last error, if every attempt fails
  def connect_with_retry(
    max_attempts: MAX_ATTEMPTS,
    delay: RETRY_DELAY_SECONDS
  )
    attempts = 0
    begin
      attempts += 1
      ping
      true
    rescue *RESCUED_ERRORS => e
      raise if attempts >= max_attempts

      warn "DatabaseBootRetry: attempt #{attempts}/#{max_attempts} " \
           "failed (#{e.class}); retrying in #{delay}s"
      sleep delay
      retry
    end
  end

  # Seam for tests: the only place that touches the database.
  def ping
    ActiveRecord::Base.connection.execute('SELECT 1')
  end
end
