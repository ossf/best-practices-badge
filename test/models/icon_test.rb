# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

class IconTest < ActiveSupport::TestCase
  test 'Icons exist' do
    assert Icon.keys.length >= 10
  end

  test 'fa-edit icon exists and will not be escaped' do
    result = Icon[:'fa-edit']
    assert result.present?
    assert result.length > 10
    # rubocop: disable-next Rails/OutputSafety
    assert_equal result, ''.html_safe + result
  end
end
