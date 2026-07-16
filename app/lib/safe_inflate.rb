# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'zlib'
require 'stringio'

# SafeInflate is the ONLY sanctioned way to decompress untrusted external data
# (evidence fetched from attacker-controlled repo / homepage / arbitrary URLs).
#
# It defends against "decompression bombs": a tiny gzip payload that inflates
# to gigabytes and exhausts memory. We never hand attacker data to a raw
# Zlib::Inflate, an auto-decoding HTTP client, or a `gz.read` with no length,
# because those inflate more than we asked for before we can react.
#
# The mechanism is a *pull*: Zlib::GzipReader#read(n) inflates only enough
# input to produce n output bytes and then stops. We ask for one byte past the
# cap; if we get it, the stream is over budget and we refuse. A 200 MB bomb is
# stopped after inflating ~max_bytes bytes, with no multi-megabyte transient
# spike (a push-style Zlib::Inflate fed even a single 16 KB slice can expand to
# ~16 MB inside one call before any size check runs; the pull model avoids
# that entirely). Easy to reason about in one sentence: output can never exceed
# max_bytes, and neither can the memory used to produce it.
#
# Only gzip framing is handled. Because every fetch path requests identity
# encoding, a compressed response only ever comes from a misbehaving or hostile
# server, and gzip is the dominant Content-Encoding by far; raw `deflate` is
# deliberately not supported (it raises Zlib::Error, which fetch callers already
# rescue). Add it explicitly if a real need appears, rather than carrying a
# worse memory profile for a case that essentially never occurs.
module SafeInflate
  # Raised when the decompressed stream would exceed the caller's max_bytes.
  class TooLarge < StandardError; end

  # Inflate a gzip stream, producing at most `max_bytes` of output.
  #
  # @param data [String] the gzip-compressed bytes (already size-bounded
  #   upstream, e.g. by Evidence::MAXREAD).
  # @param max_bytes [Integer] hard cap on decompressed output size.
  # @return [String] the decompressed content (binary encoding).
  # @raise [SafeInflate::TooLarge] if the output would exceed max_bytes.
  # @raise [Zlib::Error] if `data` is not a valid gzip stream (callers that
  #   fetch untrusted data typically rescue StandardError).
  def self.gunzip(data, max_bytes:)
    raise ArgumentError, 'max_bytes must be positive' unless max_bytes.positive?

    reader = Zlib::GzipReader.new(StringIO.new(data))
    # Pull one byte past the cap: getting it proves the stream is over budget.
    # read returns nil at EOF (e.g. gzip of ""), which we normalize to "".
    out = reader.read(max_bytes + 1) || (+'').force_encoding(Encoding::BINARY)
    raise TooLarge, "decompressed output exceeds #{max_bytes} bytes" \
      if out.bytesize > max_bytes

    out
  ensure
    reader&.close
  end
end
