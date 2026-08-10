# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'application_system_test_case'

class FilterTest < ApplicationSystemTestCase
  # rubocop:disable Metrics/BlockLength
  test 'Can Filter Projects' do
    visit '/en/projects'
    assert_text 'Add New Project'
    assert_equal 7, all('tbody tr').count
    assert_text '7 Projects'
    assert_text 'Pathfinder OS'
    assert_text 'Mars Ascent Vehicle (MAV)'
    assert_text 'Another Ascent Vehicle (AAV)'
    assert_text 'Unjustified perfect project'
    assert_text 'Justified perfect passing project'
    assert_text 'Justified perfect silver project'
    assert_text 'Justified perfect project'

    # We would *like* to be able to use the select... wait_for_url pattern to
    # more accurately test the UI.  However, for security reasons
    # we use a Content Security Policy (CSP) that disables embedded JavaScript.
    # This CSP setting causes select...wait to fail in some environments.
    # We *want* to use CSP to harden the software, and we need to make
    # sure that our tests run while CSP is enabled.
    # So instead, we directly "visit" the pages; this doesn't test
    # the UI as thoroughly, but it has the advantage of actually working :-).
    #
    # select 'Passing', from: 'gteq'
    # wait_for_url '/projects?gteq=100'
    visit '/en/projects?gteq=100'
    assert_equal 3, all('tbody tr').count
    assert_text '3 Projects'
    assert has_no_content? 'Pathfinder OS'
    assert has_no_content? 'Mars Ascent Vehicle (MAV)'
    assert has_no_content? 'Another Ascent Vehicle (AAV)'
    assert has_no_content? 'Unjustified perfect project'
    assert_text 'Justified perfect passing project'
    assert_text 'Justified perfect silver project'
    assert_text 'Justified perfect project'

    # select 'In Progress (75% or more)', from: 'gteq'
    # wait_for_url '/projects?gteq=75'
    visit '/en/projects?gteq=75'
    assert_equal 4, all('tbody tr').count
    assert_text '4 Projects'
    assert has_no_content? 'Pathfinder OS'
    assert has_no_content? 'Mars Ascent Vehicle (MAV)'
    assert has_no_content? 'Another Ascent Vehicle (AAV)'
    assert_text 'Unjustified perfect project'
    assert_text 'Justified perfect passing project'
    assert_text 'Justified perfect silver project'
    assert_text 'Justified perfect project'

    # fill_in 'q', with: 'unjustified'
    # click_on 'Search'
    # wait_for_url '/projects?gteq=75&q=unjustified'
    visit '/en/projects?gteq=75&q=unjustified'
    assert_equal 1, all('tbody tr').count
    assert_text '1 Project'
    assert has_no_content? 'Pathfinder OS'
    assert has_no_content? 'Mars Ascent Vehicle (MAV)'
    assert has_no_content? 'Another Ascent Vehicle (AAV)'
    assert_text 'Unjustified perfect project'
    assert has_no_content? 'Justified perfect passing project'
    assert has_no_content? 'Justified perfect silver project'
    assert has_no_content? 'Justified perfect project'

    # fill_in 'q', with: ''
    # click_on 'Search'
    # wait_for_url '/projects?gteq=75'
    visit '/en/projects?gteq=75'
    assert_equal 4, all('tbody tr').count
    assert_text '4 Projects'
    assert has_no_content? 'Pathfinder OS'
    assert has_no_content? 'Mars Ascent Vehicle (MAV)'
    assert has_no_content? 'Another Ascent Vehicle (AAV)'
    assert_text 'Unjustified perfect project'
    assert_text 'Justified perfect passing project'
    assert_text 'Justified perfect silver project'
    assert_text 'Justified perfect project'

    # check 'lteq' # Click 'Exclude passing' checkbox
    # wait_for_url '/projects?gteq=75&lteq=99'
    visit '/en/projects?gteq=75&lteq=99'
    assert_equal 1, all('tbody tr').count
    assert_text '1 Project'
    assert has_no_content? 'Pathfinder OS'
    assert has_no_content? 'Mars Ascent Vehicle (MAV)'
    assert has_no_content? 'Another Ascent Vehicle (AAV)'
    assert_text 'Unjustified perfect project'
    assert has_no_content? 'Justified perfect passing project'
    assert has_no_content? 'Justified perfect silver project'
    assert has_no_content? 'Justified perfect project'

    # No UI to use status params
    visit '/en/projects?status=in_progress'
    # wait_for_url '/projects?status=in_progress'
    assert_equal 4, all('tbody tr').count
    assert_text '4 Projects'
    assert_text 'Pathfinder OS'
    assert_text 'Mars Ascent Vehicle (MAV)'
    assert_text 'Another Ascent Vehicle (AAV)'
    assert_text 'Unjustified perfect project'
    assert has_no_content? 'Justified perfect passing project'
    assert has_no_content? 'Justified perfect silver project'
    assert has_no_content? 'Justified perfect project'

    # check that old search system is working and returns expected results
    visit '/en/projects?pq=Pathfinder'
    assert_equal 1, all('tbody tr').count
    assert_text '1 Project'
    assert_text 'Pathfinder OS'
    assert has_no_content? 'Mars Ascent Vehicle (MAV)'
    assert has_no_content? 'Another Ascent Vehicle (AAV)'
    assert has_no_content? 'Unjustified perfect project'
    assert has_no_content? 'Justified perfect passing project'
    assert has_no_content? 'Justified perfect silver project'
    assert has_no_content? 'Justified perfect project'

    # check results from normal search system
    visit '/en/projects?q=Pathfinder'
    assert_equal 2, all('tbody tr').count
    assert_text '2 Projects'
    assert_text 'Pathfinder OS'
    assert_text 'Mars Ascent Vehicle (MAV)'
    assert has_no_content? 'Another Ascent Vehicle (AAV)'
    assert has_no_content? 'Unjustified perfect project'
    assert has_no_content? 'Justified perfect passing project'
    assert has_no_content? 'Justified perfect silver project'
    assert has_no_content? 'Justified perfect project'
  end
  # rubocop:enable Metrics/BlockLength
end
