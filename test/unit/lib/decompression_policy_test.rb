# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# Enforces our anti-"decompression bomb" invariant by construction rather than
# by comment, so it stays true as detectives are added or changed:
#
#   1. Every path that fetches untrusted external data requests identity
#      encoding, so the HTTP stack never transparently inflates a response.
#   2. SafeInflate is the ONLY place under app/lib that touches Zlib, so the
#      single sanctioned (output-capped) decompressor cannot be bypassed.
class DecompressionPolicyTest < ActiveSupport::TestCase
  test 'Evidence requests identity encoding on outbound fetches' do
    assert_equal 'identity', Evidence::REQUEST_HEADERS['Accept-Encoding']
  end

  test 'GithubContentAccess requests identity encoding on content fetches' do
    assert_equal 'identity',
                 GithubContentAccess::IDENTITY_ENCODING['Accept-Encoding']
  end

  test 'no app/lib code decompresses except SafeInflate' do
    files = Rails.root.glob('app/lib/**/*.rb')
    offenders =
      files.select do |path|
        next false if File.basename(path) == 'safe_inflate.rb'

        # A raw Zlib/GzipReader call inflates the whole stream with no output
        # cap: exactly the bomb vector SafeInflate exists to prevent. Match
        # actual use (Zlib::... / Zlib....) or GzipReader, not the word "Zlib"
        # in prose or in a license name such as "zlib/libpng license (Zlib)".
        File.read(path).match?(/Zlib::|Zlib\.|GzipReader/)
      end

    assert_empty offenders,
                 'Decompress untrusted data via SafeInflate (output-capped), ' \
                 "not raw Zlib. Offending file(s): #{offenders.join(', ')}"
  end
end
