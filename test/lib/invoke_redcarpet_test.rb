# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# rubocop:disable Metrics/ClassLength
class InvokeRedcarpetTest < ActiveSupport::TestCase
  # Reset between tests to ensure clean state
  def setup
    super
    InvokeRedcarpet.instance_variable_set(:@previous_content, nil)
  end

  test 'invoke_and_sanitize renders simple markdown' do
    result = InvokeRedcarpet.invoke_and_sanitize('*emphasis*')
    assert_equal "<p><em>emphasis</em></p>\n", result
    assert result.html_safe?
  end

  test 'invoke_and_sanitize handles blank content' do
    result = InvokeRedcarpet.invoke_and_sanitize('')
    # Redcarpet returns empty string for empty input
    assert_equal '', result
    assert result.html_safe?
  end

  test 'invoke_and_sanitize with force_bad_type raises TypeError' do
    error =
      assert_raises(TypeError) do
        InvokeRedcarpet.invoke_and_sanitize('test', raise_on_error: true, force_bad_type: true)
      end

    assert_match(/wrong type/i, error.message)
  end

  test 'invoke_and_sanitize with force_bad_type returns escaped content when not raising' do
    result = InvokeRedcarpet.invoke_and_sanitize('<test>',
                                                 raise_on_error: false,
                                                 force_bad_type: true)
    # Should return HTML-escaped content as fallback
    assert_equal '&lt;test&gt;', result
    assert result.html_safe?
  end

  test 'invoke_and_sanitize with force_exception raises when raise_on_error true' do
    test_error = StandardError.new('Test error')

    error =
      assert_raises(StandardError) do
        InvokeRedcarpet.invoke_and_sanitize('test',
                                            raise_on_error: true,
                                            force_exception: test_error)
      end

    assert_equal 'Test error', error.message
  end

  test 'invoke_and_sanitize with force_exception returns escaped when raise_on_error false' do
    test_error = StandardError.new('Test error')

    result = InvokeRedcarpet.invoke_and_sanitize('<b>test</b>',
                                                 raise_on_error: false,
                                                 force_exception: test_error)

    # Should return HTML-escaped content as fallback
    assert_equal '&lt;b&gt;test&lt;/b&gt;', result
    assert result.html_safe?
  end

  test 'invoke_and_sanitize resets processor on exception' do
    # Force an exception
    test_error = StandardError.new('Test error')
    result = InvokeRedcarpet.invoke_and_sanitize('*test*',
                                                 raise_on_error: false,
                                                 force_exception: test_error)
    assert_equal '*test*', result # Lightly escaped
  end
end
# rubocop:enable Metrics/ClassLength
