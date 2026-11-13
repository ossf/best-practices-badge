# frozen_string_literal: true

# Copyright the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# Badge images of every series get the faster badge rate limit; everything
# else (including badge JSON) gets the slower non-badge limit.
class RackAttackInitializerTest < ActiveSupport::TestCase
  # BADGE_REGEX_PATH is built from these suffixes, so a strange one
  # (e.g., '' would match "/projects/1/") could widen the faster limit.
  test 'every badge URL suffix is a plain lowercase word' do
    Sections::BADGE_URL_SUFFIX.each_value do |suffix|
      assert_match(/\A[a-z]+\z/, suffix)
    end
  end

  test 'badge image paths of every series match BADGE_REGEX_PATH' do
    Sections::BADGE_URL_SUFFIX.each_value do |suffix|
      assert_match Rack::Attack::BADGE_REGEX_PATH, "/projects/1/#{suffix}"
      assert_match Rack::Attack::BADGE_REGEX_PATH, "/projects/90/#{suffix}"
    end
  end

  test 'other paths do not match BADGE_REGEX_PATH' do
    [
      '/projects/1/badge.json',
      '/projects/1/baseline.json',
      '/projects/0/badge',
      '/projects/1/badges',
      '/projects/1/baseline-1',
      '/projects/1/passing',
      '/en/projects/1/badge',
      "/projects/1/badge\n/x"
    ].each do |path|
      assert_no_match Rack::Attack::BADGE_REGEX_PATH, path
    end
  end
end
