# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

class BlankDetectiveTest < ActiveSupport::TestCase
  setup do
    # @user = User.new(name: 'Example User', email: 'user@example.com',
    #                 password: 'p@$$w0rd', password_confirmation: 'p@$$w0rd')
  end

  test 'Blank' do
    results = BlankDetective.new.analyze(
      nil, license: '(GPL-2.0 WITH CLASSPATH'
    )
    assert results == {}
  end
end
