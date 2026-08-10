# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'application_system_test_case'

class AccessHomeTest < ApplicationSystemTestCase
  test 'sanity' do
    visit root_path(locale: :en)
    assert_text 'OpenSSF Best Practices Badge Program'
  end

  test 'New Project link' do
    visit root_path(locale: :en)
    assert_text 'Get Your Badge Now!'
  end

  test 'Header has links' do
    visit root_path(locale: :en)
    # use an id to ensure we are referring to the correct one
    assert find('#projects_page').visible?
    assert find_link('Sign Up').visible?
    assert find_link('Login').visible?
  end
end
