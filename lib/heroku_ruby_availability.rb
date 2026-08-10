# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'net/http'
require 'uri'

# Can Heroku deploy this Ruby on this stack, and which does it have?
#
# It decides nothing; what to do about a newer Ruby is Renovate's job,
# fed by the list this produces. See .github/renovate.json5.
#
# WHY PROBE RATHER THAN READ A LIST. There is no machine-readable one.
# The devcenter names supported versions in prose bullets, without
# saying which stack each is built for, and heroku/buildpacks-ruby has
# no inventory file. Heroku's own buildpack probes too:
# download_presence.rb and outdated_ruby_version.rb issue HEAD requests
# for versions they guess. So we learn what a deploy would learn.
#
# ONLY 200 MEANS YES. S3 answers 403, not 404, for an object it will
# not list, so "not a 404" would read a permissions change as a
# published Ruby.
#
# UNREACHABLE IS NOT UNAVAILABLE. Conflating them is how a guard stops
# guarding: a developer on a train would look like Heroku dropping our
# Ruby. Connection failures raise Unreachable and callers decide.
#
# STANDARD LIBRARY ONLY. script/heroku_ruby_versions loads this where
# there is no bundle, so a gem added here breaks that workflow rather
# than the test suite.
module HerokuRubyAvailability
  BUCKET_URL = 'https://heroku-buildpack-ruby.s3.us-east-1.amazonaws.com'

  # Heroku publishes per architecture; the dynos and our CI are amd64.
  ARCH = 'amd64'

  # Heroku's OutdatedRubyVersion uses DEFAULT_RANGE = 1..5 and extends
  # when the last of a range exists, tolerating a gap of up to four.
  # Matching it means we find what a deploy would find.
  PROBE_WINDOW = 5

  # So a bucket answering 200 to everything cannot become a crawl.
  MAX_PROBES_PER_LINE = 50

  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 10

  # "Could not ask", as distinct from "the answer was no". Listed
  # rather than rescuing StandardError so a bug here surfaces as a bug.
  NETWORK_ERRORS = [
    SocketError, EOFError, IOError,
    Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH,
    Errno::ENETUNREACH, Errno::ETIMEDOUT,
    Net::OpenTimeout, Net::ReadTimeout,
    OpenSSL::SSL::SSLError
  ].freeze

  # Raised when S3 could not be reached at all.
  class Unreachable < StandardError; end

  module_function

  # @param version [String] e.g. "3.4.10"
  # @param stack [String] e.g. "heroku-24"
  # @return [String] the tarball URL a Heroku build would fetch
  def url_for(version:, stack:)
    "#{BUCKET_URL}/#{stack}/#{ARCH}/ruby-#{version}.tgz"
  end

  # @param version [String] e.g. "3.4.10"
  # @param stack [String] e.g. "heroku-24"
  # @return [Boolean] true only if the tarball answered 200
  # @raise [Unreachable] if S3 could not be reached
  def available?(version:, stack:)
    uri = URI.parse(url_for(version: version, stack: stack))
    http_head(uri).code.to_i == 200
  rescue *NETWORK_ERRORS => e
    raise Unreachable, "Could not reach #{uri}: #{e.class}: #{e.message}"
  end

  # The highest published patch on one line, or nil if the line has
  # nothing above where we started.
  #
  # @param line [String] e.g. "3.4"
  # @param after [Integer] probe from this patch + 1; -1 starts at 0
  # @param stack [String]
  # @return [String, nil] e.g. "3.4.10"
  # @raise [Unreachable]
  def highest_patch(line:, after:, stack:)
    best = nil
    probes = 0
    start = after + 1
    while probes < MAX_PROBES_PER_LINE
      patches = (start...(start + PROBE_WINDOW)).to_a
      hits = probe_window(line, patches, stack)
      best = hits.max if hits.any?
      probes += patches.size
      # Extend only when the LAST of the window exists, as Heroku does.
      # Compared this way because "hits" keeps the order of "patches";
      # exclude? would be ActiveSupport, absent from a :no_rails task.
      break unless hits.last == patches.last

      start += PROBE_WINDOW
    end
    best && "#{line}.#{best}"
  end

  # @return [Array<Integer>] the patches in this window that exist
  def probe_window(line, patches, stack)
    patches.select { |p| available?(version: "#{line}.#{p}", stack: stack) }
  end

  # The newest Ruby Heroku has on each line worth considering, which is
  # the list Renovate chooses from.
  #
  # DELIBERATELY NOT "what is newer than us": the published list must
  # depend on Heroku, not on where .ruby-version sits, or it would churn
  # on every upgrade we accepted and each change would look like news.
  # So our own line is probed from zero like any other.
  #
  # @param current [String] the version in .ruby-version, e.g. "3.4.1"
  # @param stack [String] e.g. "heroku-24"
  # @return [Array<String>] ascending, one per line that has anything
  # @raise [Unreachable]
  def available_versions(current:, stack:)
    major, minor = parse(current)
    candidate_lines(major, minor).filter_map do |line|
      highest_patch(line: line, after: -1, stack: stack)
    end
  end

  # @param version [String] e.g. "3.4.1"
  # @return [Array<Integer>] [major, minor, patch]
  # @raise [ArgumentError] if it is not three dot-separated numbers
  def parse(version)
    match = /\A(\d+)\.(\d+)\.(\d+)\z/.match(version.to_s.strip)
    if match.nil?
      raise ArgumentError,
            "Not an X.Y.Z Ruby version: #{version.inspect}"
    end

    match.captures.map(&:to_i)
  end

  # Our line and the ones above. Short on purpose: moving up a line
  # moves the frontier with it. Ruby went 2.7 to 3.0 and may go 3.4 to
  # 4.0, so the next major counts even when the next minor is absent.
  def candidate_lines(major, minor)
    [
      "#{major}.#{minor}", "#{major}.#{minor + 1}",
      "#{major}.#{minor + 2}", "#{major + 1}.0"
    ]
  end

  # Seam for tests, and the only place that touches the network.
  def http_head(uri)
    Net::HTTP.start(
      uri.host, uri.port,
      use_ssl: true, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT
    ) { |http| http.head(uri.request_uri) }
  end
end
