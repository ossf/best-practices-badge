# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# Enforces our anti-"decompression bomb" invariant by construction rather than
# by comment, so it stays true as detectives are added or changed:
#
#   1. The Evidence path fetches fully untrusted, attacker-chosen URLs. It sets
#      Accept-Encoding *explicitly* (gzip), which keeps Net::HTTP's
#      decode_content off, and it decodes on demand through SafeInflate - so an
#      untrusted server can never transparently inflate a response on us.
#   2. The GitHub path (GithubContentAccess) deliberately does NOT pin
#      Accept-Encoding: transport compression is applied by
#      GitHub-the-organization, the same trusted party whose reported file size
#      this path already relies on, so we let the stack inflate gzip and save
#      bandwidth. (Repo file *content* is untrusted, but it is only read as
#      opaque bytes here, never expanded as an archive.)
#   3. SafeInflate is the ONLY place under app/lib that touches Zlib, so the
#      single sanctioned (output-capped) decompressor cannot be bypassed for
#      any untrusted data we do decompress ourselves.
class DecompressionPolicyTest < ActiveSupport::TestCase
  test 'Evidence advertises gzip and only gzip (matches SafeInflate)' do
    # gzip, not deflate: SafeInflate handles only gzip framing, so what we
    # accept always matches what we can safely decode.
    assert_equal 'gzip', Evidence::REQUEST_HEADERS['Accept-Encoding']
  end

  test 'GithubContentAccess does not pin Accept-Encoding (trusts transport)' do
    # By construction: the GitHub path must not reintroduce a forced
    # Accept-Encoding. Transport compression there is GitHub-the-org's, a
    # trusted party (see the class's TRUST BOUNDARY note), so pinning identity
    # would only cost bandwidth for no security gain.
    source = Rails.root.join('app/lib/github_content_access.rb').read
    assert_no_match(/Accept-Encoding/i, source,
                    'GithubContentAccess should trust GitHub transport ' \
                    'compression and not set Accept-Encoding')
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
