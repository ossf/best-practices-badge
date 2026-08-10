# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

class CriterionFieldValidatorTest < ActiveSupport::TestCase
  test 'parse_status_value accepts case-insensitive status strings' do
    # Test all case variations of 'Met'
    %w[Met met MET mEt].each do |variation|
      result = CriterionFieldValidator.parse_status_value(variation)
      assert_equal CriterionStatus::MET, result[:value], "Failed for '#{variation}'"
      assert_equal 'Met', result[:canonical], "Canonical form should be 'Met' for '#{variation}'"
    end

    # Test other status values
    result = CriterionFieldValidator.parse_status_value('Unmet')
    assert_equal CriterionStatus::UNMET, result[:value]
    assert_equal 'Unmet', result[:canonical]

    result = CriterionFieldValidator.parse_status_value('N/A')
    assert_equal CriterionStatus::NA, result[:value]
    assert_equal 'N/A', result[:canonical]
  end

  test 'parse_status_value ignores ? and empty values' do
    assert_nil CriterionFieldValidator.parse_status_value('?')
    assert_nil CriterionFieldValidator.parse_status_value('')
    assert_nil CriterionFieldValidator.parse_status_value('   ')
  end

  test 'parse_status_value rejects non-string values' do
    assert_nil CriterionFieldValidator.parse_status_value(3)
    assert_nil CriterionFieldValidator.parse_status_value(nil)
    assert_nil CriterionFieldValidator.parse_status_value(['Met'])
  end

  test 'parse_status_value rejects invalid strings' do
    assert_nil CriterionFieldValidator.parse_status_value('invalid')
    assert_nil CriterionFieldValidator.parse_status_value('true')
    assert_nil CriterionFieldValidator.parse_status_value('false')
  end

  test 'parse_status_value rejects question mark and unknown for automation' do
    # JSON automation: '?' and 'unknown' mean "I don't know" - no automation value
    assert_nil CriterionFieldValidator.parse_status_value('?')
    assert_nil CriterionFieldValidator.parse_status_value('unknown')
    assert_nil CriterionFieldValidator.parse_status_value('UNKNOWN')
  end

  test 'parse_status_value accepts aliases for automation' do
    # JSON can use 'na' as alias for 'N/A'
    result = CriterionFieldValidator.parse_status_value('na')
    assert_equal 2, result[:value]
    assert_equal 'N/A', result[:canonical]

    result = CriterionFieldValidator.parse_status_value('NA')
    assert_equal 2, result[:value]
    assert_equal 'N/A', result[:canonical]
  end

  test 'validate_justification accepts valid UTF-8 text' do
    text = 'This is a valid justification'
    result = CriterionFieldValidator.validate_justification(text)
    assert_equal text, result
  end

  test 'validate_justification strips whitespace' do
    text = "  \n  Some text  \n  "
    result = CriterionFieldValidator.validate_justification(text)
    assert_equal 'Some text', result
  end

  test 'validate_justification rejects empty strings' do
    assert_nil CriterionFieldValidator.validate_justification('')
    assert_nil CriterionFieldValidator.validate_justification('   ')
  end

  test 'validate_justification rejects text exceeding max length' do
    long_text = 'a' * (Project::MAX_TEXT_LENGTH + 1)
    assert_nil CriterionFieldValidator.validate_justification(long_text)
  end

  test 'validate_justification accepts text at max length' do
    text = 'a' * Project::MAX_TEXT_LENGTH
    result = CriterionFieldValidator.validate_justification(text)
    assert_equal text, result
  end

  test 'validate_justification rejects non-strings' do
    assert_nil CriterionFieldValidator.validate_justification(123)
    assert_nil CriterionFieldValidator.validate_justification(nil)
    assert_nil CriterionFieldValidator.validate_justification(['text'])
  end

  test 'validate_field_name accepts valid criterion fields' do
    result = CriterionFieldValidator.validate_field_name('contribution_status')
    assert_equal :contribution_status, result

    result = CriterionFieldValidator.validate_field_name(:license_location_status)
    assert_equal :license_location_status, result
  end

  test 'validate_field_name rejects invalid fields' do
    assert_nil CriterionFieldValidator.validate_field_name('invalid_field')
    assert_nil CriterionFieldValidator.validate_field_name('random_status')
  end

  test 'status_field? identifies status fields correctly' do
    assert CriterionFieldValidator.status_field?(:contribution_status)
    assert CriterionFieldValidator.status_field?(:license_location_status)
    assert_not CriterionFieldValidator.status_field?(:contribution_justification)
    assert_not CriterionFieldValidator.status_field?(:name)
  end

  test 'justification_field? identifies justification fields correctly' do
    assert CriterionFieldValidator.justification_field?(:contribution_justification)
    assert CriterionFieldValidator.justification_field?(:license_location_justification)
    assert_not CriterionFieldValidator.justification_field?(:contribution_status)
    assert_not CriterionFieldValidator.justification_field?(:name)
  end

  test 'status_to_justification_field converts correctly' do
    result = CriterionFieldValidator.status_to_justification_field(:contribution_status)
    assert_equal :contribution_justification, result

    result = CriterionFieldValidator.status_to_justification_field(:license_location_status)
    assert_equal :license_location_justification, result
  end
end
