# frozen_string_literal: true

# Copyright the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'
require 'no_dup_coder'

# Test NoDupCoder, which replaces DupCoder in MemoryStore to avoid
# duplicating frozen strings on every cache read.
class NoDupCoderTest < ActiveSupport::TestCase
  test 'dump freezes string values' do
    entry = ActiveSupport::Cache::Entry.new('hello world')
    dumped = NoDupCoder.dump(entry)
    assert dumped.value.frozen?, 'dumped string value should be frozen'
  end

  test 'dump wraps non-string values in MarshaledValue' do
    entry = ActiveSupport::Cache::Entry.new([1, 2, 3])
    dumped = NoDupCoder.dump(entry)
    assert_instance_of NoDupCoder::MarshaledValue, dumped.value
  end

  test 'dump passes through nil, true, and numeric values unchanged' do
    entry_nil = ActiveSupport::Cache::Entry.new(nil)
    assert_nil NoDupCoder.dump(entry_nil).value

    [true, 42, 3.14].each do |val|
      entry = ActiveSupport::Cache::Entry.new(val)
      dumped = NoDupCoder.dump(entry)
      assert_equal val, dumped.value
    end
  end

  test 'load returns string entry as-is' do
    original = 'cached content'.dup.freeze
    entry = ActiveSupport::Cache::Entry.new(original)
    loaded = NoDupCoder.load(entry)
    assert_same entry, loaded
    assert_equal 'cached content', loaded.value
    assert loaded.value.frozen?
  end

  test 'load deserializes MarshaledValue entries' do
    array = [1, 2, 3]
    wrapped = NoDupCoder::MarshaledValue.new(Marshal.dump(array))
    entry = ActiveSupport::Cache::Entry.new(wrapped)
    loaded = NoDupCoder.load(entry)
    assert_equal array, loaded.value
  end

  test 'dump/load round-trips non-string values correctly' do
    original = { key: 'value', nested: [1, 2] }
    entry = ActiveSupport::Cache::Entry.new(original)
    dumped = NoDupCoder.dump(entry)
    loaded = NoDupCoder.load(dumped)
    assert_equal original, loaded.value
  end

  test 'dump preserves expires_at and version metadata' do
    expires = 1.hour.from_now.to_f
    entry = ActiveSupport::Cache::Entry.new('value',
                                            expires_at: expires,
                                            version: 'v1')
    dumped = NoDupCoder.dump(entry)
    assert_equal expires, dumped.expires_at
    assert_equal 'v1', dumped.version
  end

  test 'dump_compressed works with compressible entries' do
    large_value = 'x' * 2048
    entry = ActiveSupport::Cache::Entry.new(large_value)
    result = NoDupCoder.dump_compressed(entry, 1024)
    # Either compressed or dumped, both are valid
    assert_instance_of ActiveSupport::Cache::Entry, result
  end

  test 'dump_compressed falls back to dump for small entries' do
    entry = ActiveSupport::Cache::Entry.new('small')
    result = NoDupCoder.dump_compressed(entry, 1024)
    assert_instance_of ActiveSupport::Cache::Entry, result
    assert result.value.frozen?
  end

  test 'SafeBuffer values preserve html_safe through dump/load cycle' do
    safe = '<p>hello</p>'.html_safe
    entry = ActiveSupport::Cache::Entry.new(safe)
    dumped = NoDupCoder.dump(entry)
    loaded = NoDupCoder.load(dumped)
    assert loaded.value.html_safe?, 'html_safe? should be preserved'
    assert_equal '<p>hello</p>', loaded.value
  end

  test 'load returns non-string entries unchanged' do
    entry = ActiveSupport::Cache::Entry.new(42)
    loaded = NoDupCoder.load(entry)
    assert_same entry, loaded
    assert_equal 42, loaded.value
  end

  test 'already frozen strings are not re-duped on dump' do
    frozen_str = 'already frozen'
    entry = ActiveSupport::Cache::Entry.new(frozen_str)
    dumped = NoDupCoder.dump(entry)
    assert_same frozen_str, dumped.value
  end

  test 'strings starting with Marshal signature are never deserialized' do
    # This is the key security test: user-supplied strings that happen
    # to start with Marshal's magic bytes must be treated as plain strings,
    # never passed to Marshal.load.
    evil = "\x04\x08o:dangerous"
    entry = ActiveSupport::Cache::Entry.new(evil)
    dumped = NoDupCoder.dump(entry)
    loaded = NoDupCoder.load(dumped)
    assert_equal evil, loaded.value
    assert_instance_of String, loaded.value
  end

  test 'Rails.cache uses NoDupCoder and returns frozen values' do
    Rails.cache.write('nodup_test_key', 'test_value')
    result = Rails.cache.read('nodup_test_key')
    assert_equal 'test_value', result
    assert result.frozen?, 'cached string should be frozen'
  ensure
    Rails.cache.delete('nodup_test_key')
  end
end
