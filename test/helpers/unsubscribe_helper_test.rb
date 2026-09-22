# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# rubocop: disable-next Metrics/BlockLength
class UnsubscribeHelperTest < ActionView::TestCase
  test 'compute_key_array with one key' do
    key_string = 'fake_key_123'
    result = UnsubscribeHelper.compute_key_array(key_string)

    assert_equal ['fake_key_123'], result
    assert result.frozen?
  end

  test 'compute_key_array with two keys separated by comma' do
    key_string = 'fake_key_123,fake_key_456'
    result = UnsubscribeHelper.compute_key_array(key_string)

    assert_equal %w[fake_key_123 fake_key_456], result
    assert result.frozen?
  end

  test 'compute_key_array with three keys separated by commas' do
    key_string = 'fake_key_123,fake_key_456,fake_key_789'
    result = UnsubscribeHelper.compute_key_array(key_string)

    assert_equal %w[fake_key_123 fake_key_456 fake_key_789], result
    assert result.frozen?
  end

  test 'compute_key_array handles whitespace around keys' do
    key_string = ' fake_key_123 , fake_key_456 ,  fake_key_789  '
    result = UnsubscribeHelper.compute_key_array(key_string)

    assert_equal %w[fake_key_123 fake_key_456 fake_key_789], result
    assert result.frozen?
  end

  test 'compute_key_array rejects empty keys' do
    key_string = 'fake_key_123,,fake_key_456, ,fake_key_789'
    result = UnsubscribeHelper.compute_key_array(key_string)

    assert_equal %w[fake_key_123 fake_key_456 fake_key_789], result
    assert result.frozen?
  end

  test 'compute_key_array with empty string returns empty array' do
    key_string = ''
    result = UnsubscribeHelper.compute_key_array(key_string)

    assert_equal [], result
    assert result.frozen?
  end

  test 'compute_key_array with only commas and spaces returns empty array' do
    key_string = ' , , , '
    result = UnsubscribeHelper.compute_key_array(key_string)

    assert_equal [], result
    assert result.frozen?
  end
end
