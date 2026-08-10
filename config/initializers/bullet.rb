# frozen_string_literal: true

# Copyright the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Configure the Bullet gem to detect N+1 queries and unused eager loading.
# Bullet is only loaded in development and test (see Gemfile).
# Previously this was duplicated in development.rb and test.rb.
if defined?(Bullet)
  Rails.application.config.after_initialize do
    Bullet.enable = true
    Bullet.rails_logger = true
    Bullet.add_footer = true
    Bullet.raise = true if Rails.env.test?
  end
end
