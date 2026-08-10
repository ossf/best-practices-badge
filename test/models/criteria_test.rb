# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# rubocop:disable Metrics/ClassLength
class CriteriaTest < ActiveSupport::TestCase
  test 'Criteria should have floss_license_osi' do
    assert Criteria['0'][:floss_license_osi]
  end

  test 'Criteria "contribution" is in the category MUST' do
    assert_equal 'MUST', Criteria['0'][:contribution].category
  end

  test 'Criteria "contribution_requirements" is in the category SHOULD' do
    assert_equal 'SHOULD', Criteria['0'][:contribution_requirements].category
  end

  test 'Criteria#all' do
    assert_includes Criteria.all, :contribution
  end

  test 'Criteria.active("0")' do
    active = Criteria.active('0').map(&:name)
    assert_includes active, :contribution
    assert_not_includes active, :hardening
  end

  test 'Criteria#keys' do
    assert_includes Criteria.keys, '0'
    assert_includes Criteria.keys, '1'
    assert_includes Criteria.keys, '2'
  end

  test 'Reasonable number of criteria in each level' do
    assert Criteria['0'].count > 40
    assert Criteria['1'].count > 20
    assert Criteria['2'].count > 10
  end

  test '#details_present?' do
    assert Criteria['0'][:description_good].details_present?
    assert_not Criteria['0'][:version_tags].details_present?
  end

  test 'Ensure details can be pulled from a lower level' do
    assert_not I18n.exists?('criteria.2.bus_factor.details')
    assert Criteria['2'][:bus_factor].details_present?
  end

  test 'Ensure that only allowed fields are in Criteria' do
    allowed_set = Set.new %i[
      category future obsolete na_allowed met_url_required met_justification_required
      na_justification_required met_suppress unmet_suppress autofill
      major minor rationale
    ]
    Criteria.to_h.each_value do |criteria_set|
      criteria_set.each_value do |fields|
        fields.each_key { |k| assert_includes allowed_set, k.to_sym }
      end
    end
  end

  test 'Ensure that only allowed fields are in Criteria translations' do
    allowed_set = Set.new %w[
      description details met_placeholder unmet_placeholder na_placeholder
    ]
    # Get all criteria levels - works with both flat and nested backends
    levels = Translations.get_translation_keys('criteria')
    levels.each do |level|
      criteria_names = Translations.get_translation_keys("criteria.#{level}")
      criteria_names.each do |criterion|
        fields = Criteria.get_criterion_keys(level.to_s, criterion.to_s)
        fields.each { |k| assert_includes allowed_set, k.to_s }
      end
    end
  end

  test 'Ensure that required fields are in Criteria and English translation' do
    required_set = Set.new %i[category major minor]
    Criteria.to_h.each do |level, criteria_set|
      # Skip baseline levels - they are in early development
      next if level.to_s.start_with?('baseline-')

      criteria_set.each do |criterion, fields|
        assert I18n.exists?(
          "criteria.#{level}.#{criterion}.description", :en
        )
        required_set.each do |required_field|
          assert_includes fields.keys, required_field.to_s
        end
      end
    end
  end

  test 'All Criteria in each level have a description' do
    Criteria.each do |level, criteria_set|
      # Skip baseline levels - they are in early development
      next if level.to_s.start_with?('baseline-')

      criteria_set.each_value do |criterion|
        assert criterion.description.present?
      end
    end
  end

  test 'Ensure Criteria data is sane' do
    allowed_field_values = %w[MUST SHOULD SUGGESTED]
    Criteria.to_h.each_value do |criteria_set|
      criteria_set.each_value do |fields|
        assert_includes allowed_field_values, fields['category'],
                        'only valid categories may be in Criteria'
        assert_not fields[:met_url_required] && fields[:met_suppress],
                   'If URL required, do not suppress justification'
        assert_not fields[:met_justification_required] && fields[:met_suppress],
                   'If Met justification required, must allow justification'
        assert_not fields[:na_justification_required] && fields[:met_suppress],
                   'If N/A justification required, must allow justification'
      end
    end
  end

  test 'Sample values correct for specific criteria' do
    assert Criteria['0'][:contribution].met_url_required?
    assert_not Criteria['0'][:floss_license_osi].met_url_required?

    assert Criteria['0'][:description_good].must?
    assert_not Criteria['0'][:contribution_requirements].must?

    assert Criteria['0'][:contribution_requirements].should?
    assert_not Criteria['0'][:description_good].should?

    assert Criteria['0'][:static_analysis].na_justification_required?
    assert_not Criteria['0'][:repo_distributed].na_justification_required?
  end

  # The "badge_percentage" and related values are currently integers 0..100;
  # that won't work well if we have > 100 criteria.
  # We can change the code later to address this; for now, let's make sure
  # the software stays within the limitation
  test 'No more than 100 criteria in each level' do
    Criteria.each_value do |criteria_set|
      assert criteria_set.keys.length <= 100
    end
  end

  test 'No nil values in Criteria.for_js' do
    assert_equal '', key_with_nil_value(Criteria.for_js)
  end
end
# rubocop:enable Metrics/ClassLength
