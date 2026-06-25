# frozen_string_literal: true

# Copyright the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Redact the data that we store in VCR cassettes to prevent
# recording data that *looks* like a secret.

# GitHub's "contents" API returns directory entries that each carry a 40-hex
# git SHA-1 object id. A 40-hex string sitting next to the literal text
# "circleci" (the ".circleci" folder entry) looks like a
# CircleCI API token, which is also 40-hex, so the secret scanner
# Kusari Inspector (and perhaps others) flags it as a leaked credential.
# These are public, non-secret git object ids
# that none of our code ever reads, so we neutralize them in cassettes.
#
# This rule has exactly one home so the before_record hook (test_helper.rb,
# for newly recorded cassettes) and the one-off scrub of existing cassettes
# (script/redact_vcr_circleci_shas.rb) stay identical.

module VcrRedaction
  module_function

  NULL_SHA = ('0' * 40).freeze

  # Redact every copy of each ".circleci" entry's git SHA-1 within +body+
  # (the hash recurs in the "sha", "git_url", and "_links" fields of the
  # same JSON object, so all copies must go). Returns the scrubbed body.
  def redact_circleci_shas(body)
    # Plain String predicates (not blank?) so the standalone scrub script can
    # require this file without loading ActiveSupport.
    return body if body.nil? || body.empty? # rubocop:disable Rails/Blank

    body.scan(/"name":"\.circleci"[^}]*?"sha":"([0-9a-f]{40})"/)
        .flatten.uniq
        .reduce(body) { |acc, elem| acc.gsub(elem, NULL_SHA) }
  end
end
