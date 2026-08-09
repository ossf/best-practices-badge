# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# NO require_relative HERE, DELIBERATELY. lib/ is an autoload path (see
# config/application.rb), so naming the constant loads the file inside
# the worker process running these tests. Requiring it at the top loads
# it once in the PARENT instead, before Rails forks its test workers,
# and the parent's result is named "job-manual", which the later serial
# system-test run overwrites. The file's load-time lines, its requires,
# constants and def headers, then look untested: every method body is
# exercised and "rake test:optimized" still fails on coverage.

# Every probe is stubbed: the suite is hermetic on purpose, and a test
# that reached S3 would fail on a train and pass or fail for reasons
# unrelated to this code.
#
# Grouped into few tests, each a table, because they were the same six
# lines with different numbers and each test block costs a startup. The
# ROW LABELS are the documentation, and a failure names its row.
# rubocop:disable Metrics/ClassLength
class HerokuRubyAvailabilityTest < ActiveSupport::TestCase
  STACK = 'heroku-24'

  # Publish exactly these; everything else answers 403, which is what S3
  # really sends for an object you may not list. Resets first, so one
  # row cannot inherit the stubs of the row before.
  def publish(*versions)
    WebMock.reset!
    stub_request(:head, /heroku-buildpack-ruby.*\.tgz/).to_return(status: 403)
    versions.each do |version|
      stub_request(
        :head, HerokuRubyAvailability.url_for(version: version, stack: STACK)
      ).to_return(status: 200)
    end
  end

  # A real release line is contiguous, which is what lets the window
  # slide from 3.4.1 to 3.4.10.
  def line(prefix, range)
    range.map { |patch| "#{prefix}.#{patch}" }
  end

  test 'pure helpers: the URL, parsing, and which lines we consider' do
    assert_equal(
      'https://heroku-buildpack-ruby.s3.us-east-1.amazonaws.com/' \
      'heroku-24/amd64/ruby-3.4.10.tgz',
      HerokuRubyAvailability.url_for(version: '3.4.10', stack: STACK)
    )
    assert_equal(
      ['3.4', '3.5', '3.6', '4.0'],
      HerokuRubyAvailability.candidate_lines(3, 4)
    )
    assert_equal [3, 4, 10], HerokuRubyAvailability.parse('3.4.10')
    # A version file has a trailing newline.
    assert_equal [3, 4, 1], HerokuRubyAvailability.parse("3.4.1\n")
    ['3.4', '3.4.1-preview1', 'ruby-3.4.1', '', 'latest'].each do |bad|
      assert_raises(ArgumentError, "should reject #{bad.inspect}") do
        HerokuRubyAvailability.parse(bad)
      end
    end
  end

  # 403 is the one that matters: S3 sends it, not 404, for an object it
  # will not list. And being unable to ask must never read as "no".
  test 'available? answers only to 200, and raises when it cannot ask' do
    publish('3.4.10')
    assert HerokuRubyAvailability.available?(version: '3.4.10', stack: STACK)

    [403, 404, 500].each do |status|
      WebMock.reset!
      stub_request(:head, /heroku-buildpack-ruby.*\.tgz/)
        .to_return(status: status)
      assert_not(
        HerokuRubyAvailability.available?(version: '3.4.10', stack: STACK),
        "#{status} should not count as available"
      )
    end

    [->(r) { r.to_raise(Errno::ECONNREFUSED) }, ->(r) { r.to_timeout }]
      .each do |failure|
        WebMock.reset!
        failure.call(stub_request(:head, /heroku-buildpack-ruby.*\.tgz/))
        assert_raises(HerokuRubyAvailability::Unreachable) do
          HerokuRubyAvailability.available?(version: '3.4.1', stack: STACK)
        end
      end
  end

  test 'highest_patch searches a line the way Heroku does' do
    {
      'the newest patch above where we started' =>
        [%w[3.4.2 3.4.3], '3.4', 1, '3.4.3'],
      'nothing, when the line has nothing newer' =>
        [%w[3.4.1], '3.4', 1, nil],
      # Stopping at the first miss would hide 3.4.5 behind a missing
      # 3.4.3; Heroku's own range tolerates exactly this much.
      'past a gap that fits inside the window' =>
        [%w[3.4.2 3.4.5], '3.4', 1, '3.4.5'],
      # Where that tolerance ends. A hole this wide hides the version
      # from a deploy's own suggestion too.
      'nothing, past a gap wider than the window' =>
        [%w[3.4.20], '3.4', 1, nil],
      # The window slides only while its last patch exists.
      'onward while the window keeps hitting' =>
        [line('3.4', 2..12), '3.4', 1, '3.4.12'],
      'from zero, for a line we are not on yet' =>
        [%w[3.5.0], '3.5', -1, '3.5.0'],
      # Heroku need not carry a line's .0 for the line to exist.
      'a line that does not start at zero' =>
        [%w[3.5.3], '3.5', -1, '3.5.3']
    }.each do |intent, (published, searched, after, expected)|
      publish(*published)
      assert_equal(
        expected,
        HerokuRubyAvailability.highest_patch(
          line: searched, after: after, stack: STACK
        ),
        "should find #{intent}"
      )
    end

    # A bucket answering 200 to everything must not become a crawl.
    WebMock.reset!
    stub_request(:head, /heroku-buildpack-ruby.*\.tgz/).to_return(status: 200)
    ceiling = HerokuRubyAvailability::MAX_PROBES_PER_LINE
    assert_equal(
      "3.4.#{ceiling - 1}",
      HerokuRubyAvailability.highest_patch(line: '3.4', after: -1, stack: STACK)
    )
  end

  test 'available_versions reports what Heroku has, one per line' do
    {
      'the newest on our own line' =>
        [line('3.4', 0..10), ['3.4.10']],
      # One per line, so Renovate can offer each as its own decision.
      'one per line, when several have something' =>
        [
          line('3.4', 0..10) + line('3.5', 0..2) + line('4.0', 0..6),
          %w[3.4.10 3.5.2 4.0.6]
        ],
      # Ruby went 2.7 to 3.0, so the next major must be probed even when
      # the next minor never appears.
      'the next major, with no next minor in between' =>
        [line('4.0', 0..6), ['4.0.6']],
      # The list describes Heroku, not us, so what we already run
      # belongs in it while it is still newest on its line.
      'the version we already run, when it is still newest' =>
        [line('3.4', 0..1), ['3.4.1']],
      'nothing, when Heroku has nothing on our lines' =>
        [[], []]
    }.each do |intent, (published, expected)|
      publish(*published)
      assert_equal(
        expected,
        HerokuRubyAvailability.available_versions(
          current: '3.4.1', stack: STACK
        ),
        "should report #{intent}"
      )
    end

    # Accepting an upgrade within a line must not change the published
    # list, or every upgrade we took would look like news from Heroku.
    publish(*line('3.4', 0..10))
    assert_equal(
      HerokuRubyAvailability.available_versions(current: '3.4.1', stack: STACK),
      HerokuRubyAvailability.available_versions(current: '3.4.10', stack: STACK)
    )
  end
end
# rubocop:enable Metrics/ClassLength
