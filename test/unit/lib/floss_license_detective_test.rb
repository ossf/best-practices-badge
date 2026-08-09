# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

class FlossLicenseDetectiveTest < ActiveSupport::TestCase
  setup do
    # @user = User.new(name: 'Example User', email: 'user@example.com',
    #                 password: 'p@$$w0rd', password_confirmation: 'p@$$w0rd')
  end

  test 'MIT is OSS' do
    results = FlossLicenseDetective.new.analyze(nil, license: 'MIT')

    assert results.key?(:floss_license_osi_status)
    assert results[:floss_license_osi_status].key?(:value)
    assert results[:floss_license_osi_status][:value] == CriterionStatus::MET
    assert results[:floss_license_osi_status][:confidence] == 5

    assert results.key?(:floss_license_status)
    assert results[:floss_license_status].key?(:value)
    assert results[:floss_license_status][:value] == CriterionStatus::MET
    assert results[:floss_license_status][:confidence] == 5

    # Also checks baseline criteria (license meets OSI/FSF definition)
    assert results.key?(:osps_le_02_01_status)
    assert results[:osps_le_02_01_status][:value] == CriterionStatus::MET
    assert results[:osps_le_02_01_status][:confidence] == 5
  end

  test 'GPL-2.0+ is OSS' do
    results = FlossLicenseDetective.new.analyze(nil, license: 'GPL-2.0+')

    assert results.key?(:floss_license_osi_status)
    assert results[:floss_license_osi_status].key?(:value)
    assert results[:floss_license_osi_status][:value] == CriterionStatus::MET
    assert results[:floss_license_osi_status][:confidence] == 5

    assert results.key?(:floss_license_status)
    assert results[:floss_license_status].key?(:value)
    assert results[:floss_license_status][:value] == CriterionStatus::MET
    assert results[:floss_license_status][:confidence] == 5
  end

  test 'Apache-2.0 is OSS' do
    results = FlossLicenseDetective.new.analyze(nil, license: 'Apache-2.0')

    assert results.key?(:floss_license_osi_status)
    assert results[:floss_license_osi_status].key?(:value)
    assert results[:floss_license_osi_status][:value] == CriterionStatus::MET
    assert results[:floss_license_osi_status][:confidence] == 5

    assert results.key?(:floss_license_status)
    assert results[:floss_license_status].key?(:value)
    assert results[:floss_license_status][:value] == CriterionStatus::MET
    assert results[:floss_license_status][:confidence] == 5
  end

  test 'PROPRIETARY is probably not OSI-approved' do
    results = FlossLicenseDetective.new.analyze(nil, license: 'PROPRIETARY')

    assert results.key?(:floss_license_osi_status)
    assert results[:floss_license_osi_status].key?(:value)
    assert results[:floss_license_osi_status][:value] == CriterionStatus::UNMET
  end

  test 'Assume nothing for complicated situations' do
    results = FlossLicenseDetective.new.analyze(
      nil, license: '(GPL-2.0 WITH CLASSPATH'
    )
    assert results == {}
  end
end
