# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

Octokit.configure do |c|
  if Rails.env.test?
    # Test app OAuth returns to a different port
    ENV['GITHUB_KEY'] = ENV.fetch('TEST_GITHUB_KEY', nil)
    ENV['GITHUB_SECRET'] = ENV.fetch('TEST_GITHUB_SECRET', nil)
  end
  c.client_id = ENV.fetch('GITHUB_KEY', nil)
  c.client_secret = ENV.fetch('GITHUB_SECRET', nil)
  c.auto_paginate = true
  c.user_agent = USER_AGENT
end
Octokit.default_media_type = 'application/vnd.github.v3+json'
