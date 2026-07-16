# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

class SafeInflateTest < ActiveSupport::TestCase
  # --- Happy path: gzip content round-trips ---

  test 'gunzips a gzip stream back to the original content' do
    original = 'Installation instructions and usage notes.' * 10
    result = SafeInflate.gunzip(Zlib.gzip(original), max_bytes: 1_000_000)
    assert_equal original, result.force_encoding('UTF-8')
  end

  test 'gunzips content larger than one internal read buffer' do
    original = 'x' * (256 * 1024)
    result = SafeInflate.gunzip(Zlib.gzip(original), max_bytes: original.bytesize)
    assert_equal original.bytesize, result.bytesize
  end

  test 'an empty gzip stream yields an empty string' do
    assert_equal '', SafeInflate.gunzip(Zlib.gzip(''), max_bytes: 1_000)
  end

  # --- Security: decompression bombs are refused without materializing ---

  test 'raises TooLarge on a decompression bomb' do
    # ~200 MB of a single repeated byte compresses to a few hundred KB. The
    # pull-based reader must stop after ~max_bytes, never inflating the rest.
    bomb = Zlib.gzip('A' * (200 * 1024 * 1024))
    assert bomb.bytesize < 1_000_000, 'sanity: bomb should be small compressed'
    assert_raises(SafeInflate::TooLarge) do
      SafeInflate.gunzip(bomb, max_bytes: 1_000)
    end
  end

  test 'output exactly at the cap is allowed' do
    result = SafeInflate.gunzip(Zlib.gzip('y' * 500), max_bytes: 500)
    assert_equal 500, result.bytesize
  end

  test 'one byte over the cap raises TooLarge' do
    assert_raises(SafeInflate::TooLarge) do
      SafeInflate.gunzip(Zlib.gzip('z' * 501), max_bytes: 500)
    end
  end

  # --- Input validation and unsupported/malformed streams ---

  test 'rejects a non-positive max_bytes' do
    gz = Zlib.gzip('hello')
    assert_raises(ArgumentError) { SafeInflate.gunzip(gz, max_bytes: 0) }
    assert_raises(ArgumentError) { SafeInflate.gunzip(gz, max_bytes: -1) }
  end

  test 'raises Zlib::Error on data that is not a gzip stream' do
    assert_raises(Zlib::Error) do
      SafeInflate.gunzip('this is not compressed', max_bytes: 1_000)
    end
  end

  test 'raw deflate (non-gzip framing) is not accepted' do
    # We intentionally support only gzip framing; a raw zlib/deflate stream
    # must be rejected rather than silently decoded.
    assert_raises(Zlib::Error) do
      SafeInflate.gunzip(Zlib::Deflate.deflate('some text'), max_bytes: 1_000)
    end
  end
end
