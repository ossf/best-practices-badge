# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Fails fast, with an unambiguous message, if a real boot happens in
# production with no DATABASE_URL at all.
#
# WHY THIS EXISTS. On 2026-09-15 a Heroku release-phase dyno and a fresh
# web dyno both crashed because DATABASE_URL was unavailable for a few
# seconds at boot. The error that actually reached the log was
# ActiveRecord::ConnectionNotEstablished, several stack frames deep
# inside a migration or an eager-loaded model's default scope, saying
# nothing about DATABASE_URL itself; diagnosing that took hours of log
# archaeology across two different crash sites. Checking for the missing
# variable directly, before anything else touches it, turns any repeat
# into an immediate, specific error instead.
#
# NO EXEMPTION FOR ASSET PRECOMPILATION. It might seem like precompiling
# assets shouldn't need a database at all, and functionally it doesn't;
# but sprockets-rails defines "assets:precompile" as depending on the
# standard "environment" task (see Sprockets::Rails::Task#define), which
# runs a full Rails.application.initialize!, including eager loading in
# production. This app's Project model has a class-level default scope
# (app/models/project.rb) that queries the schema the moment the class
# loads, so eager loading alone already requires a working database
# connection on any production-flagged boot, precompiling assets
# included, independently of this file. Since this app has deployed to
# Heroku successfully for a long time, that means Heroku's build phase
# already has DATABASE_URL available; there is no real scenario here
# to exempt.
module DatabaseUrlGuard
  # Raised when a real boot has no DATABASE_URL at all.
  class MissingDatabaseUrl < StandardError; end

  module_function

  # @param database_url [String, nil] typically ENV['DATABASE_URL']
  # @raise [MissingDatabaseUrl] if a real boot has no DATABASE_URL
  def check!(database_url:)
    return if database_url

    raise MissingDatabaseUrl,
          'FATAL: DATABASE_URL is not set (RAILS_ENV=production). ' \
          'Refusing to boot rather than fail later with a confusing ' \
          'connection error.'
  end
end
