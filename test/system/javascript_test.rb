# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'application_system_test_case'

class JavascriptTest < ApplicationSystemTestCase
  CHECK = /result_symbol_check/
  QUESTION = /result_symbol_question/

  setup do
    @project_passing = projects(:perfect_passing)
    @user = users(:test_user)
    @project = projects(:one)
  end

  test 'Check show/hide Met on show for passing' do
    visit project_path(@project_passing, locale: :en)
    wait_for_page_load
    find('#toggle-expand-all-panels').click
    wait_for_jquery
    assert_selector(:css, '#discussion')
    assert_selector(:css, '#english')
    assert_selector(:css, '#contribution')
    assert_selector(:css, '#repo_public')
    assert_selector(:css, '#report_process')
    find('#toggle-hide-metna-criteria').click
    wait_for_jquery
    refute_selector(:css, '#discussion')
    refute_selector(:css, '#english')
    refute_selector(:css, '#contribution')
    refute_selector(:css, '#repo_public')
    refute_selector(:css, '#report_process')
  end

  test 'Check show/hide Met works for silver' do
    visit project_section_path(@project_passing, 'silver', locale: :en)
    wait_for_page_load
    find('#toggle-expand-all-panels').click
    wait_for_jquery
    assert_selector(:css, '#contribution_requirements')
    assert_selector(:css, '#report_tracker')
    assert_selector(:css, '#warnings_strict')
    find('#toggle-hide-metna-criteria').click
    wait_for_jquery
    refute_selector(:css, '#contribution_requirements')
    refute_selector(:css, '#report_tracker')
    refute_selector(:css, '#warnings_strict')
  end

  test 'Can edit baseline-1 form with JavaScript updates' do
    # Log in as test_user who owns the project
    visit projects_path(locale: :en)
    click_on 'Login'
    fill_in 'Email', with: @user.email
    fill_in 'Password', with: 'password'
    click_button 'Log in using custom account'
    assert_text 'Logged in!'

    # Visit the baseline-1 edit page directly
    visit "/en/projects/#{@project.id}/baseline-1/edit"
    wait_for_page_load

    # Expand all panels to ensure proper initialization
    find('#toggle-expand-all-panels').click
    # Wait for jQuery to finish, which includes panel expansion animations
    wait_for_jquery

    # Wait for the radio button to be present, visible, and interactable
    # Use a more robust wait that ensures the element is truly ready
    assert_selector '#project_osps_ac_01_01_status_met', visible: true, wait: 10

    # Get initial panel count - automation may fill some criteria on first edit
    initial_panel_text = find('#controls .satisfaction-text').text
    # Extract the number filled (e.g., "4/24" -> 4)
    initial_filled = initial_panel_text.match(%r{^(\d+)/\d+$})[1].to_i

    # Get initial progress bar percentage
    initial_progress = find('.badge-progress').text

    # Find the first baseline criterion (osps_ac_01_01) and verify it starts
    # with question mark icon (automation doesn't fill osps_ac_01_01)
    first_criterion_icon = find('#osps_ac_01_01_enough')
    assert_match QUESTION, first_criterion_icon['src'],
                 'Criterion should start with question mark icon'

    # Click the "Met" radio button for the first baseline criterion
    # Use ensure_choice to handle potential flaky clicks
    ensure_choice 'project_osps_ac_01_01_status_met'
    wait_for_jquery

    # Verify the criterion result icon changed to check mark
    first_criterion_icon = find('#osps_ac_01_01_enough')
    assert_match CHECK, first_criterion_icon['src'],
                 'Criterion icon should change to check mark'

    # Verify panel count increased by 1
    new_panel_text = find('#controls .satisfaction-text').text
    new_filled = new_panel_text.match(%r{^(\d+)/\d+$})[1].to_i
    assert_equal initial_filled + 1, new_filled,
                 'Panel count should have increased by 1'

    # Verify progress bar increased from initial value
    new_progress = find('.badge-progress').text
    assert_not_equal initial_progress, new_progress,
                     "Progress bar should have increased from #{initial_progress}"
    assert_match(/^\d+%$/, new_progress,
                 'Progress bar should be a percentage')
  end
end
