# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

class SafeInflateTest < ActiveSupport::TestCase
  # --- Happy path: real content round-trips through both framings ---

  test 'inflates a gzip stream back to the original content' do
    original = 'Installation instructions and usage notes.' * 10
    compressed = Zlib.gzip(original)
    result = SafeInflate.inflate(compressed, max_bytes: 1_000_000)
    assert_equal original, result.force_encoding('UTF-8')
  end

  test 'inflates a zlib/deflate stream (auto-detected framing)' do
    original = 'security policy text'
    compressed = Zlib::Deflate.deflate(original)
    result = SafeInflate.inflate(compressed, max_bytes: 1_000_000)
    assert_equal original, result.force_encoding('UTF-8')
  end

  test 'output is bytes even when input spans many INPUT_SLICE chunks' do
    # Larger than one INPUT_SLICE of *compressed* input to exercise the
    # multi-slice feed loop, but well under the cap.
    original = 'x' * (SafeInflate::INPUT_SLICE * 4)
    compressed = Zlib.gzip(original)
    result = SafeInflate.inflate(compressed, max_bytes: original.bytesize + 10)
    assert_equal original.bytesize, result.bytesize
  end

  # --- Security: decompression bombs are refused ---

  test 'raises TooLarge on a decompression bomb without materializing it' do
    # ~5 MB of a single repeated byte compresses to a few KB: a classic bomb.
    bomb = Zlib.gzip('A' * 5_000_000)
    assert bomb.bytesize < 10_000, 'sanity: bomb should be tiny compressed'
    assert_raises(SafeInflate::TooLarge) do
      SafeInflate.inflate(bomb, max_bytes: 1_000)
    end
  end

  test 'output exactly at the cap is allowed' do
    original = 'y' * 500
    compressed = Zlib.gzip(original)
    result = SafeInflate.inflate(compressed, max_bytes: 500)
    assert_equal 500, result.bytesize
  end

  test 'one byte over the cap raises TooLarge' do
    original = 'z' * 501
    compressed = Zlib.gzip(original)
    assert_raises(SafeInflate::TooLarge) do
      SafeInflate.inflate(compressed, max_bytes: 500)
    end
  end

  # --- Input validation and malformed streams ---

  test 'rejects a non-positive max_bytes' do
    compressed = Zlib.gzip('hello')
    assert_raises(ArgumentError) { SafeInflate.inflate(compressed, max_bytes: 0) }
    assert_raises(ArgumentError) do
      SafeInflate.inflate(compressed, max_bytes: -1)
    end
  end

  test 'raises Zlib::Error on data that is not a valid compressed stream' do
    assert_raises(Zlib::Error) do
      SafeInflate.inflate('this is not compressed', max_bytes: 1_000)
    end
  end
end
