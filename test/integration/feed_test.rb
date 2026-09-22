# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'
load 'Rakefile'

class FeedTest < ActionDispatch::IntegrationTest
  # Historically we did a lot of special cases to hide time changes.
  # But these are really invasive and fragile, so I've commented them out.
  # The current tests simply check for data that should be there, and
  # ignoring times. It's just loading from a fixture file, so a more
  # sophisticated test isn't really justified.

  # Turn off transactional fixtures for this test since we are loading
  # the fixtures database anyway. This will prevent the timestamp change
  # from spilling into other tests.
  # self.use_transactional_tests = false

  # setup do
  #   Ensure the test db has its environment metadata set to test,
  #   otherwise tasks farther down will fail.  New for Rails 5
  #   Rake::Task['db:environment:set'].invoke
  #   Normalize time in order to match fixture file
  #   travel_to Time.zone.parse('2015-03-01T12:00:00') do
  #     ActiveRecord::Schema.verbose = false
  #     Rake::Task['db:schema:load'].reenable
  #     Rake::Task['db:schema:load'].invoke
  #     Rake::Task['db:fixtures:load'].reenable
  #     Rake::Task['db:fixtures:load'].invoke
  #   end
  # end

  test 'feed matches fixture file' do
    get feed_path(locale: :en)
    # See test/fixtures/files/feed.atom for a sample
    assert response.body.start_with?('<?xml version="1.0" encoding="UTF-8"?>')
    assert response.body.include?(
      '<title>OpenSSF Best Practices BadgeApp Updated Projects</title>'
    )
    assert response.body.include?(
      '<title>Another Ascent Vehicle (AAV)</title>'
    )
    # Attempt to parse it as XML to verify if it's well-formed.
    # It might not be valid XML, but we'd need a schema definition to check.
    # Disable Rubocop check - rubocop is very confused by this.
    # rubocop:disable-next Style/SymbolProc
    _result = Nokogiri::XML(response.body) { |config| config.strict }
  end
end
