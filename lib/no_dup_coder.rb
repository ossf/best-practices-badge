# frozen_string_literal: true

# Copyright the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# NoDupCoder is a drop-in replacement for ActiveSupport::Cache::MemoryStore's
# default DupCoder. Instead of duplicating strings on every cache read,
# NoDupCoder freezes values on write and returns the frozen object directly
# on read. This eliminates large string allocations from Marshal/dup on
# every cache hit (e.g., fragment cache reads).
#
# Safety: frozen strings cannot be mutated, so there is no risk of cache
# corruption. Frozen SafeBuffers preserve their html_safe? status.
#
# Unlike DupCoder, this module never inspects string contents to guess
# whether they are marshaled data. Instead, marshaled non-string values
# are wrapped in a MarshaledValue struct, so the type alone determines
# handling on load. This avoids the risk of a potential deserialization
# vulnerability where user-supplied strings starting with
# Marshal's signature bytes could trigger Marshal.load.

module NoDupCoder
  # Wrapper that distinguishes marshaled non-string values from plain
  # strings stored in the cache. Using a distinct type eliminates any
  # need to inspect string contents on load, which is a much more secure way
  # to indicate if we need to marshall a value or not (even if an attacker
  # manages to get a magic prefix into the string, it doesn't matter).
  MarshaledValue = Struct.new(:data)

  extend self # rubocop:disable Style/ModuleFunction

  # Prepares a cache entry for storage by returning:
  # - if it's a string, return the string if frozen else a dupe frozen string
  # - if it's already frozen, return it (including all Ruby immediates)
  # - else it wraps the non-string non-frozen objects in a MarshaledValue.
  def dump(entry)
    value = entry.value
    if value.frozen?
      # If it's frozen, including a frozen string, simply return it.
      # Frozen values can't change so we can simply reuse them every time.
      # All Ruby immediates (nil, true, false, Integer, Float, Symbol)
      # are frozen. This also covers any future Ruby immediates and any
      # value the caller has explicitly frozen.
      entry
    elsif value.is_a?(String)
      # Dupe & record a frozen string, so we can simply reuse it each time
      # from the cache. This is common situation. This means that you have to
      # "dupe" a string returned from the cache if you want to change it
      # later, but that's a rare circumstance; we want to optimize the
      # normal case.
      new_entry(value.dup.freeze, entry)
    else
      # Wrap anything else as a MarshaledValue. This does create another
      # object, but we hope to make up this extra effort by being able to
      # reuse the data later from the cache.
      new_entry(MarshaledValue.new(Marshal.dump(value)), entry)
    end
  end

  # Attempts to compress the entry if it exceeds the threshold;
  # falls back to standard dump if compression is not applicable or beneficial.
  def dump_compressed(entry, threshold)
    compressed_entry = entry.compressed(threshold)
    compressed_entry.compressed? ? compressed_entry : dump(entry)
  end

  # Retrieves the original object from the cache entry, deserializing
  # MarshaledValue wrappers, while passing through
  # other values (like frozen values) untouched.
  def load(entry)
    if entry.value.is_a?(MarshaledValue)
      new_entry(
        Marshal.load(entry.value.data), # rubocop:disable Security/MarshalLoad
        entry
      )
    else
      entry
    end
  end

  private

  # Creates a new ActiveSupport::Cache::Entry while preserving
  # the original metadata (expiration and version).
  def new_entry(value, source)
    ActiveSupport::Cache::Entry.new(
      value, expires_at: source.expires_at, version: source.version
    )
  end
end
