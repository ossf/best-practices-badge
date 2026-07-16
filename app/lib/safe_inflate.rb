# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'zlib'

# SafeInflate is the ONLY sanctioned way to decompress untrusted external data
# (evidence fetched from attacker-controlled repo / homepage / arbitrary URLs).
#
# It defends against "decompression bombs": a tiny gzip/deflate payload that
# inflates to gigabytes and exhausts memory. We never hand attacker data to a
# raw Zlib/GzipReader or an auto-decoding HTTP client, because those inflate
# the *entire* stream before we can see how big it got. Instead we feed the
# compressed input in bounded slices and stop the instant the *decompressed*
# output would exceed max_bytes, so a bomb is refused before it materializes.
#
# Why this is safe to reason about in one sentence: output can never exceed
# max_bytes, and transient memory is bounded by max_bytes plus at most one
# input slice's worth of expansion.
module SafeInflate
  # Raised when the decompressed stream would exceed the caller's max_bytes.
  class TooLarge < StandardError; end

  # Size of each compressed-input slice we feed to the inflater. Kept small so
  # the transient overshoot before we notice we are over the cap (at most one
  # slice inflated at zlib's maximum ratio) stays modest. This is a memory
  # bound, not a throughput knob; there is no reason to make it large.
  INPUT_SLICE = 16 * 1024

  # Auto-detect a gzip *or* zlib (deflate) header. MAX_WBITS + 32 tells Zlib to
  # accept either framing, which is what real servers and .gz files send.
  WINDOW_BITS = Zlib::MAX_WBITS + 32

  # Inflate gzip/deflate `data`, producing at most `max_bytes` of output.
  #
  # @param data [String] the compressed bytes (already size-bounded upstream,
  #   e.g. by Evidence::MAXREAD).
  # @param max_bytes [Integer] hard cap on decompressed output size.
  # @return [String] the decompressed content (binary encoding).
  # @raise [SafeInflate::TooLarge] if the output would exceed max_bytes.
  # @raise [Zlib::Error] if `data` is not a valid gzip/deflate stream
  #   (callers that fetch untrusted data typically rescue StandardError).
  def self.inflate(data, max_bytes:)
    raise ArgumentError, 'max_bytes must be positive' unless max_bytes.positive?

    zstream = Zlib::Inflate.new(WINDOW_BITS)
    out = (+'').force_encoding(Encoding::BINARY)
    feed_slices(zstream, data, out, max_bytes)
    out
  ensure
    # Always release the C-level zlib stream, even on TooLarge/Zlib::Error.
    zstream&.close
  end

  # Feed `data` to `zstream` one INPUT_SLICE at a time, appending decompressed
  # output to `out` and aborting as soon as it would exceed max_bytes.
  def self.feed_slices(zstream, data, out, max_bytes)
    pos = 0
    total = data.bytesize
    while pos < total
      out << zstream.inflate(data.byteslice(pos, INPUT_SLICE))
      raise TooLarge, "decompressed output exceeds #{max_bytes} bytes" \
        if out.bytesize > max_bytes

      pos += INPUT_SLICE
    end
    # Flush any bytes buffered inside zlib once all input has been fed.
    out << zstream.finish unless zstream.finished?
    raise TooLarge, "decompressed output exceeds #{max_bytes} bytes" \
      if out.bytesize > max_bytes
  end
  private_class_method :feed_slices
end
