# frozen_string_literal: true

# Copyright the Linux Foundation, IDA,
# and the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'application_system_test_case'

class RobotsContentsTest < ApplicationSystemTestCase
  test 'robots.txt on nonproduction site' do
    # The tests never set ENV['PUBLIC_HOSTNAME'] to the production site value.
    visit '/robots.txt'
    assert_text 'User-Agent: *'
    assert_not has_content? 'Allow: /'
    assert_text 'Disallow: /'
  end
end

# Historically we tested the contents of robots.txt for both
# true production and the other sites as separate system tests.
# However, it's tricky to do this as a system test;
# you have to modify the environment variable & clear the cache.
# This makes the tests not able to run in parallel within a process.
# It would be better to implement one as a unit test (if desired)
# so we don't need to modify the environment variables (which are shared).
#
# Robots.txt is cached, since it usually is unchanged in execution.
# We must clear the cache so we can test under different circumstances.
#
# class RobotsProductionTest < CapybaraFeatureTest
#   setup do
#     Rails.cache.clear
#     ENV['PUBLIC_HOSTNAME'] = 'bestpractices.coreinfrastructure.org'
#   end
#
#   teardown do
#     ENV['PUBLIC_HOSTNAME'] = ''
#   end
#
#   scenario 'robots.txt on production site' do
#     visit '/robots.txt'
#     assert_text 'User-Agent: *'
#     assert_text 'Allow: /'
#     assert_text 'Disallow: /users'
#     # Directly check for locales used by EU countries, ensure they're there
#     assert_text 'Disallow: /en/users'
#     assert_text 'Disallow: /fr/users'
#     assert_text 'Disallow: /de/users'
#     # Loop through all locales (make sure we didn't miss one)
#     I18n.available_locales.each do |loc|
#       assert_text "Disallow: /#{loc}/users"
#     end
#   end
# end
