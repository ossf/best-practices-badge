#!/usr/bin/env ruby
# frozen_string_literal: true

# Copyright the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Redact git SHA-1 object ids that secret scanners mistake for CircleCI
# tokens from the recorded VCR cassettes. This applies the SAME rule that
# test/test_helper.rb's VcrRedaction.before_record hook applies to newly
# recorded cassettes, so existing fixtures match what a fresh recording
# would produce. Idempotent: re-running it changes nothing once scrubbed.
#
# Usage: ruby script/redact_vcr_git_shas.rb

require_relative '../test/test_helper_redaction'

CASSETTE_GLOB = File.expand_path('../test/vcr_cassettes/**/*.yml', __dir__)

Dir.glob(CASSETTE_GLOB).each do |path|
  original = File.read(path)
  scrubbed = VcrRedaction.redact_git_shas(original)
  next if scrubbed == original

  File.write(path, scrubbed)
  puts "Redacted #{path}"
end
