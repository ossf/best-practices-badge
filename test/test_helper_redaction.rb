# frozen_string_literal: true

# Copyright the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Redact the data that we store in VCR cassettes to prevent
# recording data that *looks* like a secret.

# A 40-character lowercase hex string is indistinguishable from a CircleCI
# API token, which is also 40-hex. Our recorded HTTP interactions are full of
# such strings that are NOT secrets: git SHA-1 object ids (GitHub "contents",
# blob, tree, and commit responses), GitHub ETags (W/"<40-hex>"), and Rails
# session-cookie HMACs. The secret scanner Kusari Inspector (and perhaps
# others) flags these as leaked credentials -- repeatedly, on whichever one
# it happens to pick -- so chasing them individually is whack-a-mole. None of
# them are real secrets, none are read by code under test, and none appear in
# a request URI (VCR matches requests on method + URI only), so we simply
# blank every standalone 40-hex string in cassettes. Collapsing distinct
# values to one placeholder is therefore safe for request matching.
#
# This rule has exactly one home so the before_record hook (test_helper.rb,
# for newly recorded cassettes) and the one-off scrub of existing cassettes
# (script/redact_vcr_git_shas.rb) stay identical.

module VcrRedaction
  module_function

  NULL_SHA = ('0' * 40).freeze
  # Bounded so 64-hex SHA-256 digests are left intact (not token-shaped).
  HEX_40 = /\b[0-9a-f]{40}\b/

  # Replace every standalone 40-hex string in +text+ with zeros. Returns the
  # scrubbed text. Used directly on whole cassette files by the scrub script.
  def redact_git_shas(text)
    # Plain String predicates (not blank?) so the standalone scrub script can
    # require this file without loading ActiveSupport.
    return text if text.nil? || text.empty? # rubocop:disable Rails/Blank

    text.gsub(HEX_40, NULL_SHA)
  end

  # Scrub a recorded VCR request/response (both expose #body and #headers) in
  # place. We deliberately do not touch the URI, since request matching relies
  # on it and it never contains a 40-hex string.
  def redact_message!(message)
    message.body = redact_git_shas(message.body)
    message.headers&.each_value do |values|
      values.map! { |value| redact_git_shas(value) }
    end
    message
  end
end
