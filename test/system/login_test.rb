# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'application_system_test_case'

include ActionView::Helpers::TextHelper

# rubocop:disable Metrics/ClassLength
class LoginTest < ApplicationSystemTestCase
  CHECK = /result_symbol_check/
  DASH = /result_symbol_dash/
  QUESTION = /result_symbol_question/
  X = /result_symbol_x/

  setup do
    # FastlyRails is no longer in use.
    # FastlyRails.configure do |c|
    #   c.purging_enabled = true
    # end
    @user = users(:test_user)
    @project = projects(:one)
  end

  # teardown do
  #   FastlyRails.configure do |c|
  #     c.purging_enabled = false
  #   end
  # end

  # Test this with larger integration, to increase confidence that
  # we really do reject correct local usernames with wrong passwords
  test 'Cannot login with local username and wrong password' do
    visit projects_path(locale: :en)
    click_on 'Login'
    fill_in 'Email', with: @user.email
    fill_in 'Password', with: 'WRONG_PASSWORD'
    click_button 'Log in using custom account'
    assert_text 'Invalid email/password combination'
    assert_equal login_path(locale: :en), current_path
  end

  # Test this with larger integration, to increase confidence that
  # we really do reject correct local usernames with blank passwords
  test 'Cannot login with local username and blank password' do
    visit projects_path(locale: :en)
    click_on 'Login'
    fill_in 'Email', with: @user.email
    # NOTE: we do NOT fill in a password.
    click_button 'Log in using custom account'
    assert_text 'Invalid email/password combination'
    assert_equal login_path(locale: :en), current_path
  end

  # rubocop:disable Metrics/BlockLength
  test 'Can login and edit using custom account' do
    visit projects_path(locale: :en)
    click_on 'Login'
    fill_in 'Email', with: @user.email
    fill_in 'Password', with: 'password'
    click_button 'Log in using custom account'
    assert_text 'Logged in!'
    assert_equal projects_path(locale: :en), current_path

    # Visit the passing level edit page directly (with explicit criteria_level)
    visit "/en/projects/#{@project.id}/passing/edit"
    # Wait for page to be ready by checking for presence of form element
    assert_selector 'input#project_name'
    assert_text 'This is not the production system'
    assert_text 'We have updated our requirements for the criterion ' \
                'static_analysis. Please add a justification for ' \
                'this criterion.'

    fill_in 'project_name', with: 'It does not matter'
    # Click the "Save (and continue)" button to stay on edit page
    # Use match: :first because there are multiple save buttons (one per section)
    click_button('Save (and continue)', match: :first)
    # After routing changes, edit paths now include criteria_level
    assert_equal "/en/projects/#{@project.id}/passing/edit", current_path
    # Use assert_text which waits for content to appear (event-based waiting)
    assert_text 'Project was successfully updated.'
    # TODO: Get the clicking working again with capybara.
    # Details: If we expand all panels first and dont click this test passes.
    #          If we instead click each section, Capybara has issues not seen
    #          in real world scenarios, mainly it doesn't correctly identify
    #          an elements parents, leading to errors.
    kill_sticky_headers # This is necessary for Chrome and Firefox
    # Expand all panels first to ensure proper initialization
    find('#toggle-expand-all-panels').click
    wait_for_jquery
    # NOTE: After routing changes, form state may be different
    ensure_choice 'project_discussion_status_unmet'
    wait_for_jquery # Wait for page to complete update of status icon
    assert_match X, find('#discussion_enough')['src']

    ensure_choice 'project_english_status_met'
    wait_for_jquery
    assert_match CHECK, find('#english_enough')['src']

    ensure_choice 'project_contribution_status_met' # No URL given, so fails
    wait_for_jquery
    assert_match QUESTION, find('#contribution_enough')['src']
    fill_in 'project_contribution_justification',
            with: 'For more information see: http://www.example.org/'
    wait_for_jquery
    assert_match CHECK, find('#contribution_enough')['src']

    ensure_choice 'project_contribution_requirements_status_unmet' # No URL
    wait_for_jquery
    assert_match QUESTION, find('#contribution_requirements_enough')['src']

    # Since we expanded all panels, #repo_public is already visible
    assert_selector(:css, '#repo_public')
    ensure_choice 'project_repo_public_status_unmet'
    wait_for_jquery
    assert_match X, find('#repo_public_enough')['src']

    assert find('#project_repo_distributed_status_')['checked']
    ensure_choice 'project_repo_distributed_status_unmet' # SUGGESTED, so enough
    assert find('#project_repo_distributed_status_unmet')['checked']
    wait_for_jquery
    assert_match DASH, find('#repo_distributed_enough')['src']

    # All panels already expanded
    assert_selector(:css, '#report_process')
    ensure_choice 'project_report_process_status_unmet'
    wait_for_jquery
    assert_match X, find('#report_process_enough')['src']

    assert_selector(:css, '#english')
    find('#toggle-hide-metna-criteria').click
    wait_for_jquery
    refute_selector(:css, '#english')

    click_on('Submit', match: :first)
    assert_match X, find('#discussion_enough')['src']
  end
  # rubocop:enable Metrics/BlockLength

  test 'Can Login custom where GitHub account has same email' do
    # Make GitHub account have same email address as custom account
    @github_user = users(:github_user)
    @github_user.email = @user.email
    @github_user.save!
    # Now have custom account log in.
    visit projects_path(locale: :en)
    click_on 'Login'
    fill_in 'Email', with: @user.email
    fill_in 'Password', with: 'password'
    click_button 'Log in using custom account'
    assert_text 'Logged in!'
    assert_equal projects_path(locale: :en), current_path
  end

  # Test if we switch to user's preferred locale on login.
  # Here we test on a path that isn't the root.
  test 'Can Login in fr locale to /projects' do
    fr_user = users(:fr_user)
    visit projects_path(locale: :en)
    click_on 'Login'
    fill_in 'Email', with: fr_user.email
    fill_in 'Password', with: 'password'
    click_button 'Log in using custom account'
    assert_text 'Connecté !'
    assert_equal '/fr/projects', current_path
  end

  # Test login from root path.
  test 'Can Login in fr locale to top' do
    fr_user = users(:fr_user)
    visit root_path(locale: :en)
    click_on 'Login'
    fill_in 'Email', with: fr_user.email
    fill_in 'Password', with: 'password'
    click_button 'Log in using custom account'
    assert_text 'Connecté !'
    assert_equal '/fr', current_path
  end

  # Test login from non-english locale
  test 'Prelogin non-en locale saved on login' do
    fr_user = users(:fr_user)
    visit '/fr'
    click_on "S'identifier"
    fill_in 'Email', with: fr_user.email
    fill_in 'Mot de passe', with: 'password'
    click_button 'Connectez-vous en utilisant un compte personnalisé'
    assert_text 'Connecté !'
    assert_equal '/fr', current_path
  end
end
# rubocop:enable Metrics/ClassLength
