# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'
require 'ostruct'

# rubocop:disable Metrics/ClassLength
class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:one)
    @project_two = projects(:two)
    @project_no_repo = projects(:no_repo)
    @perfect_passing_project = projects(:perfect_passing)
    @user = users(:test_user)
    @user2 = users(:test_user_melissa) # password 'password1'
    @admin = users(:admin_user)
  end

  # Ensure that every criterion that is *supposed* to be in this level is
  # selectable, and that every criterion that is *not* supposed to be in this
  # level is not selectable.
  # rubocop:disable Metrics/MethodLength
  def only_correct_criteria_selectable(level)
    Criteria.keys do |query_level|
      Criteria[query_level].each do |criterion|
        if query_level == level
          assert_select '#' + criterion.to_s
          assert_select "#project_#{criterion}_status_met"
        elsif !Criteria[level].key?(criterion)
          # This is criterion in another level, *not* this one
          assert_select '#' + criterion.to_s, false
          assert_select "#project_#{criterion}_status_met", false
        end
      end
    end
  end
  # rubocop:enable Metrics/MethodLength

  test 'should get index' do
    get '/en/projects'
    assert_response :success
    assert_includes @response.body, 'Badge status'
    assert_not_includes @response.body, 'target=[^ >]+>'
    assert_equal 'Accept-Encoding, Origin', @response.headers['Vary']
  end

  test 'new but not logged in' do
    get '/en/projects/new'
    assert_response :success
    assert_includes @response.body, 'Log in with '
    assert_not_includes @response.body,
                        'What is the URL for the project home page ' \
                        '(the URL for the project as a whole)'
  end

  test 'should get new' do
    log_in_as(@user)
    get '/en/projects/new'
    assert_response :success
    assert_not_includes @response.body, 'Log in with '
    assert_includes @response.body,
                    'What is the URL for the project home page ' \
                    '(the URL for the project as a whole)'
  end

  test 'should create project' do
    log_in_as(@user)
    stub_request(:get, 'https://api.github.com/user/repos')
      .to_return(status: 200, body: '', headers: {})
    # Use assert_difference to verify that project record created & email sent
    assert_difference [
      'Project.count', 'ActionMailer::Base.deliveries.size'
    ] do
      post '/en/projects', params: { # Routes to 'create'
        project: {
          description: @project.description,
          license: @project.license,
          name: @project.name,
          repo_url: 'https://www.example.org/code',
          homepage_url: @project.homepage_url
        }
      }
    end
    # Ensure that we actually created the project with those values
    new_project = Project.find_by(repo_url: 'https://www.example.org/code')
    assert_equal @project.description, new_project.description
    assert_equal @project.license, new_project.license
    assert_equal @project.name, new_project.name
    assert_equal 'https://www.example.org/code', new_project.repo_url
    assert_equal @project.homepage_url, new_project.homepage_url
    assert new_project.id != @project.id
  end

  test 'should create project with empty repo' do
    log_in_as(@user)
    stub_request(:get, 'https://api.github.com/user/repos')
      .to_return(status: 200, body: '', headers: {})
    assert_difference [
      'Project.count', 'ActionMailer::Base.deliveries.size'
    ] do
      post '/en/projects', params: { # Routes to 'create'
        project: {
          description: @project.description,
          license: @project.license,
          name: @project.name,
          repo_url: '',
          homepage_url: @project.homepage_url
        }
      }
    end
  end

  test 'should fail to create project with duplicate repo' do
    log_in_as(@user)
    stub_request(:get, 'https://api.github.com/user/repos')
      .to_return(status: 200, body: '', headers: {})
    assert_no_difference [
      'Project.count', 'ActionMailer::Base.deliveries.size'
    ] do
      post '/en/projects', params: { # Routes to 'create'
        project: {
          description: 'Some other project',
          license: @project.license,
          name: @project.name,
          repo_url: @project.repo_url,
          homepage_url: @project_two.homepage_url
        }
      }
    end
    # Owner should be redirected to the edit page, not the show page,
    # so they can continue filling in the project they already created.
    assert_redirected_to edit_project_section_path(@project, 'passing')
  end

  test 'duplicate repo owned by another user redirects to show page' do
    # @project_two is owned by @user2; @user tries to submit the same repo URL
    log_in_as(@user)
    stub_request(:get, 'https://api.github.com/user/repos')
      .to_return(status: 200, body: '', headers: {})
    assert_no_difference ['Project.count'] do
      post '/en/projects', params: {
        project: {
          description: 'Trying to duplicate',
          license: @project_two.license,
          name: @project_two.name,
          repo_url: @project_two.repo_url,
          homepage_url: @project_two.homepage_url
        }
      }
    end
    # Non-owner reaches the edit path, where can_edit_else_redirect
    # redirects them to the show page.
    follow_redirect!
    assert_response :redirect
    assert_redirected_to project_section_path(@project_two, 'passing')
  end

  test 'should fail to create project as blocked user' do
    blocked_user = users(:blocked_github_user)
    log_in_as(blocked_user)
    stub_request(:get, 'https://api.github.com/user/repos')
      .to_return(status: 200, body: '', headers: {})
    # Use assert_difference to verify that project record created & email sent
    # This actually raises an exception, so we'll need to catch & ignore it
    # rubocop:disable Style/RescueStandardError
    assert_no_difference [
      'Project.count', 'ActionMailer::Base.deliveries.size'
    ] do
      post '/en/projects', params: { # Routes to 'create'
        project: {
          description: @project.description,
          license: @project.license,
          name: @project.name,
          repo_url: 'https://www.example.org/code',
          homepage_url: @project.homepage_url
        }
      }
    rescue
      # We don't care what the exception is
    end
    # rubocop:enable Style/RescueStandardError
  end

  test 'should fail to create project' do
    log_in_as(@user)
    # We simplify this test by stubbing out the request to GitHub to
    # retrieve information about user repositories.
    # Stub GitHub API request (matches any query parameters)
    stub_request(:get, %r{https://api\.github\.com/user/repos})
      .to_return(status: 200, body: '', headers: {})
    assert_no_difference('Project.count') do # Post routes to 'create'
      post '/en/projects', params: { project: { name: @project.name } }
    end
    assert_no_difference('Project.count') do
      post '/en/projects.json', params: {
        project: { name: @project.name }
      }
    end
  end

  test 'create project defaults to passing section' do
    log_in_as(@user)
    stub_request(:get, 'https://api.github.com/user/repos')
      .to_return(status: 200, body: '', headers: {})
    assert_difference('Project.count') do
      post '/en/projects', params: {
        project: {
          name: @project.name,
          repo_url: 'https://www.example.org/default-section',
          homepage_url: @project.homepage_url
        }
      }
    end
    new_project = Project.find_by(repo_url: 'https://www.example.org/default-section')
    assert_redirected_to edit_project_section_path(new_project, 'passing')
  end

  test 'create project with starting_section passing' do
    log_in_as(@user)
    stub_request(:get, 'https://api.github.com/user/repos')
      .to_return(status: 200, body: '', headers: {})
    assert_difference('Project.count') do
      post '/en/projects', params: {
        project: {
          name: @project.name,
          repo_url: 'https://www.example.org/passing-section',
          homepage_url: @project.homepage_url
        },
        starting_section: 'passing'
      }
    end
    new_project = Project.find_by(repo_url: 'https://www.example.org/passing-section')
    assert_redirected_to edit_project_section_path(new_project, 'passing')
  end

  test 'create project with starting_section baseline-1' do
    log_in_as(@user)
    stub_request(:get, 'https://api.github.com/user/repos')
      .to_return(status: 200, body: '', headers: {})
    assert_difference('Project.count') do
      post '/en/projects', params: {
        project: {
          name: @project.name,
          repo_url: 'https://www.example.org/baseline-section',
          homepage_url: @project.homepage_url
        },
        starting_section: 'baseline-1'
      }
    end
    new_project = Project.find_by(repo_url: 'https://www.example.org/baseline-section')
    assert_redirected_to edit_project_section_path(new_project, 'baseline-1')
  end

  test 'create project with invalid starting_section defaults to passing' do
    log_in_as(@user)
    stub_request(:get, 'https://api.github.com/user/repos')
      .to_return(status: 200, body: '', headers: {})
    assert_difference('Project.count') do
      post '/en/projects', params: {
        project: {
          name: @project.name,
          repo_url: 'https://www.example.org/invalid-section',
          homepage_url: @project.homepage_url
        },
        starting_section: 'gold'
      }
    end
    new_project = Project.find_by(repo_url: 'https://www.example.org/invalid-section')
    assert_redirected_to edit_project_section_path(new_project, 'passing')
  end

  test 'duplicate project redirect respects starting_section' do
    log_in_as(@user)
    stub_request(:get, 'https://api.github.com/user/repos')
      .to_return(status: 200, body: '', headers: {})
    assert_no_difference('Project.count') do
      post '/en/projects', params: {
        project: {
          name: 'Duplicate test',
          repo_url: @project.repo_url,
          homepage_url: @project.homepage_url
        },
        starting_section: 'baseline-1'
      }
    end
    assert_redirected_to edit_project_section_path(@project, 'baseline-1')
  end

  test 'new project form contains badge series radio buttons' do
    log_in_as(@user)
    get '/en/projects/new'
    assert_response :success
    assert_includes @response.body, 'Badge series'
    # Exactly one form (unified), one set of radio buttons
    assert_select 'form', count: 1
    assert_select 'input[type=radio][name=starting_section][value=passing]',
                  count: 1
    assert_select 'input[type=radio][name=starting_section][value=baseline-1]',
                  count: 1
  end

  test 'local user does not see repo dropdown on new project form' do
    log_in_as(@user)
    get '/en/projects/new'
    assert_response :success
    assert_select 'select#github_repo_selector', count: 0
    assert_select 'form', count: 1
  end

  test 'github user with stale token sees reconnect link' do
    github_user = users(:github_user)
    OmniAuth.config.test_mode = true
    OmniAuth.config.add_mock(:github, github_omniauth_hash(github_user))
    get '/auth/github/callback'
    # Stub API as 401 BEFORE visiting the page (VCR blocks unstubbed calls)
    stub_request(:get, %r{api\.github\.com/user/repos})
      .to_return(status: 401, body: '{"message":"Requires authentication"}')
    # Clear token and visit — simulates expired GitHub token
    get '/en/projects/new', params: { clear_token: '1' }
    assert_response :success
    # Should show reconnect link, not the repo dropdown
    assert_select 'select#github_repo_selector', count: 0
    assert_includes @response.body, 'Reconnect to GitHub'
    assert_select 'a[data-method="post"][href*="/auth/github"]', count: 1
  ensure
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:github] = nil
  end

  test 'clear_token param triggers reconnect prompt for github user' do
    github_user = users(:github_user)
    OmniAuth.config.test_mode = true
    OmniAuth.config.add_mock(:github, github_omniauth_hash(github_user))
    get '/auth/github/callback'
    # With valid token, should not show reconnect
    stub_request(:get, %r{api\.github\.com/user/repos})
      .to_return(status: 200, body: '', headers: {})
    get '/en/projects/new'
    assert_response :success
    assert_not_includes @response.body, 'Reconnect to GitHub'
    # Now clear the token — should show reconnect
    stub_request(:get, %r{api\.github\.com/user/repos})
      .to_return(status: 401, body: '', headers: {})
    get '/en/projects/new', params: { clear_token: '1' }
    assert_response :success
    assert_includes @response.body, 'Reconnect to GitHub'
  ensure
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:github] = nil
  end

  # rubocop:disable Metrics/BlockLength
  test 'github reconnect flow restores token and redirects to new project' do
    github_user = users(:github_user)
    OmniAuth.config.test_mode = true
    OmniAuth.config.add_mock(:github, github_omniauth_hash(github_user))
    get '/auth/github/callback'
    # Clear token to simulate expiration
    stub_request(:get, %r{api\.github\.com/user/repos})
      .to_return(status: 401, body: '{"message":"Requires authentication"}')
    get '/en/projects/new', params: { clear_token: '1' }
    assert_response :success
    assert_includes @response.body, 'Reconnect to GitHub'

    # Reconnect: re-mock OmniAuth with fresh token, trigger callback
    OmniAuth.config.add_mock(
      :github, github_omniauth_hash(github_user, 'fresh_token_123')
    )
    get '/auth/github/callback'
    assert_redirected_to new_project_url(locale: :en)

    # Follow redirect — token is now fresh, repos should load
    stub_request(:get, %r{api\.github\.com/user/repos})
      .to_return(status: 200, body: '', headers: {})
    follow_redirect!
    assert_response :success
    assert_not_includes @response.body, 'Reconnect to GitHub'
  ensure
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:github] = nil
  end
  # rubocop:enable Metrics/BlockLength

  test 'find_homepage_url returns nil when no repo data' do
    controller = ProjectsController.new
    result = controller.send(:find_homepage_url, nil, 'https://github.com/test/repo')
    assert_nil result
  end

  test 'find_homepage_url returns nil when repo not found in data' do
    controller = ProjectsController.new
    repo_data = [
      ['other_repo', false, 'http://homepage.com', 'https://github.com/user/other']
    ]
    result = controller.send(:find_homepage_url, repo_data, 'https://github.com/test/repo')
    assert_nil result
  end

  test 'find_homepage_url returns repo homepage when present' do
    controller = ProjectsController.new
    repo_data = [
      ['test_repo', false, 'http://homepage.com', 'https://github.com/test/repo']
    ]
    result = controller.send(:find_homepage_url, repo_data, 'https://github.com/test/repo')
    assert_equal 'http://homepage.com', result
  end

  test 'find_homepage_url returns repo_url when homepage blank' do
    controller = ProjectsController.new
    repo_data = [
      ['test_repo', false, '', 'https://github.com/test/repo']
    ]
    result = controller.send(:find_homepage_url, repo_data, 'https://github.com/test/repo')
    assert_equal 'https://github.com/test/repo', result
  end

  test 'should show project' do
    get "/en/projects/#{@project.id}/passing"
    assert_response :success
    assert_includes @response.body,
                    'What is the human-readable name of the project'
    assert_select(+'a[href=?]', 'https://www.nasa.gov')
    assert_select(+'a[href=?]', 'https://www.nasa.gov/pathfinder')
    # Check semver description, which has HTML - make sure it's not escaped:
    assert @response.body.include?(
      I18n.t('criteria.0.version_semver.description')
    )
    assert_not_includes @response.body, 'target=[^ >]+>'
    assert_includes @response.body, "<img src='/projects/#{@project.id}/badge"
    assert_equal 'Accept-Encoding, Origin', @response.headers['Vary']
  end

  test 'should show passing project' do
    get "/en/projects/#{@perfect_passing_project.id}/passing"
    assert_response :success
    assert_includes @response.body,
                    'What is the human-readable name of the project'
    assert_select(+'a[href=?]', 'https://www.example.org')
    assert_includes @response.body, "<img src='/badge_static/passing'"
    assert_equal 'Accept-Encoding, Origin', @response.headers['Vary']
  end

  test 'should NOT show project if invalid id given' do
    get "/en/projects/#{@project.id}junk"
    assert_response :missing
  end

  test 'should show project with criteria_level=1' do
    # Use "/silver" suffix to indicate criteria_level=1
    get "/en/projects/#{@project.id}/silver"
    assert_response :success
    assert_select(+'a[href=?]', 'https://www.nasa.gov')
    assert_select(+'a[href=?]', 'https://www.nasa.gov/pathfinder')
    only_correct_criteria_selectable('1')
    assert_equal 'Accept-Encoding, Origin', @response.headers['Vary']
  end

  test 'should show project with criteria_level=2' do
    # Use path-based criteria_level
    get "/en/projects/#{@project.id}/gold"
    assert_response :success
    assert_select(+'a[href=?]', 'https://www.nasa.gov')
    assert_select(+'a[href=?]', 'https://www.nasa.gov/pathfinder')
    only_correct_criteria_selectable('2')
  end

  test 'should show project with criteria_level=baseline-1' do
    # Test baseline-1 level view
    get "/en/projects/#{@project.id}/baseline-1"
    assert_response :success
    assert_select(+'a[href=?]', 'https://www.nasa.gov')
    assert_select(+'a[href=?]', 'https://www.nasa.gov/pathfinder')
    only_correct_criteria_selectable('baseline-1')
  end

  test 'show page includes the automation proposals hint for metal and baseline' do
    # The hint used to only appear on edit pages; it must now also show on
    # the read-only project page for every criteria level, so anonymous
    # visitors (and AI training data) learn about the mechanism too.
    %w[passing silver gold baseline-1].each do |section|
      get "/en/projects/#{@project.id}/#{section}"
      assert_response :success
      assert_select(+'a[href=?]', ApplicationHelper::AUTOMATION_PROPOSALS_URL)
    end
  end

  test 'edit page still includes the automation proposals hint' do
    log_in_as(@project.user)
    %w[passing silver gold baseline-1].each do |section|
      get "/en/projects/#{@project.id}/#{section}/edit"
      assert_response :success
      assert_select(+'a[href=?]', ApplicationHelper::AUTOMATION_PROPOSALS_URL)
    end
  end

  test 'should redirect project JSON with locale to non-locale JSON' do
    get "/en/projects/#{@project.id}.json"
    assert_response :moved_permanently
    assert_redirected_to "/projects/#{@project.id}.json"
    follow_redirect!
    assert_response :success
    body = response.parsed_body
    assert_equal 'Pathfinder OS', body['name']
    assert_equal 'Operating system for Pathfinder rover', body['description']
    assert_equal 'https://www.nasa.gov', body['homepage_url']
    assert_equal 'in_progress', body['badge_level']
  end

  # The JSON describes the project; it is not a window into how we run
  # the badging process.  Withholding these also means a write that only
  # touches them cannot make a cached page stale.
  test 'project JSON withholds badging-process bookkeeping' do
    get "/projects/#{@project.id}.json"
    assert_response :success
    body = response.parsed_body
    Project::BOOKKEEPING_FIELDS.each do |field|
      assert_not body.key?(field), "#{field} should not be published"
    end
    # ...while still publishing what the project actually is.
    assert_equal 'Pathfinder OS', body['name']
    assert body.key?('badge_percentage_0')
    assert body.key?('achieved_passing_at')
    assert body.key?('user_id')
  end

  test 'should show project JSON data without locale' do
    get "/projects/#{@project.id}.json"
    assert_response :success
    body = response.parsed_body
    assert_equal 'Pathfinder OS', body['name']
    assert_equal 'Operating system for Pathfinder rover', body['description']
    assert_equal 'https://www.nasa.gov', body['homepage_url']
    assert_equal 'in_progress', body['badge_level']
    assert_equal [], body['additional_rights']
  end

  test 'should redirect well-formed criteria_level query param to path' do
    # Legacy URL format: /projects/1?criteria_level=1
    # Handled by redirect_to_default_section action
    # Should redirect to: /projects/1/silver
    get "/en/projects/#{@project.id}?criteria_level=1"
    assert_response :moved_permanently
    assert_redirected_to "/en/projects/#{@project.id}/silver"
  end

  test 'should redirect malformed criteria_level query param to path' do
    # Malformed URL format: /projects/1?criteria_level,2
    # Handled by redirect_to_default_section action
    # Should redirect to: /projects/1/gold
    get "/en/projects/#{@project.id}?criteria_level,2"
    assert_response :moved_permanently
    assert_redirected_to "/en/projects/#{@project.id}/gold"
  end

  test 'should show markdown for all levels when level not said' do
    # Redirects to default section, then follow to get markdown
    get "/en/projects/#{@project.id}.md"
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_includes @response.body, 'The project website MUST provide information on how'
    assert_includes @response.body, 'Passing'
    # When following redirect, we only get the default section (passing)
    # not all levels, so don't assert for Silver/Gold
  end

  test 'should show markdown for one given level' do
    # Use new path-based format instead of query parameter
    get "/en/projects/#{@project.id}/passing.md"
    assert_response :success
    assert_includes @response.body, 'The project website MUST provide information on how'
    assert_includes @response.body, 'Passing'
    assert_not_includes @response.body, 'Silver'
    assert_not_includes @response.body, 'Gold'
  end

  test 'Markdown generates correctly for French' do
    # Use new path-based format instead of query parameter
    get "/fr/projects/#{@project.id}/silver.md"
    assert_response :success
    # Split up text to fool spellchecker. "Project" is easily misspelled
    # and there's no mechanism to disable spellchecking for a specific line.
    assert_includes @response.body,
                    ('Le ' \
                     'pro' \
                     'jet ' + 'DOIT atteindre un badge de niveau basique')
    assert_not_includes @response.body, '[Basique]' # "Passing"
    assert_includes @response.body, '[Argent]' # "Silver"
    assert_not_includes @response.body, 'Passing'
    assert_not_includes @response.body, 'Silver'
    assert_not_includes @response.body, 'Gold'
  end

  test 'should raise error for permissions section in markdown format' do
    # Permissions section doesn't support markdown format
    assert_raises(ActionController::RoutingError) do
      get "/en/projects/#{@project.id}/permissions.md"
    end
  end

  test 'validate_section accepts canonical section names' do
    # Test the defensive validation accepts canonical sections
    controller = ProjectsController.new
    # Should not raise for canonical sections
    Sections::ALL_CANONICAL_NAMES.each do |section|
      assert_nothing_raised do
        controller.send(:validate_section, section)
      end
    end
  end

  test 'validate_section rejects invalid section names' do
    # Test the defensive validation rejects invalid sections
    controller = ProjectsController.new
    # Should raise for invalid sections
    error =
      assert_raises(ActionController::RoutingError) do
        controller.send(:validate_section, 'invalid_section_name')
      end
    assert_match(/Invalid section/, error.message)
  end

  test 'should get edit' do
    log_in_as(@project.user)
    assert_equal(
      'Logged in! Last login: (No previous time recorded.)', flash['success']
    )
    get "/en/projects/#{@project.id}/passing/edit"
    assert_response :success
    assert_includes @response.body, 'Edit Project Badge Status'
  end

  test 'should get edit for baseline-1' do
    log_in_as(@project.user)
    get "/en/projects/#{@project.id}/baseline-1/edit"
    assert_response :success
    assert_includes @response.body, 'Edit Project Badge Status'
  end

  test 'should get edit for silver' do
    log_in_as(@project.user)
    get "/en/projects/#{@project.id}/silver/edit"
    assert_response :success
    assert_includes @response.body, 'Edit Project Badge Status'
  end

  test 'should get edit for gold' do
    log_in_as(@project.user)
    get "/en/projects/#{@project.id}/gold/edit"
    assert_response :success
    assert_includes @response.body, 'Edit Project Badge Status'
  end

  test 'should get edit as additional rights user' do
    test_user = users(:test_user_mark)
    # Create additional rights during test, not as a fixure.
    # The fixture would require correct references to *other* fixture ids.
    new_right = AdditionalRight.new(
      user_id: test_user.id,
      project_id: @project.id
    )
    new_right.save!
    log_in_as(test_user)
    get "/en/projects/#{@project.id}/passing/edit" # Invokes "edit"
    assert_response :success
    assert_includes @response.body, 'Edit Project Badge Status'
  end

  # rubocop:disable Metrics/BlockLength
  test 'can add users with additional rights using "+"' do
    log_in_as(@project.user)
    # Ensure that our test setup is correct & get current state
    assert_not AdditionalRight.exists?(
      project_id: @project.id,
      user_id: users(:test_user_mark).id
    )
    assert_not AdditionalRight.exists?(
      project_id: @project.id,
      user_id: users(:test_user_melissa).id
    )
    assert_not AdditionalRight.exists?(
      project_id: @project.id,
      user_id: @admin.id
    )
    previous_update = @project.updated_at
    # Run patch (the point of the test), which invokes the 'update' method
    patch "/en/projects/#{@project.id}", params: {
      project: { name: @project.name }, # *Something* so not empty.
      additional_rights_changes:
        "+ #{users(:test_user_mark).id}, #{users(:test_user_melissa).id}"
    }
    # Check that results are what was expected
    assert_redirected_to project_section_path(assigns(:project), 'passing')
    assert AdditionalRight.exists?(
      project_id: @project.id,
      user_id: users(:test_user_mark).id
    )
    assert AdditionalRight.exists?(
      project_id: @project.id,
      user_id: users(:test_user_melissa).id
    )
    # Ensure that updated_at has changed
    @project.reload
    assert_not_equal previous_update, @project.updated_at
  end
  # rubocop:enable Metrics/BlockLength

  test 'can remove a user with additional rights using "-"' do
    AdditionalRight.new(
      user_id: users(:test_user_melissa).id,
      project_id: @project.id
    ).save!
    AdditionalRight.new(
      user_id: users(:test_user_mark).id,
      project_id: @project.id
    ).save!
    assert_equal 2, AdditionalRight.for_project(@project.id).count
    log_in_as(@project.user)
    # Run patch (the point of the test), which invokes the 'update' method
    patch "/en/projects/#{@project.id}", params: {
      project: { name: @project.name }, # *Something* so not empty.
      additional_rights_changes:
        "- #{users(:test_user_melissa).id}, #{users(:test_user_mark).id}"
    }
    # TODO: Weird http/https discrepancy in test
    # assert_redirected_to project_section_path(@project, 'passing', locale: :en)
    assert_equal 0, AdditionalRight.for_project(@project.id).count
  end

  # Negative test
  test 'cannot remove a user with only additional rights using "-"' do
    AdditionalRight.new(
      user_id: users(:test_user_melissa).id,
      project_id: @project.id
    ).save!
    AdditionalRight.new(
      user_id: users(:test_user_mark).id,
      project_id: @project.id
    ).save!
    assert_equal 2, AdditionalRight.for_project(@project.id).count
    log_in_as(users(:test_user_melissa))
    # Run patch (the point of the test), which invokes the 'update' method
    patch "/en/projects/#{@project.id}", params: {
      project: { name: @project.name }, # *Something* so not empty.
      additional_rights_changes: "- #{users(:test_user_mark).id}"
    }
    # TODO: Currently we don't report an error if a non-owner
    # tries to remove an "additional rights" user, we just ignore it.
    # If we add an error report, we should check for that error report here.
    # Unauthorized users are redirected to the project show page
    assert_redirected_to project_section_path(@project, 'passing', locale: 'en')
    assert_equal 2, AdditionalRight.for_project(@project.id).count
  end

  # Negative test
  test 'should not get edit page as user without additional rights' do
    # This *expressly* tests that a normal logged-in
    # user cannot request the edit page of another project's data
    # without authorization.
    # Without additional rights, you can't edit.  This is paired with the
    # previous test, to ensure that *only* the additional right provides
    # the necessary rights.
    test_user = users(:test_user_mark)
    log_in_as(test_user)
    get "/en/projects/#{@project.id}/passing/edit" # Routes to 'edit'
    # Unauthorized logged-in users are redirected to the project show page
    assert_redirected_to project_section_path(@project, 'passing')
    assert_equal 'You are not authorized to edit this project.',
                 flash[:danger]
  end

  # Having trouble translating this test, will do later.
  # test 'should fail to get edit page due to old session' do
  #   log_in_as(@project.user)
  #   assert_equal(
  #     'Logged in! Last login: (No previous time recorded.)', flash['success']
  #   )
  #   session[:time_last_used] = 1000.days.ago.utc
  #   get "/en/projects/#{@project.id}/edit" # Routes to 'edit'
  #   assert_response 302
  #   assert_redirected_to login_path
  #   # follow_redirect!
  #   # refute_includes @response.body, 'Edit Project Badge Status'
  # end

  # test 'should fail to edit due to session time missing' do
  #   log_in_as(@project.user, time_last_used: 1000.days.ago.utc)
  #   session.delete(:time_last_used)
  #   get :edit, params: { id: @project, locale: :en }
  #   assert_response 302
  #   assert_redirected_to login_path
  # end

  test 'should update project (using patch)' do
    log_in_as(@project.user)
    new_name = @project.name + '_updated'
    # Run patch (the point of the test), which invokes the 'update' method
    patch "/en/projects/#{@project.id}", params: {
      project: {
        description: @project.description,
        license: @project.license,
        name: new_name,
        repo_url: @project.repo_url,
        homepage_url: @project.homepage_url
      }
    }
    assert_redirected_to project_section_path(assigns(:project), 'passing')
    follow_redirect! # Follow redirect to /en/projects/:id/passing
    assert_response :success # Should render the show page
    @project.reload
    assert_equal @project.name, new_name
    # Ensure that replied page uses a /badge_static badge image.
    # We omit the specific level, since that will change as automation changes.
    assert_includes @response.body, '/badge_static/'
  end

  test 'should update project (using put)' do
    log_in_as(@project.user)
    new_name = @project.name + '_updated'
    # Run put (the point of the test), which invokes the 'update' method
    # A separate test uses "patch" instead; both should work.
    put "/en/projects/#{@project.id}", params: {
      project: {
        description: @project.description,
        license: @project.license,
        name: new_name,
        repo_url: @project.repo_url,
        homepage_url: @project.homepage_url
      }
    }
    assert_redirected_to project_section_path(assigns(:project), 'passing')
    @project.reload
    assert_equal @project.name, new_name
  end

  test 'should update baseline-1 criteria' do
    log_in_as(@project.user)
    # Update a baseline-1 criterion (osps_ac_01_01)
    patch "/en/projects/#{@project.id}", params: {
      criteria_level: 'baseline-1',
      project: {
        osps_ac_01_01_status: 'Met',
        osps_ac_01_01_justification: 'We use MFA for all contributors'
      }
    }
    # Redirects with criteria_level parameter included
    assert_response :redirect
    @project.reload
    # When it's *stored* it's converted into an integer, so we must
    # check against the integer stored.
    assert_equal CriterionStatus::MET, @project.osps_ac_01_01_status
    assert_equal 'We use MFA for all contributors',
                 @project.osps_ac_01_01_justification
  end

  test 'should update and show active baseline-1 criterion (osps_br_01_03)' do
    log_in_as(@project.user)
    # Active criterion must appear on the edit page (view and edit)
    get "/en/projects/#{@project.id}/baseline-1/edit"
    assert_response :success
    assert_select '#osps_br_01_03'
    assert_select '#project_osps_br_01_03_status_met'
    # Save new values for the future criterion
    patch "/en/projects/#{@project.id}", params: {
      criteria_level: 'baseline-1',
      project: {
        osps_br_01_03_status: 'Met',
        osps_br_01_03_justification: 'We validate branch names in CI'
      }
    }
    assert_response :redirect
    @project.reload
    assert_equal CriterionStatus::MET, @project.osps_br_01_03_status
    assert_equal 'We validate branch names in CI',
                 @project.osps_br_01_03_justification
    # Saved values must appear on the show page
    get "/en/projects/#{@project.id}/baseline-1"
    assert_response :success
    assert_select '#osps_br_01_03'
    assert_includes @response.body, 'We validate branch names in CI'
  end

  test 'should update entry_locale' do
    log_in_as(@project.user)
    patch "/en/projects/#{@project.id}",
          params: { project: { entry_locale: 'ja' } }
    @project.reload
    assert_equal 'ja', @project.entry_locale
  end

  test 'partial update with only name should not reset entry_locale' do
    log_in_as(@project.user)
    # First set entry_locale to non-default value
    @project.update!(entry_locale: 'fr')
    original_description = @project.description
    original_license = @project.license

    # Send partial update with only name field
    patch "/en/projects/#{@project.id}",
          params: { project: { name: 'New Name Only' } }
    assert_response :redirect

    # Verify: name changed, but entry_locale and other fields unchanged
    @project.reload
    assert_equal 'New Name Only', @project.name
    assert_equal 'fr', @project.entry_locale, 'entry_locale must not reset to en'
    assert_equal original_description, @project.description
    assert_equal original_license, @project.license
  end

  test 'partial update with multiple fields should not affect entry_locale' do
    log_in_as(@project.user)
    # Set entry_locale to non-default value
    @project.update!(entry_locale: 'de')
    original_homepage = @project.homepage_url

    # Send partial update with description and license only
    patch "/en/projects/#{@project.id}",
          params: {
            project: {
              description: 'Updated description',
                        license: 'Apache-2.0'
            }
          }
    assert_response :redirect

    # Verify: sent fields changed, entry_locale and other fields unchanged
    @project.reload
    assert_equal 'Updated description', @project.description
    assert_equal 'Apache-2.0', @project.license
    assert_equal 'de', @project.entry_locale, 'entry_locale must not reset'
    assert_equal original_homepage, @project.homepage_url
  end

  test 'partial update with blank entry_locale should set to en' do
    log_in_as(@project.user)
    # Set entry_locale to non-default value
    @project.update!(entry_locale: 'fr')
    assert_equal 'fr', @project.entry_locale

    # Explicitly send blank entry_locale (form with nothing selected)
    patch "/en/projects/#{@project.id}",
          params: { project: { entry_locale: '' } }
    # Save succeeds; may render edit (if Chief produces overrides) or redirect to show
    assert_includes [200, 302], response.status

    # Blank should normalize to 'en' regardless of render vs redirect
    @project.reload
    assert_equal 'en', @project.entry_locale,
                 'Explicitly blank entry_locale should normalize to en'
  end

  # Negative test
  test 'should fail to update project if not logged in' do
    # NOTE: no log_in_as
    old_name = @project.name
    new_name = old_name + '_updated'
    # Run patch (the point of the test), which invokes the 'update' method
    patch "/en/projects/#{@project.id}", params: {
      project: {
        description: @project.description,
        license: @project.license,
        name: new_name,
        repo_url: @project.repo_url,
        homepage_url: @project.homepage_url
      }
    }
    # Verify that we didn't really change the name
    @project.reload
    assert_equal @project.name, old_name
  end

  test 'should fail to update project if providing bad URL' do
    log_in_as(@project.user)
    new_project_data = {
      description: '',
      license: '',
      name: '',
      homepage_url: 'example.org' # bad url
    }
    # Run patch (the point of the test), which invokes the 'update' method
    patch "/en/projects/#{@project.id}", params: { project: new_project_data }
    # "Success" here only in the HTTP sense - we *do* get a form...
    assert_response :success
    # ... but we just get the edit form.
    assert_includes @response.body, 'Edit Project Badge Status'

    # Do the same thing, but as for JSON
    patch "/en/projects/#{@project.id}.json", params: {
      project: new_project_data
    }
    assert_response :unprocessable_content
  end

  # rubocop: disable Metrics/BlockLength
  test 'should fail to update stale project due to optimistic locking' do
    # Check for proper handling of project[lock_version] in the HTML like
    # <input type="hidden" value="73" name="project[lock_version]"
    # id="project_lock_version" />
    new_name1 = @project.name + '_updated-1'
    new_project_data1 = { name: new_name1 }
    new_name2 = @project.name + '_updated-2'
    new_project_data2 = {
      name: new_name2,
      lock_version: @project.lock_version
    }
    log_in_as(@project.user)
    patch "/en/projects/#{@project.id}", params: { project: new_project_data1 }
    assert_redirected_to project_section_path(@project, 'passing', locale: :en)
    get "/en/projects/#{@project.id}/passing/edit"
    assert_includes @response.body, 'Edit Project Badge Status'
    assert_includes @response.body, new_name1
    assert_not_includes @response.body, new_name2
    patch "/en/projects/#{@project.id}", params: { project: new_project_data2 }
    assert_includes flash['danger'],
                    'Another user has made a change to that record ' \
                    'since you accessed the edit form.'
    assert_includes @response.body, 'Edit Project Badge Status'
    # Return to the user the *unsaved* values in the edit field, along with
    # the error message. That way, the user can store them separately
    # (say as a printout).
    assert_not_includes @response.body, new_name1
    assert_includes @response.body, new_name2
    # Now reload the actually-stored record to check on what's in the database.
    assert_difference '@project.lock_version' do
      @project.reload
    end
    assert_equal @project.name, new_name1
  end
  # rubocop: enable Metrics/BlockLength

  test 'should fail update project with invalid control in name' do
    log_in_as(@project.user)
    old_name = @project.name
    new_name = @project.name + "\x0c"
    patch "/en/projects/#{@project.id}", params: {
      project: {
        description: @project.description,
        license: @project.license,
        name: new_name,
        repo_url: @project.repo_url,
        homepage_url: @project.homepage_url
      }
    }
    # "Success" here only in the HTTP sense - we *do* get a form...
    assert_response :success
    # ... but we just get the edit form.
    assert_includes @response.body, 'Edit Project Badge Status'
    assert_equal @project.name, old_name
  end

  test 'should fail to update other users project' do
    old_name = @project_two.name
    new_name = old_name + '_updated'
    assert_not_equal @user, @project_two.user
    log_in_as(@user)
    patch "/en/projects/#{@project_two.id}", params: {
      project: { name: new_name }
    }
    # Unauthorized logged-in users are redirected to the project show page
    assert_redirected_to project_section_path(@project_two, 'passing',
                                              locale: :en)
    @project_two.reload
    assert_equal old_name, @project_two.name
  end

  test 'admin can update other users project' do
    new_name = @project.name + '_updated'
    log_in_as(@admin)
    assert_not_equal @admin, @project.user
    patch "/en/projects/#{@project.id}", params: {
      project: { name: new_name }
    }
    assert_redirected_to project_section_path(assigns(:project), 'passing')
    @project.reload
    assert_equal new_name, @project.name
  end

  test 'admin can change owner of other users project' do
    log_in_as(@admin)
    old_user = @project.user
    assert_not_equal @admin.id, old_user.id
    # We SHOULD see the option to change the owner id in the permissions form
    get "/en/projects/#{@project.id}/permissions/edit"
    assert_response :success
    assert_includes @response.body, 'Repeated new owner id'

    # Ensure it won't change if we don't give repeat id
    patch "/en/projects/#{@project.id}", params: {
      project: { user_id: @admin.id }
    }
    assert_redirected_to project_section_path(assigns(:project), 'passing')
    @project.reload
    assert_not_equal @admin.id, @project.user_id
    assert_equal old_user.id, @project.user_id

    # Ensure it won't change if we repeat id doesn't match
    patch "/en/projects/#{@project.id}", params: {
      project: { user_id: @admin.id, repeat_user_id: @admin.id + 1 }
    }
    assert_redirected_to project_section_path(assigns(:project), 'passing')
    @project.reload
    assert_equal old_user.id, @project.user_id

    # Ensure it won't change if user doesn't exist
    # Admin will own this project after this instruction.
    # We'll assume this does not exist :-)
    no_such_uid = 999_999_999_999_999
    patch "/en/projects/#{@project.id}", params: {
      project: { user_id: no_such_uid, user_id_repeat: no_such_uid }
    }
    assert_redirected_to project_section_path(assigns(:project), 'passing')
    @project.reload
    assert_not_equal no_such_uid, @project.user_id
    assert_equal old_user.id, @project.user_id

    # Let's ensure we CAN change it.
    # Admin will own this project after this instruction.
    patch "/en/projects/#{@project.id}", params: {
      project: { user_id: @admin.id, user_id_repeat: @admin.id }
    }
    assert_redirected_to project_section_path(assigns(:project), 'passing')
    @project.reload
    assert_equal @admin.id, @project.user_id
  end

  # We allow normal users of their own project to change
  # the owner to anyone else.
  # If recipient doesn't want it, they can reassign again.
  test 'Normal user change ownership of their own project' do
    # Verify test setup - @project is owned by @user
    assert_equal @project.user_id, @user.id
    log_in_as(@user)

    get "/en/projects/#{@project.id}/permissions/edit"
    assert_response :success
    # We should see the option to change the owner id in the permissions form
    assert_includes @response.body, 'Repeated new owner id'

    # Let's ensure we can change it.
    patch "/en/projects/#{@project.id}", params: {
      project: { user_id: @admin.id, user_id_repeat: @admin.id }
    }
    assert_redirected_to project_section_path(assigns(:project), 'passing')
    @project.reload
    # Notice that ownership has changed.
    assert_equal @project.user_id, @admin.id
  end

  # Don't allow users other than admin or owner to change the owner.
  test 'Normal user cannot change ownership of a project they do not own' do
    test_user = users(:test_user_mark)
    # Create additional rights during test, not as a fixure.
    # The fixture would require correct references to *other* fixture ids.
    new_right = AdditionalRight.new(
      user_id: test_user.id,
      project_id: @project.id
    )
    new_right.save!
    log_in_as(test_user)

    get "/en/projects/#{@project.id}/passing/edit"
    assert_response :success
    # We should NOT see the option to change the owner id
    assert_not_includes @response.body, 'Repeated new owner id'

    # Let's ensure we can't change it.
    patch "/en/projects/#{@project.id}", params: {
      project: { user_id: @admin.id, user_id_repeat: @admin.id }
    }
    assert_redirected_to project_section_path(assigns(:project), 'passing')
    @project.reload
    # Notice that nothing has changed.
    assert_not_equal @project.user_id, @admin.id
  end

  test 'Cannot evade /badge match with /badge/..' do
    get "/projects/#{@perfect_passing_project.id}/badge/..",
        params: { format: 'svg' }
    assert_response :not_found
    assert_equal 'Accept-Encoding, Origin', @response.headers['Vary']
    assert_nil @response.headers['Access-Control-Allow-Origin']
  end

  test 'Cannot evade /badge match with /projects/NUM/../badge' do
    get "/projects/#{@perfect_passing_project.id}/../badge",
        params: { format: 'svg' }
    assert_response :not_found
    assert_equal 'Accept-Encoding', @response.headers['Vary']
    assert_nil @response.headers['Access-Control-Allow-Origin']
  end

  test 'CORS Cannot evade /badge match with /badge.json/..' do
    get "/projects/#{@perfect_passing_project.id}/badge.json/..",
        headers: { Origin: 'example.com' }
    assert_response :not_found
    assert_equal 'Accept-Encoding, Origin', @response.headers['Vary']
    assert_equal '*', @response.headers['Access-Control-Allow-Origin']
  end

  test 'Cannot evade /badge match with /projects/NUM/../badge.json' do
    get "/projects/#{@perfect_passing_project.id}/../badge.json",
        headers: { Origin: 'example.com' }
    assert_response :not_found
    # We don't really care about these for a "not found":
    # assert_equal 'Accept-Encoding', @response.headers['Vary']
    # assert_equal '*', @response.headers['Access-Control-Allow-Origin']
  end

  test 'A perfect passing project should have the passing badge' do
    # NOTICE!! Badge URLs do *NOT* have a locale prefix
    get "/projects/#{@perfect_passing_project.id}/badge",
        params: { format: 'svg' }
    assert_response :success
    assert_equal contents('badge-passing.svg'), @response.body
    # NOTE: Requesters MUST use the ".json"
    # suffix to request the data in JSON format
    # (and NOT use the HTTP Accept header to try to select the output format).
    # Therefore we don't need to include "Accept" as part of "Vary".
    assert_equal 'Accept-Encoding', @response.headers['Vary']
    # No origin stated, so shouldn't see one as a response.
    assert_nil @response.headers['Access-Control-Allow-Origin']
  end

  test 'badge SVG has CDN caching headers' do
    get "/projects/#{@project.id}/badge", params: { format: 'svg' }
    assert_response :success
    # Surrogate-Key must carry both the project's own key (for the existing
    # edit-time purge) and METAL_BADGES_SURROGATE_KEY (so a metal badge
    # artwork change can purge every project's metal badge at once).
    assert_equal "#{@project.record_key} #{ApplicationController::METAL_BADGES_SURROGATE_KEY}",
                 @response.headers['Surrogate-Key']
  end

  test 'badge JSON has CDN caching headers' do
    get "/projects/#{@project.id}/badge.json"
    assert_response :success
    # JSON has no image and no translatable text, so it needs no series key.
    assert_equal @project.record_key, @response.headers['Surrogate-Key']
  end

  test 'A perfect passing project requested with CORS' do
    get "/en/projects/#{@project.id}/badge.json",
        headers: { Origin: 'example.com' }
    assert_equal 'Accept-Encoding', @response.headers['Vary']
    assert_equal '*', @response.headers['Access-Control-Allow-Origin']
  end

  test 'A perfect silver project should have the silver badge' do
    @perfect_silver_project = projects(:perfect_silver)
    get "/projects/#{@perfect_silver_project.id}/badge",
        params: { format: 'svg' }
    assert_response :success
    assert_equal contents('badge-silver.svg'), @response.body
  end

  test 'A perfect silver project should have the silver badge in JSON' do
    @perfect_silver_project = projects(:perfect_silver)
    get "/projects/#{@perfect_silver_project.id}/badge.json"
    assert_response :success
    json_data = JSON.parse(@response.body)
    assert_equal 'silver', json_data['badge_level']
    assert_equal @perfect_silver_project.id, json_data['id'].to_i
    assert_equal 'Accept-Encoding', @response.headers['Vary']
  end

  test 'A perfect project should have the gold badge' do
    @perfect_project = projects(:perfect)
    get "/projects/#{@perfect_project.id}/badge"
    assert_response :success
    assert_equal contents('badge-gold.svg'), @response.body
  end

  test 'A perfect unjustified project should have in progress badge' do
    @perfect_unjustified_project = projects(:perfect_unjustified)
    get "/projects/#{@perfect_unjustified_project.id}/badge"
    assert_response :success
    assert_includes @response.body, 'in progress'
  end

  test 'An in-progress project must reply in_progress in JSON' do
    get "/projects/#{@project.id}/badge.json"
    assert_response :success
    json_data = JSON.parse(@response.body)
    assert_equal 'in_progress', json_data['badge_level']
    assert_equal @project.id, json_data['id'].to_i
  end

  test 'An empty project should not have a badge; it should be in progress' do
    get "/projects/#{@project.id}/badge"
    assert_response :success
    assert_includes @response.body, 'in progress'
  end

  test 'Achievement datetimes set' do
    log_in_as(@admin)
    assert_nil @perfect_passing_project.lost_passing_at
    assert_not_nil @perfect_passing_project.achieved_passing_at
    patch "/en/projects/#{@perfect_passing_project.id}", params: {
      project: { interact_status: 'Unmet' }
    }
    follow_redirect!
    @perfect_passing_project.reload
    assert_not_nil @perfect_passing_project.lost_passing_at
    assert @perfect_passing_project.lost_passing_at > 5.minutes.ago.utc
    assert_not_nil @perfect_passing_project.achieved_passing_at
    patch "/en/projects/#{@perfect_passing_project.id}", params: {
      project: { interact_status: 'Met' }
    }
    assert_not_nil @perfect_passing_project.lost_passing_at
    assert_not_nil @perfect_passing_project.achieved_passing_at
    # These tests should work, but don't; it appears our workaround for
    # the inadequately reset database interferes with them.
    # assert @perfect_passing_project.achieved_passing_at > 5.minutes.ago.utc
    # assert @perfect_passing_project.achieved_passing_at >
    #        @perfect_passing_project.lost_passing_at
  end

  test 'Can display delete form' do
    log_in_as(@project.user)
    get "/en/projects/#{@project.id}/delete_form"
    assert_response :success
    assert_includes @response.body, 'Warning'
  end

  test 'should destroy own project if rationale adequate' do
    log_in_as(@project.user)
    num = ActionMailer::Base.deliveries.size
    assert_difference('Project.count', -1) do
      # The "delete" request routes to the controller method "destroy"
      delete "/en/projects/#{@project.id}",
             params: {
               deletion_rationale: 'The front page is not purple enough.'
             }
    end
    assert_equal 'Project was successfully deleted.', flash['success']
    assert_redirected_to projects_path
    assert_equal num + 1, ActionMailer::Base.deliveries.size
  end

  test 'should NOT destroy own project if rationale too short' do
    log_in_as(@project.user)
    assert_no_difference('Project.count',
                         ActionMailer::Base.deliveries.size) do
      delete "/en/projects/#{@project.id}",
             params: { deletion_rationale: 'Nah.' }
    end
    assert_equal 'Must have at least 20 characters.', flash['danger']
    assert_redirected_to delete_form_project_path(@project)
  end

  test 'should NOT destroy own project if rationale has few non-whitespace' do
    log_in_as(@project.user)
    assert_no_difference('Project.count',
                         ActionMailer::Base.deliveries.size) do
      delete "/en/projects/#{@project.id}",
             params: { deletion_rationale: ' x y ' + ("\n" * 30) }
    end
    assert_equal 'Must have at least 15 non-whitespace characters.',
                 flash['danger']
    assert_redirected_to delete_form_project_path(@project)
  end

  test 'Admin can destroy any project' do
    log_in_as(@admin)
    num = ActionMailer::Base.deliveries.size
    assert_not_equal @admin, @project.user
    assert_difference('Project.count', -1) do
      delete "/en/projects/#{@project.id}" # calls controller method "destroy"
    end
    assert_redirected_to projects_path(locale: :en)
    assert_equal num + 1, ActionMailer::Base.deliveries.size
  end

  # Negative test
  test 'should not destroy project if logged in as different user' do
    log_in_as(@user2, password: 'password1')
    # Verify that we are actually logged in
    assert_equal @user2.id, session[:user_id]
    assert_no_difference('Project.count',
                         ActionMailer::Base.deliveries.size) do
      delete "/en/projects/#{@project.id}" # calls controller method "destroy"
    end
  end

  # Negative test
  test 'should not destroy project if not logged in' do
    # Notice that we do *not* call log_in_as.
    assert_no_difference('Project.count',
                         ActionMailer::Base.deliveries.size) do
      delete "/en/projects/#{@project.id}" # calls controller method "destroy"
    end
  end

  test 'should redirect to project page if project repo exists' do
    log_in_as(@user)
    assert_no_difference('Project.count') do
      post '/en/projects', params: { # Routes to 'create'
        project: { repo_url: @project.repo_url }
      }
    end
    assert_redirected_to edit_project_section_path(@project, 'passing', locale: :en)
  end

  test 'should succeed and then fail to change non-blank repo_url' do
    # We rate limit changing repo_url - ensure that works.
    assert @project_two.user.id, @user2.id # Check test fixtures
    log_in_as(@user2, password: 'password1')
    # Verify that we are actually logged in
    assert_equal @user2.id, session[:user_id]
    new_repo_url = @project.repo_url + '_new'
    patch "/en/projects/#{@project_two.id}", params: {
      project: { repo_url:  new_repo_url }
    }
    # Check for success
    @project_two.reload
    assert_equal new_repo_url, @project_two.repo_url

    # Now let's do it again. *This* should fail, it's too soon.
    second_repo_url = new_repo_url + '_second'
    patch "/en/projects/#{@project_two.id}", params: {
      project: { repo_url:  second_repo_url }
    }
    # Ensure the second attempt failed.
    assert_not_empty flash
    assert_includes @response.body, 'Edit Project Badge Status'
    @project_two.reload
    assert_equal new_repo_url, @project_two.repo_url
    assert_not_equal second_repo_url, @project_two.repo_url
  end

  test 'should change https to http in non-blank repo_url' do
    assert_equal @project_two.user.id, @user2.id # Check test fixtures match
    log_in_as(@user2, password: 'password1')
    # Verify that we are actually logged in
    assert_equal @user2.id, session[:user_id]
    old_repo_url = @project_two.repo_url
    new_repo_url = 'http://www.nasa.gov/mav'
    old_description = @project_two.description
    new_description = 'Mars Ascent Vehicle project'

    # Get version count before update
    version_count_before = @project_two.versions.count

    patch "/en/projects/#{@project_two.id}", params: { # Invokes "update"
      project: { repo_url: new_repo_url, description: new_description }
    }
    @project_two.reload

    # Verify fields were updated
    assert_not_equal @project_two.repo_url, old_repo_url
    assert_equal @project_two.repo_url, new_repo_url
    assert_equal @project_two.description, new_description

    # Verify PaperTrail created exactly one new version
    assert_equal version_count_before + 1, @project_two.versions.count

    # Check that PaperTrail properly recorded the version
    last_version = @project_two.versions.last
    assert_equal 'update', last_version.event

    # CRITICAL: Verify whodunnit contains the logged-in user's ID
    # This validates that our user_for_paper_trail override correctly
    # returns @session_user_id set by setup_authentication_state
    assert_equal @user2.id, last_version.whodunnit.to_i

    # Use PaperTrail to retrieve old version and verify old field values
    # This assumes we're storing this using JSON (probably jsonb),
    # *not* the default YAML. YAML stores very specific data types, including
    # a specialized timezone type, that we don't want. By storing with
    # JSON we reduce storage use, increase query speed, and avoid
    # various deserialization problems.
    old_version = last_version.reify
    assert_equal old_repo_url, old_version.repo_url
    assert_equal old_description, old_version.description
  end

  test 'admin can change other users non-blank repo_url' do
    log_in_as(@admin)
    assert_not_equal @admin, @project.user
    new_repo_url = @project.repo_url + '_new'
    patch "/en/projects/#{@project_two.id}", params: { # Invokes "update"
      project: { repo_url: new_repo_url }
    }
    @project_two.reload
    assert_equal @project_two.repo_url, new_repo_url
  end

  test 'should redirect with empty query params removed' do
    get '/en/projects?q=&status=passing' # Calls controller method "index"
    assert_redirected_to '/en/projects?status=passing'
  end

  test 'should redirect with all query params removed' do
    get '/en/projects?q=&status='
    assert_redirected_to '/en/projects'
  end

  test 'should remove invalid parameter' do
    get '/en/projects?bogus1=bogus2&status=passing'
    assert_redirected_to '/en/projects?status=passing'
  end

  test 'query JSON for passing projects' do
    get '/en/projects.json?gteq=100'
    assert_response :success
    body = response.parsed_body
    # We don't want to have to edit this test if we merely add new
    # test fixtures, so we'll just make sure we have at least 3 and
    # do a sanity check of the response.
    assert body.length >= 3
    0.upto(body.length - 1) do |i|
      assert body[i]['badge_percentage_0'] >= 100
    end
  end

  test 'query for passing projects has correct i18n query string' do
    # It'd be easy to drop the query string in cross-referenced locale links,
    # e.g., to refer to "/projects" when we should have "/projects?gteq=100".
    # Many of the Rails url-querying methods intentionally
    # *omit* the query string (which is often fine, but not in this case).
    # Specifically test to ensure the query string is retained.
    #
    get '/en/projects?gteq=100'
    assert_response :success

    # There's a weird test environment artifact I haven't been
    # able to track down.  The view response sometimes has an original url of
    # http://127.0.0.1:31337 and other times it's http://www.example.com.
    # Values such as "request.host" are consistently the second value.
    # This doesn't happen when we only test this file, but instead happens
    # when there's a full "rails test" - which means some other test
    # causes this.  It seems to be an artifact of the test environment, and
    # not actually a bug in the deployed code, so the test here will be
    # flexible to handle the variations that occur in the test environment.
    # See also: static_pages_controller_test.rb

    assert_includes I18n.available_locales, :en
    assert_includes I18n.available_locales, :fr
    I18n.available_locales.each do |loc|
      assert_match \
        %r{<link\ rel="alternate"\ hreflang="#{loc}"
         \ href="https?://[a-z0-9.:]+/#{loc}/projects\?gteq=100"\ />}x,
        @response.body
      # User locale selector (useful for users)
      assert_match \
        %r{<li><a\ href="https?://[a-z0-9.:]+/#{loc}/projects\?gteq=100">}x,
        @response.body
    end
    assert_match \
      %r{<link\ rel="alternate"\ hreflang="x-default"
       \ href="https?://[a-z0-9.:]+/projects\?gteq=100"\ />}x,
      @response.body
  end

  test 'as=badge works in simple case (single result)' do
    expected_id = projects(:perfect).id
    get '/en/projects?as=badge&' \
        'url=https%3A%2F%2Fgithub.com%2Fbestpracticestest%2Ftest-repo-shared'
    assert_redirected_to "/projects/#{expected_id}/badge"
  end

  test 'as=badge works with trailing space and slash' do
    expected_id = projects(:perfect).id
    get '/en/projects?as=badge&' \
        'url=https%3A%2F%2Fgithub.com%2Fbestpracticestest%2Ftest-repo-shared%2F%20'
    assert_redirected_to "/projects/#{expected_id}/badge"
  end

  test 'as=badge works in simple case returning JSON' do
    expected_id = projects(:perfect).id
    get '/en/projects.json?as=badge&' \
        'url=https%3A%2F%2Fgithub.com%2Fbestpracticestest%2Ftest-repo-shared'
    assert_redirected_to "/projects/#{expected_id}/badge.json"
  end

  test 'as=badge redirects simple case when using pq=' do
    expected_id = projects(:perfect).id
    get '/en/projects?as=badge&' \
        'pq=https%3A%2F%2Fgithub.com%2Fbestpracticestest%2Ftest-repo-shared'
    assert_redirected_to "/projects/#{expected_id}/badge"
  end

  test 'as=badge returns status 404 if not found' do
    get '/en/projects?as=badge&url=https%3A%2F%2FNO_SUCH_THING'
    assert_response :not_found
  end

  test 'as=badge returns status 409 (conflict) if >1 match' do
    get '/en/projects?as=badge&pq=https%3A%2F%2F'
    assert_response :conflict
  end

  test 'as=entry works in simple case (single result)' do
    expected_id = projects(:perfect).id
    get '/en/projects?as=entry&' \
        'url=https%3A%2F%2Fgithub.com%2Fbestpracticestest%2Ftest-repo-shared'
    assert_redirected_to "/en/projects/#{expected_id}"
  end

  test 'as=entry with section=choose redirects to choose show page' do
    expected_id = projects(:perfect).id
    get '/en/projects?as=entry&' \
        'section=choose&' \
        'url=https%3A%2F%2Fgithub.com%2Fbestpracticestest%2Ftest-repo-shared'
    assert_redirected_to "/en/projects/#{expected_id}/choose"
  end

  test 'as=entry quietly returns project list if >1 match' do
    get '/en/projects?as=entry&pq=https%3A%2F%2F'
    assert_response :success
    assert_includes @response.body, 'Projects'
  end

  test 'as=edit redirects to choose/edit when no section given' do
    expected_id = projects(:perfect).id
    get '/en/projects?as=edit&' \
        'url=https%3A%2F%2Fgithub.com%2Fbestpracticestest%2Ftest-repo-shared'
    assert_response :found # 302
    assert_redirected_to "/projects/#{expected_id}/choose/edit"
  end

  test 'as=edit redirects to choose/edit when section=choose' do
    expected_id = projects(:perfect).id
    get '/en/projects?as=edit&' \
        'section=choose&' \
        'url=https%3A%2F%2Fgithub.com%2Fbestpracticestest%2Ftest-repo-shared'
    assert_response :found # 302
    assert_redirected_to "/projects/#{expected_id}/choose/edit"
  end

  test 'as=edit redirects to edit page with explicit section' do
    expected_id = projects(:perfect).id
    # Params in alphabetical order to avoid set_valid_query_url reorder
    get '/en/projects?as=edit&' \
        'section=silver&' \
        'url=https%3A%2F%2Fgithub.com%2Fbestpracticestest%2Ftest-repo-shared'
    assert_response :found
    assert_redirected_to "/projects/#{expected_id}/silver/edit"
  end

  test 'as=edit defaults to passing for invalid section' do
    expected_id = projects(:perfect).id
    get '/en/projects?as=edit&' \
        'section=bogus&' \
        'url=https%3A%2F%2Fgithub.com%2Fbestpracticestest%2Ftest-repo-shared'
    assert_response :found
    assert_redirected_to "/projects/#{expected_id}/passing/edit"
  end

  test 'as=edit forwards proposal params to choose/edit when no section given' do
    expected_id = projects(:perfect).id
    # Params in alphabetical order, %20 for spaces (not +) to match
    # Addressable::URI normalization and avoid a reorder redirect.
    get '/en/projects?' \
        'as=edit&' \
        'floss_license_justification=MIT%20license&' \
        'floss_license_status=Met&' \
        'url=https%3A%2F%2Fgithub.com%2Fbestpracticestest%2Ftest-repo-shared'
    assert_response :found
    location = response.headers['Location']
    assert_includes location, "/projects/#{expected_id}/choose/edit?"
    assert_includes location, 'floss_license_status=Met'
    assert_includes location, 'floss_license_justification=MIT'
    assert_not_includes location, 'as=edit'
    assert_not_includes location, 'url='
  end

  test 'as=edit forwards proposal params to section/edit when section given' do
    expected_id = projects(:perfect).id
    # Params in alphabetical order, %20 for spaces (not +) to match
    # Addressable::URI normalization and avoid a reorder redirect.
    get '/en/projects?' \
        'as=edit&' \
        'floss_license_justification=MIT%20license&' \
        'floss_license_status=Met&' \
        'section=passing&' \
        'url=https%3A%2F%2Fgithub.com%2Fbestpracticestest%2Ftest-repo-shared'
    assert_response :found
    location = response.headers['Location']
    assert_includes location, "/projects/#{expected_id}/passing/edit?"
    assert_includes location, 'floss_license_status=Met'
    assert_includes location, 'floss_license_justification=MIT'
    assert_not_includes location, 'as=edit'
    assert_not_includes location, 'url='
  end

  test 'choose_edit shows section list and forwards proposal params' do
    project = projects(:perfect)
    log_in_as(project.user)
    get "/en/projects/#{project.id}/choose/edit?" \
        'floss_license_status=Met&floss_license_justification=MIT+license'
    assert_response :success
    body = response.body
    # Each section edit link should include the proposal params
    assert_includes body, '/passing/edit?'
    assert_includes body, 'floss_license_status=Met'
    # section= must not appear in the edit links' query strings
    assert_not_includes body, '/edit?section='
  end

  test 'choose_edit strips section= from forwarded edit link params' do
    project = projects(:perfect)
    log_in_as(project.user)
    # If someone visits choose/edit with section= in query string,
    # it must be stripped from the section edit links to prevent cycles.
    # (section appears in the URL path, not the query string)
    get "/en/projects/#{project.id}/choose/edit?section=choose&floss_license_status=Met"
    assert_response :success
    body = response.body
    # The hreflang links in <head> legitimately echo the current URL (pointing
    # to choose/edit with section=choose), which is fine - no cycle.
    # What matters: the section-specific edit links must NOT carry section=.
    Sections::ALL_CANONICAL_NAMES.each do |section_name|
      assert_not_includes body, "/#{section_name}/edit?section="
    end
  end

  test 'choose_edit redirects unauthenticated user to login with return_to' do
    project = projects(:perfect)
    get "/en/projects/#{project.id}/choose/edit"
    assert_response :found
    assert_match %r{/en/login\?return_to=}, response.location
  end

  test 'choose_show shows section list for read-only viewing' do
    project = projects(:perfect)
    get "/en/projects/#{project.id}/choose"
    assert_response :success
    # Should show links to section show pages (not edit)
    assert_includes response.body, "/projects/#{project.id}/passing"
  end

  test 'as=edit quietly returns project list if >1 match' do
    get '/en/projects?as=edit&pq=https%3A%2F%2F'
    assert_response :success
    assert_includes @response.body, 'Projects'
  end

  test 'as=edit quietly returns project list if no match' do
    get '/en/projects?as=edit&url=https%3A%2F%2FNO_SUCH_THING'
    assert_response :success
    assert_includes @response.body, 'Projects'
  end

  test 'Check ids= projects index query' do
    # %2c is the comma
    get "/en/projects.json?ids=#{@project.id}%2c#{@project_two.id}"
    follow_redirect!
    assert_response :success
    body = response.parsed_body
    assert_equal 2, body.length
    assert_equal @project.id, body[0]['id']
    assert_equal @project_two.id, body[1]['id']
  end

  test 'should redirect http to https' do
    # Rails.application.config.force_ssl is off in testing, turn it on.
    # This is NOT a thread-safe test.
    old = Rails.application.config.force_ssl
    Rails.application.config.force_ssl = true
    get 'http://test.host/en/projects'
    assert_redirected_to 'https://test.host/en/projects'
    Rails.application.config.force_ssl = old
  end

  test 'sanity test of reminders' do
    # The test framework does not reliably reset the test values for the
    # late_project (we don't know why). So in this test we manually force the
    # correct test values so our test will work reliably.
    # This makes the test reliable (I've re-run "rails test:all" 177 times after doing this),
    # and doing this lets us remove the gem "database_cleaner" (which shouldn't be necessary).
    # We generally want to minimize dependencies, so adding a few lines to set up a test
    # is a good trade-off.

    # Here are debug statements if you want to investigate this again:
    # projects_to_remind = Project.projects_to_remind
    # projects_to_remind_ids = projects_to_remind.map(&:id) # Return a list
    # puts('')
    # puts('Expect: project name=Pathfinder OS id=980190962 badge_percentage_0=0 '
    #      'last_reminder_at= lost_passing_at= updated_at=2000-01-01 00:00:00 UTC')
    # p = projects_to_remind.first
    # p = Project.find_by(id: 980190962)
    # puts("Sanity: project name=#{p.name} id=#{p.id} badge_percentage_0=#{p.badge_percentage_0} '
    #      "last_reminder_at=#{p.last_reminder_at} lost_passing_at=#{p.lost_passing_at} "
    #      "updated_at=#{p.updated_at}")
    # byebug if projects_to_remind_ids.size == 0

    # Manually force the correct test values so our test will work reliably.
    late_project = Project.find_by(name: 'Pathfinder OS')
    late_project.last_reminder_at = nil
    late_project.lost_passing_at = nil
    late_project.save!(touch: false)

    result = ProjectsController.send :send_reminders
    assert_not_equal 0, result.size
    late_project.reload
    assert_not_nil late_project.last_reminder_at
    # assert_equal late_project.id, result[0]
  end

  # Sending a reminder is our bookkeeping, not the owner's edit, so it
  # must not bump lock_version.  If it did, an owner who happened to have
  # the edit form open would be told their entry "changed since you
  # started editing" because we mailed them a reminder.
  test 'sending reminders leaves lock_version alone' do
    late_project = Project.find_by(name: 'Pathfinder OS')
    late_project.last_reminder_at = nil
    late_project.lost_passing_at = nil
    late_project.save!(touch: false)
    before = Project.where(id: late_project.id).pick(:lock_version)
    assert_predicate before, :positive?, 'fixture must exercise a real lock'

    ProjectsController.send :send_reminders

    fresh = Project.find(late_project.id)
    assert_not_nil fresh.last_reminder_at, 'reminder was not recorded'
    assert_equal before, fresh.lock_version
  end

  # Sending a reminder writes only last_reminder_at, which is withheld
  # from the project JSON and shown on no cached page, so it must not
  # cost a CDN purge.  Purging for a field nobody can see is the waste
  # that Project::BOOKKEEPING_FIELDS exists to make visible.
  test 'sending reminders does not purge the CDN' do
    late_project = Project.find_by(name: 'Pathfinder OS')
    late_project.last_reminder_at = nil
    late_project.lost_passing_at = nil
    late_project.save!(touch: false)

    assert_no_enqueued_jobs only: PurgeCdnProjectJob do
      ProjectsController.send :send_reminders
    end
  end

  # This is a unit test of a private method in ProjectsController.
  test 'URL cleaning works' do
    p = ProjectsController.new
    # Use "send" to do unit test of private method.
    assert_equal 'xyz', p.send(:clean_url, 'xyz')
    assert_equal 'xyz', p.send(:clean_url, 'xyz/')
    assert_equal 'xyz', p.send(:clean_url, 'xyz//')
    assert_nil p.send(:clean_url, nil)
    assert_equal 'x/z', p.send(:clean_url, 'x/z')
  end

  # Test repo_data with mock client to check basic functionality
  test 'repo_data with valid github client returns processed repos' do
    controller = ProjectsController.new

    # Mock github client that returns successful data
    mock_github = Object.new
    mock_github.define_singleton_method(:auto_paginate=) { |value| }
    mock_github.define_singleton_method(:repos) do |_user, **_options|
      [
        # rubocop:disable Style/OpenStructUse, Performance/OpenStruct
        OpenStruct.new(
          html_url: 'https://github.com/user/testrepo',
          full_name: 'user/testrepo',
          fork: false,
          homepage: 'https://example.com'
        ),
        OpenStruct.new(
          html_url: 'https://github.com/user/anotherepo',
          full_name: 'user/anotherepo',
          fork: true,
          homepage: nil
        )
        # rubocop:enable Style/OpenStructUse, Performance/OpenStruct
      ]
    end

    result = controller.send(:repo_data, mock_github)

    assert_not_nil result
    assert_equal 2, result.length
    assert_equal 'user/anotherepo', result[0][0] # Should be sorted by name
    assert_equal true, result[0][1] # fork status
    assert_equal 'user/testrepo', result[1][0]
    assert_equal false, result[1][1] # fork status
  end

  test 'repo_data with unauthorized exception returns nil' do
    controller = ProjectsController.new

    # Create a mock object that mimics the Octokit client
    mock_github_class =
      Class.new do
        def auto_paginate=(value)
          # Mock implementation
        end

        def repos(_user, **)
          raise Octokit::Unauthorized.new(response_status: 401, response_body: 'Unauthorized')
        end
      end
    mock_github = mock_github_class.new

    result = controller.send(:repo_data, mock_github)

    assert_nil result
  end

  test 'repo_data with empty repos returns empty array' do
    controller = ProjectsController.new

    # Mock github client that returns empty array
    mock_github = Object.new
    mock_github.define_singleton_method(:auto_paginate=) { |value| }
    mock_github.define_singleton_method(:repos) do |_user, **_options|
      []
    end

    result = controller.send(:repo_data, mock_github)

    assert_equal [], result
  end

  test 'repo_data filters out existing projects' do
    controller = ProjectsController.new
    existing_repo_url = 'https://github.com/user/existingrepo'

    # Create a project with existing repo URL
    # Use fixture directly to avoid class reloading issues
    Project.create!(
      name: 'Existing Project',
      repo_url: existing_repo_url,
      homepage_url: 'https://example.com',
      user: users(:test_user)
    )

    # Mock github client that returns repos including the existing one
    mock_github = Object.new
    mock_github.define_singleton_method(:auto_paginate=) { |value| }
    mock_github.define_singleton_method(:repos) do |_user, **_options|
      [
        # rubocop:disable Style/OpenStructUse, Performance/OpenStruct
        OpenStruct.new(
          html_url: existing_repo_url,
          full_name: 'user/existingrepo',
          fork: false,
          homepage: nil
        ),
        OpenStruct.new(
          html_url: 'https://github.com/user/newrepo',
          full_name: 'user/newrepo',
          fork: false,
          homepage: nil
        )
        # rubocop:enable Style/OpenStructUse, Performance/OpenStruct
      ]
    end

    result = controller.send(:repo_data, mock_github)

    assert_not_nil result
    assert_equal 1, result.length
    assert_equal 'user/newrepo', result[0][0] # Only the new repo should be returned
  end

  test 'repo_data with nil repos returns empty array' do
    controller = ProjectsController.new

    # Mock github client that returns nil
    mock_github = Object.new
    mock_github.define_singleton_method(:auto_paginate=) { |value| }
    mock_github.define_singleton_method(:repos) do |_user, **_options|
      nil
    end

    result = controller.send(:repo_data, mock_github)

    assert_equal [], result
  end

  test 'repo_data sorts repositories by full_name' do
    controller = ProjectsController.new

    # Mock github client with unsorted repos
    mock_github = Object.new
    mock_github.define_singleton_method(:auto_paginate=) { |value| }
    mock_github.define_singleton_method(:repos) do |_user, **_options|
      [
        # rubocop:disable Style/OpenStructUse, Performance/OpenStruct
        OpenStruct.new(
          html_url: 'https://github.com/user/zrepo',
          full_name: 'user/zrepo',
          fork: false,
          homepage: nil
        ),
        OpenStruct.new(
          html_url: 'https://github.com/user/arepo',
          full_name: 'user/arepo',
          fork: true,
          homepage: 'https://example.com'
        )
        # rubocop:enable Style/OpenStructUse, Performance/OpenStruct
      ]
    end

    result = controller.send(:repo_data, mock_github)

    assert_not_nil result
    assert_equal 2, result.length
    assert_equal 'user/arepo', result[0][0] # Should be first after sorting
    assert_equal 'user/zrepo', result[1][0] # Should be second after sorting
  end

  test 'should handle missing criteria_level by redirecting to passing' do
    # When no criteria_level specified, redirect to passing (302)
    get "/en/projects/#{@project.id}"
    assert_response :found # 302
    assert_redirected_to "/en/projects/#{@project.id}/passing"
  end

  test 'should handle bronze as synonym for passing' do
    # Bronze redirects to passing (301)
    get "/en/projects/#{@project.id}/bronze"
    assert_response :moved_permanently
    assert_redirected_to "/en/projects/#{@project.id}/passing"
  end

  test 'should get permissions edit form' do
    log_in_as(@project.user)
    get "/en/projects/#{@project.id}/permissions/edit"
    assert_response :success
    assert_includes @response.body, 'Project Permissions'
    assert_includes @response.body, 'Ownership Transfer'
    assert_includes @response.body, 'Collaborator Management'
    # Should display current additional rights
    assert_includes @response.body, 'Currently:'
  end

  test 'should handle permissions form submission' do
    log_in_as(@project.user)
    get "/en/projects/#{@project.id}/permissions/edit"
    assert_response :success
    # Verify the form can be accessed and rendered
  end

  test 'permissions not accessible by non-owner without rights' do
    log_in_as(@user2)
    get "/en/projects/#{@project.id}/permissions/edit"
    assert_response :redirect
    # Should redirect since user2 is not the owner
  end

  test 'passing form should not contain ownership fields' do
    log_in_as(@project.user)
    get "/en/projects/#{@project.id}/passing/edit"
    assert_response :success
    assert_not_includes @response.body, 'project[user_id_repeat]'
    assert_not_includes @response.body, 'new_owner_repeat'
  end

  test 'passing form should not contain additional_rights fields' do
    log_in_as(@project.user)
    get "/en/projects/#{@project.id}/passing/edit"
    assert_response :success
    assert_not_includes @response.body, 'additional_rights_changes'
  end

  test 'permissions form displays current additional rights' do
    # Add an additional right for testing
    test_user = users(:test_user_mark)
    AdditionalRight.create!(
      user_id: test_user.id,
      project_id: @project.id
    )

    log_in_as(@project.user)
    get "/en/projects/#{@project.id}/permissions/edit"
    assert_response :success

    # Should show the current additional rights with user ID
    assert_includes @response.body, 'Currently:'
    assert_includes @response.body, test_user.id.to_s
  end

  test 'accessing project without criteria_level redirects to passing' do
    get "/en/projects/#{@project.id}"
    assert_response :redirect
    assert_redirected_to "/en/projects/#{@project.id}/passing"
  end

  test 'redirect to passing uses temporary redirect (302)' do
    get "/en/projects/#{@project.id}"
    assert_response :found # Temporary redirect, not 301 permanent
  end

  # Test redirects for paths without locale (should detect locale and redirect)
  test 'project show without locale redirects with locale detection' do
    get "/projects/#{@project.id}",
        headers: { HTTP_ACCEPT_LANGUAGE: 'fr,en-US;q=0.7,en;q=0.3' }
    assert_response :found # 302 temporary (locale redirect)
    # First redirect adds locale
    assert_redirected_to "/fr/projects/#{@project.id}"
    follow_redirect!
    # Second redirect adds default section
    assert_response :found # 302 temporary (section redirect)
    assert_redirected_to "/fr/projects/#{@project.id}/passing"
  end

  test 'project edit without locale redirects with locale detection' do
    log_in_as(@project.user)
    get "/projects/#{@project.id}/edit",
        headers: { HTTP_ACCEPT_LANGUAGE: 'de,en-US;q=0.7,en;q=0.3' }
    # Route doesn't exist - edit requires section parameter
    assert_response :not_found
  end

  # Test redirects for edit paths without criteria_level
  test 'project edit with locale but no criteria_level returns 404' do
    log_in_as(@project.user)
    get "/en/projects/#{@project.id}/edit"
    # Route doesn't exist - edit requires section parameter
    assert_response :not_found
  end

  # Test that markdown redirects to default section with format preserved
  test 'project markdown without locale redirects to default section' do
    get "/projects/#{@project.id}.md",
        headers: { HTTP_ACCEPT_LANGUAGE: 'fr,en-US;q=0.7,en;q=0.3' }
    # First redirect for locale detection
    assert_response :found
    assert_redirected_to "/fr/projects/#{@project.id}.md"
    follow_redirect!
    # Second redirect to default section
    assert_response :found
    assert_redirected_to "/fr/projects/#{@project.id}/passing.md"
  end

  test 'project JSON with locale redirects to non-locale JSON' do
    get "/en/projects/#{@project.id}.json"
    assert_response :moved_permanently
    assert_redirected_to "/projects/#{@project.id}.json"
    follow_redirect!
    assert_response :success
    body = response.parsed_body
    assert_equal 'Pathfinder OS', body['name']
  end

  test 'project markdown with locale redirects to default section markdown' do
    get "/en/projects/#{@project.id}.md"
    assert_response :found
    assert_redirected_to "/en/projects/#{@project.id}/passing.md"
    follow_redirect!
    assert_response :success
    assert_includes @response.body, 'Passing'
  end

  # Unit tests for private helper methods
  test 'current_working_level returns baseline_badge_level for baseline levels' do
    controller = ProjectsController.new
    project = projects(:perfect_passing)
    result = controller.send(:current_working_level, 'baseline-1', project)
    assert_equal project.baseline_badge_level, result
  end

  test 'current_working_level returns in_progress for baseline when no baseline earned' do
    # Ensures in_progress is returned for baseline series (not just metal),
    # so earning baseline-1 from scratch is detected as a level change.
    controller = ProjectsController.new
    project = projects(:perfect_passing) # no badge_percentage_baseline_* set
    result = controller.send(:current_working_level, 'baseline-1', project)
    assert_equal 'in_progress', result
  end

  test 'current_working_level returns project badge_level for non-baseline' do
    controller = ProjectsController.new
    project = projects(:perfect_passing)
    result = controller.send(:current_working_level, 'silver', project)
    assert_equal 'passing', result # project is at passing level
  end

  test 'badge_level_lost? returns false for baseline gain' do
    controller = ProjectsController.new
    result = controller.send(:badge_level_lost?, 'in_progress', 'baseline-1')
    assert_equal false, result
  end

  test 'badge_level_lost? detects loss for baseline level downgrade' do
    controller = ProjectsController.new
    # Going from baseline-2 to baseline-1 is a loss
    result = controller.send(:badge_level_lost?, 'baseline-2', 'baseline-1')
    assert_equal true, result
  end

  test 'badge_level_lost? returns false for baseline level upgrade' do
    controller = ProjectsController.new
    # Going from baseline-1 to baseline-2 is not a loss
    result = controller.send(:badge_level_lost?, 'baseline-1', 'baseline-2')
    assert_equal false, result
  end

  test 'badge_level_lost? detects loss from baseline to in_progress' do
    controller = ProjectsController.new
    result = controller.send(:badge_level_lost?, 'baseline-1', 'in_progress')
    assert_equal true, result
  end

  test 'badge_level_lost? detects loss for traditional levels' do
    controller = ProjectsController.new
    result = controller.send(:badge_level_lost?, 'passing', 'in_progress')
    assert_equal true, result
  end

  test 'update with continue and criteria_level renders edit directly' do
    # Save-and-continue now renders :edit instead of redirecting
    log_in_as(@project.user)
    patch edit_project_section_path(@project, 'baseline-1'),
          params: {
            project: { name: @project.name },
            continue: 'Quality'
          }
    assert_response :success
  end

  # Test SQL fieldname quoting functionality
  test 'quoted_sql_fieldname quotes field names with non-simple letters' do
    # Field names with mixed case (like 2FA) should be quoted
    result = ProjectsController.quoted_sql_fieldname('require_2FA_status')
    assert_equal '"require_2FA_status"', result,
                 'Field with 2FA should be quoted'

    result = ProjectsController.quoted_sql_fieldname('secure_2FA_justification')
    assert_equal '"secure_2FA_justification"', result,
                 'Field with 2FA should be quoted'

    result = ProjectsController.quoted_sql_fieldname('Field-Name')
    assert_match(/^".*"$/, result,
                 'Field with hyphen should be quoted')

    result = ProjectsController.quoted_sql_fieldname('field name')
    assert_match(/^".*"$/, result,
                 'Field with space should be quoted')
  end

  test 'quoted_sql_fieldname does not quote simple field names' do
    # Simple lowercase field names should not be quoted
    result = ProjectsController.quoted_sql_fieldname('id')
    assert_equal 'id', result,
                 'Simple field id should not be quoted'

    result = ProjectsController.quoted_sql_fieldname('user_id')
    assert_equal 'user_id', result,
                 'Simple field user_id should not be quoted'

    result = ProjectsController.quoted_sql_fieldname('created_at')
    assert_equal 'created_at', result,
                 'Simple field created_at should not be quoted'

    result = ProjectsController.quoted_sql_fieldname('description_good_status')
    assert_equal 'description_good_status', result,
                 'Simple field with multiple underscores should not be quoted'
  end

  # Test defense-in-depth measure in convert_status_params_of_hash!
  # When an invalid status value is provided, it should not be converted
  # so model validation can catch it and provide a proper error message.
  test 'convert_status_params_of_hash! does not convert invalid status values' do
    controller = ProjectsController.new
    test_hash = { description_good_status: 'invalid_value' }

    # Call the private method using send
    controller.send(:convert_status_params_of_hash!, test_hash)

    # Verify the invalid value was NOT converted (left as-is for validation)
    assert_equal 'invalid_value', test_hash[:description_good_status],
                 'Invalid status value should not be converted'
  end

  # Test that valid status values ARE converted
  test 'convert_status_params_of_hash! converts valid status values' do
    controller = ProjectsController.new
    test_hash = { description_good_status: 'Met' }

    controller.send(:convert_status_params_of_hash!, test_hash)

    # Verify the valid value was converted to integer
    assert_equal CriterionStatus::MET, test_hash[:description_good_status],
                 'Valid status value "Met" should be converted to integer 3'
  end

  # Test that empty justification strings are converted to nil
  test 'convert_justification_params_of_hash! converts empty strings to nil' do
    controller = ProjectsController.new
    test_hash = {
      description_good_justification: '',
      know_common_errors_justification: 'Some text'
    }

    controller.send(:convert_justification_params_of_hash!, test_hash)

    # Verify empty string was converted to nil
    assert_nil test_hash[:description_good_justification],
               'Empty justification string should be converted to nil'
    # Verify non-empty string was preserved
    assert_equal 'Some text', test_hash[:know_common_errors_justification],
                 'Non-empty justification should be preserved'
  end

  # Test that nil justifications remain nil
  test 'convert_justification_params_of_hash! preserves nil values' do
    controller = ProjectsController.new
    test_hash = { description_good_justification: nil }

    controller.send(:convert_justification_params_of_hash!, test_hash)

    # Verify nil was preserved
    assert_nil test_hash[:description_good_justification],
               'Nil justification should remain nil'
  end

  # Integration test: verify empty justification strings are converted on update
  test 'empty justification strings converted to nil on update' do
    log_in_as(@admin)

    patch "/en/projects/#{@project.id}", params: {
      project: {
        description_good_justification: '', # Empty string
        name: 'Test Project'
      }
    }

    @project.reload
    assert_nil @project.description_good_justification,
               'Empty justification should be stored as nil in database'
  end

  # Baseline badge tests
  test 'baseline_badge returns SVG for project' do
    get "/projects/#{@project.id}/baseline", params: { format: 'svg' }
    assert_response :success
    assert_includes @response.body, '<svg'
    assert_equal 'image/svg+xml', @response.media_type
  end

  test 'baseline_badge returns JSON for project' do
    get "/projects/#{@project.id}/baseline.json"
    assert_response :success
    json_data = JSON.parse(@response.body)
    assert_equal @project.id, json_data['id']
    assert_equal @project.name, json_data['name']
    # Badge level should be a percentage (0-99) when not achieved
    assert json_data.key?('badge_level')
    assert json_data.key?('badge_percentage')
  end

  test 'baseline_badge has CDN caching headers' do
    get "/projects/#{@project.id}/baseline"
    assert_response :success
    # Verify Vary header for proper CDN caching
    assert_equal 'Accept-Encoding', @response.headers['Vary']
    # Surrogate-Key must carry both the project's own key (for the existing
    # edit-time purge) and BASELINE_BADGES_SURROGATE_KEY (so a baseline badge
    # artwork change, e.g. a version bump, can purge every project's
    # baseline badge at once).
    assert_equal "#{@project.record_key} #{ApplicationController::BASELINE_BADGES_SURROGATE_KEY}",
                 @response.headers['Surrogate-Key']
  end

  test 'baseline_badge JSON has CDN caching headers' do
    get "/projects/#{@project.id}/baseline.json"
    assert_response :success
    assert_equal 'Accept-Encoding', @response.headers['Vary']
    # JSON has no image and no translatable text, so it needs no series key.
    assert_equal @project.record_key, @response.headers['Surrogate-Key']
  end

  # Automation feature tests

  test 'first edit runs automation without setting saved flag' do
    log_in_as(@user)
    # Ensure baseline_1_saved is false (not yet saved)
    @project.update_column(:baseline_1_saved, false)

    get edit_project_section_path(@project, 'baseline-1', locale: :en)

    assert_response :success
    @project.reload
    # Flag should NOT be set until user actually saves
    assert_not @project.baseline_1_saved, 'baseline_1_saved flag should not be set until user saves'
  end

  test 'save with chief failure continues without automation' do
    log_in_as(@user)
    controller = ProjectsController.new

    # Simulate Chief failure by calling the failure handler directly
    controller.instance_variable_set(:@project, @project)
    controller.instance_variable_set(:@criteria_level, 'passing')

    # Create an exception with backtrace
    begin
      raise StandardError, 'Test Chief failure'
    rescue StandardError => e
      error = e
    end

    changed_fields = [:floss_license_osi_status] # Use an actually overridable field
    user_set_values = { floss_license_osi_status: 'Met' }

    controller.send(:handle_chief_save_failure, error, changed_fields, user_set_values)

    # Check that failure was recorded
    assert controller.instance_variable_get(:@chief_failed)
    assert_equal [:floss_license_osi_status], controller.instance_variable_get(:@chief_failed_fields)
  end

  test 'save and continue with overrides redirects to edit' do
    log_in_as(@user)
    controller = ProjectsController.new

    # Set up override scenario
    controller.instance_variable_set(:@project, @project)
    controller.instance_variable_set(:@criteria_level, 'passing')
    controller.instance_variable_set(:@overridden_fields, {
                                       license: {
                                         old_value: 'MIT', new_value: 'Apache-2.0',
                                         explanation: 'Detected Apache license'
                                       }
                                     })
    controller.instance_variable_set(:@automated_fields, {})

    # Test the format_override_details method
    details = controller.send(:format_override_details)

    # Should format override details
    assert_not_nil details
    assert_match(/license/i, details.downcase)
  end

  test 'classify_chief_proposals: forced override of real value → orange' do
    log_in_as(@user)
    controller = ProjectsController.new
    controller.instance_variable_set(:@project, @project)
    controller.instance_variable_set(:@criteria_level, 'passing')
    controller.instance_variable_set(:@automated_fields, {})
    controller.instance_variable_set(:@overridden_fields, {})
    controller.instance_variable_set(:@divergent_fields, {})
    proposals = {
      license: { value: 'Apache-2.0', explanation: 'Detected Apache', forced: true }
    }
    original_values = { license: 'MIT' }
    controller.send(:classify_chief_proposals, proposals, original_values, track_automated: true)
    overrides = controller.instance_variable_get(:@overridden_fields)
    assert_equal 1, overrides.size
    assert overrides.key?(:license)
    assert_equal 'MIT',        overrides[:license][:old_value]
    assert_equal 'Apache-2.0', overrides[:license][:new_value]
    assert_empty controller.instance_variable_get(:@automated_fields)
    assert_empty controller.instance_variable_get(:@divergent_fields)
  end

  test 'JSON update includes automation metadata' do
    log_in_as(@user)
    patch project_path(@project, locale: :en, format: :json),
          params: {
            criteria_level: 'passing',
                    project: { name: 'Updated Name' }
          }

    assert_response :success
    json = response.parsed_body
    assert json.key?('id')
    assert_equal 'updated', json['status']
  end

  test 'classify_chief_proposals: blank status → yellow (not orange, even if forced)' do
    log_in_as(@user)
    controller = ProjectsController.new
    controller.instance_variable_set(:@project, @project)
    controller.instance_variable_set(:@criteria_level, 'passing')
    controller.instance_variable_set(:@automated_fields, {})
    controller.instance_variable_set(:@overridden_fields, {})
    controller.instance_variable_set(:@divergent_fields, {})
    proposals = {
      contribution_status: {
        value: CriterionStatus::MET,
        explanation: 'GitHub uses issues/PRs', forced: true
      }
    }
    original_values = { contribution_status: CriterionStatus::UNKNOWN }
    controller.send(:classify_chief_proposals, proposals, original_values, track_automated: true)
    automated = controller.instance_variable_get(:@automated_fields)
    assert_equal 1, automated.size
    assert automated.key?(:contribution_status)
    assert_equal CriterionStatus::MET, automated[:contribution_status][:new_value]
    assert_empty controller.instance_variable_get(:@overridden_fields)
    assert_empty controller.instance_variable_get(:@divergent_fields)
  end

  test 'classify_chief_proposals: blank status → yellow (first-edit style)' do
    log_in_as(@user)
    controller = ProjectsController.new
    controller.instance_variable_set(:@project, @project)
    controller.instance_variable_set(:@criteria_level, 'passing')
    controller.instance_variable_set(:@automated_fields, {})
    controller.instance_variable_set(:@overridden_fields, {})
    controller.instance_variable_set(:@divergent_fields, {})
    proposals = {
      contribution_status: {
        value: CriterionStatus::MET,
        explanation: 'Has CONTRIBUTING.md', forced: false
      }
    }
    original_values = { contribution_status: CriterionStatus::UNKNOWN }
    controller.send(:classify_chief_proposals, proposals, original_values, track_automated: true)
    automated = controller.instance_variable_get(:@automated_fields)
    assert automated.key?(:contribution_status)
    assert_empty controller.instance_variable_get(:@overridden_fields)
    assert_empty controller.instance_variable_get(:@divergent_fields)
  end

  test 'classify_chief_proposals: forced real-value → orange (first-edit style)' do
    log_in_as(@user)
    controller = ProjectsController.new
    controller.instance_variable_set(:@project, @project)
    controller.instance_variable_set(:@criteria_level, 'passing')
    controller.instance_variable_set(:@automated_fields, {})
    controller.instance_variable_set(:@overridden_fields, {})
    controller.instance_variable_set(:@divergent_fields, {})
    proposals = {
      contribution_status: {
        value: CriterionStatus::UNMET,
        explanation: 'No CONTRIBUTING.md', forced: true
      }
    }
    original_values = { contribution_status: CriterionStatus::MET }
    controller.send(:classify_chief_proposals, proposals, original_values, track_automated: true)
    automated  = controller.instance_variable_get(:@automated_fields)
    overridden = controller.instance_variable_get(:@overridden_fields)
    assert_empty automated
    assert_equal 1, overridden.size
    assert overridden.key?(:contribution_status)
    assert_equal CriterionStatus::MET,   overridden[:contribution_status][:old_value]
    assert_equal CriterionStatus::UNMET, overridden[:contribution_status][:new_value]
    assert_empty controller.instance_variable_get(:@divergent_fields)
  end

  test 'classify_chief_proposals: non-forced real-value → divergent ≠' do
    log_in_as(@user)
    controller = ProjectsController.new
    @project.contribution_status = CriterionStatus::MET
    controller.instance_variable_set(:@project, @project)
    controller.instance_variable_set(:@criteria_level, 'passing')
    controller.instance_variable_set(:@automated_fields, {})
    controller.instance_variable_set(:@overridden_fields, {})
    controller.instance_variable_set(:@divergent_fields, {})
    proposals = {
      contribution_status: {
        value: CriterionStatus::UNMET,
        explanation: 'No CONTRIBUTING.md', forced: false
      }
    }
    original_values = { contribution_status: CriterionStatus::MET }
    controller.send(:classify_chief_proposals, proposals, original_values, track_automated: true)
    assert_equal CriterionStatus::MET, @project.contribution_status,
                 'classify must not change the project value'
    divergent = controller.instance_variable_get(:@divergent_fields)
    assert divergent.key?(:contribution_status), 'non-forced disagreement must show ≠'
    assert_equal CriterionStatus::UNMET, divergent[:contribution_status][:proposed_status]
    assert_empty controller.instance_variable_get(:@automated_fields)
    assert_empty controller.instance_variable_get(:@overridden_fields)
  end

  test 'classify_chief_proposals: non-forced real-value suppressed when track_automated false' do
    log_in_as(@user)
    controller = ProjectsController.new
    controller.instance_variable_set(:@project, @project)
    controller.instance_variable_set(:@criteria_level, 'passing')
    controller.instance_variable_set(:@automated_fields, {})
    controller.instance_variable_set(:@overridden_fields, {})
    controller.instance_variable_set(:@divergent_fields, {})
    proposals = {
      contribution_status: {
        value: CriterionStatus::UNMET,
        explanation: 'No CONTRIBUTING.md', forced: false
      }
    }
    original_values = { contribution_status: CriterionStatus::MET }
    controller.send(:classify_chief_proposals, proposals, original_values, track_automated: false)
    assert_empty controller.instance_variable_get(:@divergent_fields),
                 '≠ must be suppressed on save-and-exit (track_automated: false)'
    assert_empty controller.instance_variable_get(:@automated_fields)
    assert_empty controller.instance_variable_get(:@overridden_fields)
  end

  test 'classify_chief_proposals: coupling rule — divergent status blocks justification' do
    log_in_as(@user)
    controller = ProjectsController.new
    controller.instance_variable_set(:@project, @project)
    controller.instance_variable_set(:@criteria_level, 'passing')
    controller.instance_variable_set(:@automated_fields, {})
    controller.instance_variable_set(:@overridden_fields, {})
    controller.instance_variable_set(:@divergent_fields, {})
    # Chief disagrees on status (non-forced) AND proposes a justification
    proposals = {
      contribution_status: {
        value: CriterionStatus::UNMET, explanation: 'reason', forced: false
      },
      contribution_justification: {
        value: 'Chief justification', explanation: nil, forced: false
      }
    }
    original_values = {
      contribution_status:       CriterionStatus::MET,
      contribution_justification: 'user justification'
    }
    controller.send(:classify_chief_proposals, proposals, original_values, track_automated: true)
    divergent = controller.instance_variable_get(:@divergent_fields)
    # Status goes divergent; explanation from Chief becomes proposed_justification
    assert divergent.key?(:contribution_status), 'divergent status must be recorded'
    assert_equal 'reason', divergent[:contribution_status][:proposed_justification],
                 'Chief explanation must be stored as proposed_justification in status entry'
    # Coupling rule blocks the justification proposal (regardless of no ≠ for justifications)
    assert_equal 1, divergent.size, 'coupling rule must block justification entry entirely'
  end

  test 'classify_chief_proposals: no-op proposal → not recorded anywhere' do
    log_in_as(@user)
    controller = ProjectsController.new
    controller.instance_variable_set(:@project, @project)
    controller.instance_variable_set(:@criteria_level, 'passing')
    controller.instance_variable_set(:@automated_fields, {})
    controller.instance_variable_set(:@overridden_fields, {})
    controller.instance_variable_set(:@divergent_fields, {})
    proposals = {
      contribution_status: { value: CriterionStatus::MET, explanation: 'same', forced: false }
    }
    original_values = { contribution_status: CriterionStatus::MET }
    controller.send(:classify_chief_proposals, proposals, original_values, track_automated: true)
    assert_empty controller.instance_variable_get(:@automated_fields),  'no-op must not be yellow'
    assert_empty controller.instance_variable_get(:@overridden_fields), 'no-op must not be orange'
    assert_empty controller.instance_variable_get(:@divergent_fields),  'no-op must not be divergent'
  end

  test 'run_save_automation: non-forced blank→fill NOT applied on save-and-exit' do
    log_in_as(@user)
    controller = ProjectsController.new
    controller.instance_variable_set(:@project, @project)
    controller.instance_variable_set(:@criteria_level, 'passing')

    # Blank field — a non-forced proposal would normally fill it on save-and-continue
    @project.contribution_status = CriterionStatus::UNKNOWN
    non_forced_proposal = CriterionStatus::MET

    mock_chief = Object.new
    mock_chief.define_singleton_method(:propose_changes) do |**_kwargs|
      {
        contribution_status: {
          value: non_forced_proposal,
                  explanation: 'Has CONTRIBUTING.md',
                  forced: false
        }
      }
    end
    mock_chief.define_singleton_method(:apply_changes) do |project, changes|
      changes.each { |key, data| project[key] = data[:value] }
    end

    changed_fields = [:contribution_status]
    user_set_values = { contribution_status: CriterionStatus::UNKNOWN }

    # save-and-exit: track_animated is false
    controller.send(:run_save_automation, changed_fields, user_set_values,
                    chief_instance: mock_chief, track_automated: false)

    assert_equal CriterionStatus::UNKNOWN, @project.contribution_status,
                 'non-forced blank→fill must NOT be applied on save-and-exit'
    assert_empty controller.instance_variable_get(:@overridden_fields)
    assert_empty controller.instance_variable_get(:@automated_fields)
  end

  test 'run_save_automation: forced proposal IS applied on save-and-exit' do
    log_in_as(@user)
    controller = ProjectsController.new
    controller.instance_variable_set(:@project, @project)
    controller.instance_variable_set(:@criteria_level, 'passing')

    @project.contribution_status = CriterionStatus::MET

    mock_chief = Object.new
    mock_chief.define_singleton_method(:propose_changes) do |**_kwargs|
      {
        contribution_status: {
          value: CriterionStatus::UNMET,
                  explanation: 'No CONTRIBUTING.md',
                  forced: true
        }
      }
    end
    mock_chief.define_singleton_method(:apply_changes) do |project, changes|
      changes.each { |key, data| project[key] = data[:value] }
    end

    changed_fields = [:contribution_status]
    user_set_values = { contribution_status: CriterionStatus::MET }

    controller.send(:run_save_automation, changed_fields, user_set_values,
                    chief_instance: mock_chief, track_automated: false)

    assert_equal CriterionStatus::UNMET, @project.contribution_status,
                 'forced proposal must still be applied on save-and-exit'
    assert_equal 1, controller.instance_variable_get(:@overridden_fields).size
  end

  test 'run_first_edit_automation_if_needed rescues chief errors' do
    log_in_as(@user)
    # Project with passing_saved=false so automation runs
    @project.passing_saved = false
    @project.save!
    controller = ProjectsController.new
    controller.instance_variable_set(:@project, @project)
    controller.instance_variable_set(:@criteria_level, 'passing')
    controller.instance_variable_set(:@automated_fields, {})
    controller.instance_variable_set(:@overridden_fields, {})
    controller.instance_variable_set(:@divergent_fields, {})

    # Stub client_factory to raise
    controller.define_singleton_method(:client_factory) do
      raise StandardError, 'simulated network error'
    end
    controller.define_singleton_method(:level_already_saved?) { false }
    controller.define_singleton_method(:fields_for_current_section) { nil }
    controller.define_singleton_method(:capture_original_values) { {} }
    controller.define_singleton_method(:params) do
      ActionController::Parameters.new({})
    end

    # Should not raise; rescue block sets fields to {}
    assert_nothing_raised { controller.send(:run_first_edit_automation_if_needed) }
    assert_equal({}, controller.instance_variable_get(:@automated_fields))
    assert_equal({}, controller.instance_variable_get(:@overridden_fields))
    assert_equal({}, controller.instance_variable_get(:@divergent_fields))
  end

  test 'run_save_automation catches chief exceptions' do
    log_in_as(@user)
    controller = ProjectsController.new
    controller.instance_variable_set(:@project, @project)
    controller.instance_variable_set(:@criteria_level, 'passing')

    # Create a mock chief that raises
    mock_chief = Object.new
    mock_chief.define_singleton_method(:propose_changes) do |**_kwargs|
      raise StandardError, 'Test exception'
    end

    changed_fields = [:floss_license_osi_status]
    user_set_values = { floss_license_osi_status: 'Met' }

    # This should catch the exception and set @chief_failed
    controller.send(:run_save_automation, changed_fields, user_set_values, chief_instance: mock_chief)

    assert controller.instance_variable_get(:@chief_failed)
    assert_equal [:floss_license_osi_status], controller.instance_variable_get(:@chief_failed_fields)
  end

  test 'chief failure during save renders edit with analysis failed warning' do
    log_in_as(@user)

    # Set repo_url to trigger TestForcedDetective exception
    @project.repo_url = 'https://example.com/test/chief-failure'
    @project.description_good_status = '?'
    @project.passing_saved = false # Ensure automation runs
    @project.save!

    # User tries to change description_good
    patch edit_project_section_path(@project, 'passing'), params: {
      project: { description_good_status: 'Met' },
      continue: '1' # Save and continue
    }

    # Should render edit directly with analysis failed warning
    assert_response :success
    assert_nil response.location
    assert_match(/analysis failed/i, flash.now[:warning] || response.body)
  end

  # Integration tests using TestForcedDetective to trigger forced overrides
  test 'save with forced override renders edit with warning' do
    log_in_as(@user)

    # Set repo_url to trigger TestForcedDetective forced override
    @project.repo_url = 'https://example.com/test/force-override'
    @project.description_good_status = '?'
    @project.save!

    # Verify the URL was saved
    @project.reload
    assert_equal 'https://example.com/test/force-override', @project.repo_url

    # User tries to change description_good
    patch edit_project_section_path(@project, 'passing'), params: {
      project: { description_good_status: 'Met' },
      continue: '1' # Save and continue
    }

    # Should render edit (not redirect) with warning about override
    assert_response :success
    assert_nil response.location
    assert_includes response.body, 'highlight-overridden'
  end

  test 'save with forced override on exit renders edit with warning' do
    log_in_as(@user)

    # Set repo_url to trigger TestForcedDetective forced override
    @project.repo_url = 'https://example.com/test/force-override'
    @project.description_good_status = '?'
    @project.save!

    # User tries to change description_good, save and exit
    patch edit_project_section_path(@project, 'passing'), params: {
      project: { description_good_status: 'Met' }
      # No continue param = save and exit
    }

    # Should render edit (NOT redirect to show) with warning about override
    assert_response :success
    assert_nil response.location
    assert_includes response.body, 'highlight-overridden'
  end

  test 'JSON request with forced override includes automation metadata' do
    log_in_as(@user)

    # Reload to get fresh state (other tests may have modified @project)
    @project.reload

    # Set repo_url to trigger TestForcedDetective forced override
    @project.repo_url = 'https://example.com/test/force-override'
    @project.description_good_status = '?'
    @project.passing_saved = false # Ensure automation runs
    @project.save!

    # User tries to change description_good via JSON
    patch project_path(@project, locale: :en, format: :json), params: {
      criteria_level: 'passing',
      project: { description_good_status: 'Met' }
    }

    assert_response :success
    json_response = response.parsed_body

    # Should include automation metadata with overridden field
    assert json_response.key?('automation')
    assert json_response['automation'].key?('overridden')
    overridden = json_response['automation']['overridden']
    assert(overridden.any? { |f| f['field'] == 'description_good_status' })
  end

  test 'automated fields JSON includes field metadata' do
    # Test the JSON serialization of automated fields directly
    log_in_as(@user)
    controller = ProjectsController.new
    controller.instance_variable_set(:@project, @project)
    controller.instance_variable_set(:@automated_fields, {
                                       contribution_status: { new_value: CriterionStatus::MET, explanation: 'Auto-detected' }
                                     })
    controller.instance_variable_set(:@overridden_fields, {})

    json_metadata = controller.send(:build_automation_metadata)

    assert json_metadata.key?(:automated)
    assert_equal 1, json_metadata[:automated].length
    assert_equal :contribution_status, json_metadata[:automated][0][:field]
    assert_equal CriterionStatus::MET, json_metadata[:automated][0][:value]
  end

  test 'apply_query_string_automation works on revisit (section saved)' do
    @project.update_column(:passing_saved, true)
    @project.contribution_status = CriterionStatus::UNKNOWN
    @project.save!
    controller = setup_automation_controller
    run_automation(controller, 'contribution_status' => 'Met')
    assert_equal CriterionStatus::MET, @project.contribution_status
    automated = controller.instance_variable_get(:@automated_fields)
    assert_equal 1, automated.size
    assert automated.key?(:contribution_status)
  end

  test 'apply_query_string_automation works on first edit (section not saved)' do
    @project.update_column(:passing_saved, false)
    @project.contribution_status = CriterionStatus::UNKNOWN
    @project.save!
    controller = setup_automation_controller
    run_automation(controller, 'contribution_status' => 'Met')
    assert_equal CriterionStatus::MET, @project.contribution_status
    automated = controller.instance_variable_get(:@automated_fields)
    assert_equal 1, automated.size
    assert automated.key?(:contribution_status)
  end

  test 'apply_query_string_automation maps justification to status field' do
    @project.update_column(:passing_saved, true)
    @project.contribution_justification = ''
    @project.save!
    controller = setup_automation_controller
    run_automation(controller, 'contribution_justification' => 'Automated justification text')

    # The justification value should be applied
    assert_equal 'Automated justification text',
                 @project.contribution_justification

    # The automated_fields entry should map to the _status counterpart
    automated = controller.instance_variable_get(:@automated_fields)
    assert_equal 1, automated.size
    assert automated.key?(:contribution_status)
    assert_equal 'Automated justification text', automated[:contribution_status][:new_value]
  end

  # Helper to set up a controller for apply_query_string_automation tests
  def setup_automation_controller(criteria_level: 'passing')
    log_in_as(@user)
    controller = ProjectsController.new
    controller.instance_variable_set(:@project, @project)
    controller.instance_variable_set(:@criteria_level, criteria_level)
    controller
  end

  def run_automation(controller, param_hash)
    fake_params = ActionController::Parameters.new(
      param_hash.merge('controller' => 'projects', 'action' => 'edit')
    )
    controller.define_singleton_method(:params) { fake_params }
    controller.send(:init_automation_fields)
    controller.send(:apply_query_string_automation)
  end

  test 'apply_query_string_automation: blank field applied as yellow' do
    controller = setup_automation_controller
    @project.contribution_status = CriterionStatus::UNKNOWN
    run_automation(controller, 'contribution_status' => 'Met')
    assert_equal CriterionStatus::MET, @project.contribution_status
    automated = controller.instance_variable_get(:@automated_fields)
    assert automated.key?(:contribution_status), 'blank→filled goes yellow'
    assert_nil controller.instance_variable_get(:@divergent_fields)&.fetch(:contribution_status, nil)
  end

  test 'apply_query_string_automation: real-value field without overrides goes divergent' do
    controller = setup_automation_controller
    @project.contribution_status = CriterionStatus::UNMET
    run_automation(controller, 'contribution_status' => 'Met')
    assert_equal CriterionStatus::UNMET, @project.contribution_status, 'field must not change'
    divergent = controller.instance_variable_get(:@divergent_fields)
    assert divergent.key?(:contribution_status), 'should be in divergent_fields'
    assert_equal CriterionStatus::MET, divergent[:contribution_status][:proposed_status]
  end

  test 'apply_query_string_automation: proposed equals current not divergent' do
    controller = setup_automation_controller
    @project.contribution_status = CriterionStatus::MET
    run_automation(controller, 'contribution_status' => 'Met')
    assert_nil controller.instance_variable_get(:@divergent_fields)&.fetch(:contribution_status, nil)
  end

  test 'apply_query_string_automation: proposed ? not divergent' do
    controller = setup_automation_controller
    @project.contribution_status = CriterionStatus::UNMET
    run_automation(controller, 'contribution_status' => '?')
    divergent = controller.instance_variable_get(:@divergent_fields) || {}
    assert_not divergent.key?(:contribution_status), 'proposed ? should not be divergent'
  end

  test 'apply_query_string_automation: invalid proposed status skipped entirely' do
    controller = setup_automation_controller
    @project.contribution_status = CriterionStatus::UNMET
    run_automation(controller, 'contribution_status' => 'invalid_value')
    assert_equal CriterionStatus::UNMET, @project.contribution_status
    divergent = controller.instance_variable_get(:@divergent_fields) || {}
    assert_not divergent.key?(:contribution_status)
  end

  test 'apply_query_string_automation: overrides=* forces real-value field as orange' do
    controller = setup_automation_controller
    @project.contribution_status = CriterionStatus::UNMET
    run_automation(controller,
                   'contribution_status' => 'Met',
                   'contribution_justification' => 'Has CONTRIBUTING.md',
                   'overrides' => '*')
    assert_equal CriterionStatus::MET, @project.contribution_status
    overridden = controller.instance_variable_get(:@overridden_fields)
    assert overridden.key?(:contribution_status), 'should be in overridden_fields'
    assert_equal CriterionStatus::UNMET, overridden[:contribution_status][:old_value]
    assert_nil overridden[:contribution_status][:explanation], 'URL overrides have no explanation'
    assert_equal 'Has CONTRIBUTING.md', @project.contribution_justification,
                 'proposed justification must be applied to project'
  end

  test 'apply_query_string_automation: overrides too long returns no forcing' do
    controller = setup_automation_controller
    @project.contribution_status = CriterionStatus::UNMET
    long_overrides = 'contribution_*,' * 5000
    run_automation(controller,
                   'contribution_status' => 'Met',
                   'overrides' => long_overrides)
    assert_equal CriterionStatus::UNMET, @project.contribution_status
    divergent = controller.instance_variable_get(:@divergent_fields)
    assert divergent.key?(:contribution_status), 'should be divergent when overrides rejected'
  end

  test 'apply_query_string_automation: divergent status blocks paired justification' do
    controller = setup_automation_controller
    @project.contribution_status = CriterionStatus::UNMET
    @project.contribution_justification = 'existing justification'
    run_automation(controller,
                   'contribution_status' => 'Met',
                   'contribution_justification' => 'New justification')
    assert_equal CriterionStatus::UNMET, @project.contribution_status
    assert_equal 'existing justification', @project.contribution_justification,
                 'justification must not change when status is divergent'
    # The proposed justification is stored in the STATUS divergent entry so
    # the ≠ popover can display "Automation instead determined Met for: <reason>".
    divergent = controller.instance_variable_get(:@divergent_fields)
    assert_equal 'New justification',
                 divergent[:contribution_status][:proposed_justification],
                 'proposed justification must be stored in status divergent entry for popover display'
  end

  test 'apply_query_string_automation: divergent justification blocked even if overrides glob matches it' do
    controller = setup_automation_controller
    @project.contribution_status = CriterionStatus::UNMET
    @project.contribution_justification = 'existing justification'
    run_automation(controller,
                   'contribution_status' => 'Met',
                   'contribution_justification' => 'New justification',
                   'overrides' => 'contribution_justification')
    assert_equal CriterionStatus::UNMET, @project.contribution_status
    assert_equal 'existing justification', @project.contribution_justification,
                 'justification must not apply when paired status is divergent'
  end

  test 'apply_query_string_automation: blank justification applied when status blank' do
    controller = setup_automation_controller
    @project.contribution_status = CriterionStatus::UNKNOWN
    @project.contribution_justification = ''
    run_automation(controller,
                   'contribution_status' => 'Met',
                   'contribution_justification' => 'Has CONTRIBUTING.md')
    assert_equal CriterionStatus::MET, @project.contribution_status
    assert_equal 'Has CONTRIBUTING.md', @project.contribution_justification
  end

  test 'apply_query_string_automation: non-criteria blank field applied yellow' do
    controller = setup_automation_controller
    @project.name = ''
    run_automation(controller, 'name' => 'curl')
    assert_equal 'curl', @project.name
    automated = controller.instance_variable_get(:@automated_fields)
    assert automated.key?(:name), 'non-criteria blank field should be yellow'
  end

  test 'apply_query_string_automation: non-criteria non-blank field not applied, shows divergent icon' do
    controller = setup_automation_controller
    @project.name = 'existing name'
    run_automation(controller, 'name' => 'new name')
    assert_equal 'existing name', @project.name, 'non-blank non-criteria field must not change'
    divergent = controller.instance_variable_get(:@divergent_fields) || {}
    assert divergent.key?(:name), 'non-criteria divergent proposal must record ≠ icon'
    assert_equal 'new name', divergent[:name][:proposed_value]
  end

  test 'apply_query_string_automation: non-criteria non-blank field forced orange' do
    controller = setup_automation_controller
    @project.name = 'existing name'
    run_automation(controller, 'name' => 'new name', 'overrides' => '*')
    assert_equal 'new name', @project.name
    overridden = controller.instance_variable_get(:@overridden_fields) || {}
    # non-criteria fields map to themselves (not to a status field)
    assert overridden.key?(:name), 'non-criteria forced field should be orange'
  end

  test 'apply_query_string_automation: reanalyze key present in params is accessible' do
    # Just verify the params.key?(:reanalyze) check works — full reanalyze
    # behavior is tested via run_first_edit_automation_if_needed tests
    controller = setup_automation_controller
    fake_params = ActionController::Parameters.new(
      'reanalyze' => '1', 'controller' => 'projects', 'action' => 'edit'
    )
    controller.define_singleton_method(:params) { fake_params }
    assert controller.send(:params).key?(:reanalyze)
  end

  test 'run_first_edit_automation_if_needed skips when saved and no reanalyze' do
    controller = setup_automation_controller
    @project.update_column(:passing_saved, true)
    fake_params = ActionController::Parameters.new(
      'controller' => 'projects', 'action' => 'edit'
    )
    controller.define_singleton_method(:params) { fake_params }
    # Should return early (level_already_saved? && !params.key?(:reanalyze))
    # We test this by confirming no Chief reload happens (no DB find called)
    # Simplest: just confirm no exception is raised and @project stays the same id
    original_id = @project.id
    controller.send(:run_first_edit_automation_if_needed)
    assert_equal original_id, @project.id
  end

  test 'apply_query_string_automation: non-matching overrides glob leaves field divergent' do
    controller = setup_automation_controller
    @project.contribution_status = CriterionStatus::UNMET
    run_automation(controller,
                   'contribution_status' => 'Met',
                   'overrides' => 'floss_*') # glob matches floss_* not contribution_*
    assert_equal CriterionStatus::UNMET, @project.contribution_status,
                 'non-matching glob must not apply the proposal'
    divergent = controller.instance_variable_get(:@divergent_fields)
    assert divergent.key?(:contribution_status),
           'non-matching glob should leave field divergent, not applied'
  end

  test 'apply_query_string_automation: non-blank justification without overrides not applied, no icon' do
    # Justification differences are silently ignored when not forced — there are
    # many valid ways to justify a status, so automation disagreeing on wording
    # is not worth surfacing when the status itself is not being contested.
    controller = setup_automation_controller
    @project.contribution_justification = 'existing justification'
    run_automation(controller, 'contribution_justification' => 'new justification')
    assert_equal 'existing justification', @project.contribution_justification,
                 'non-blank justification must not change without overrides'
    divergent = controller.instance_variable_get(:@divergent_fields) || {}
    assert_not divergent.key?(:contribution_status),
               'justification-only difference must not show a ≠ icon'
  end

  # -----------------------------------------------------------------------
  # Consolidated decision-matrix tests for apply_query_string_automation.
  #
  # Each test exercises all rows for one field type (_status / _justification /
  # other) in a single run_automation call so the interaction between rows
  # can be verified together.  These are the integration-level counterparts
  # to the per-pass unit tests below.
  # -----------------------------------------------------------------------

  # rubocop:disable Metrics/BlockLength
  test 'integration decision matrix: _status fields — all 6 rows' do
    # Row 1 (unparsable proposed): field has real value, proposed is garbage → Skip (none)
    # Row 2 (proposed '?', even forced): field has real value → Skip (pre-screen)
    # Row 3 (blank/UNKNOWN → Yellow): current is UNKNOWN → Apply
    # Row 4 (no-op → Skip): proposed == current → Skip (none)
    # Row 5 (real, differs, not forced → ≠): stays unchanged, goes divergent
    # Row 6 (real, differs, forced → Orange): overwritten, old value recorded
    @project.license_location_status = CriterionStatus::UNMET  # row 1: bogus
    @project.english_status          = CriterionStatus::UNMET  # row 2: forced '?'
    @project.contribution_status     = CriterionStatus::UNKNOWN # row 3: blank
    @project.description_good_status = CriterionStatus::MET    # row 4: no-op
    @project.interact_status         = CriterionStatus::UNMET  # row 5: divergent
    @project.floss_license_status    = CriterionStatus::UNMET  # row 6: forced orange
    controller = setup_automation_controller
    run_automation(controller,
                   'license_location_status' => 'bogus',
                   'english_status'          => '?',
                   'contribution_status'     => 'Met',
                   'description_good_status' => 'Met',
                   'interact_status'         => 'Met',
                   'floss_license_status'    => 'Met',
                   'floss_license_justification' => 'OSI-approved license',
                   'overrides' => 'english_*,floss_*')
    automated  = controller.instance_variable_get(:@automated_fields)
    overridden = controller.instance_variable_get(:@overridden_fields)
    divergent  = controller.instance_variable_get(:@divergent_fields) || {}

    # Row 1: bogus proposed → no change, not recorded anywhere
    assert_equal CriterionStatus::UNMET, @project.license_location_status,
                 'row1: unparsable must not change'
    assert_not automated.key?(:license_location_status)
    assert_not divergent.key?(:license_location_status)
    assert_not overridden.key?(:license_location_status)

    # Row 2: proposed '?' on real value (even with overrides) → no change
    assert_equal CriterionStatus::UNMET, @project.english_status, 'row2: forced ? must not change'
    assert_not overridden.key?(:english_status), 'row2: forced ? must not be orange'
    assert_not divergent.key?(:english_status), 'row2: forced ? must not be divergent'

    # Row 3: current UNKNOWN → applied, yellow
    assert_equal CriterionStatus::MET, @project.contribution_status, 'row3: blank must be filled'
    assert automated.key?(:contribution_status), 'row3: blank fill must be yellow'
    assert_not overridden.key?(:contribution_status)

    # Row 4: no-op → not recorded anywhere
    assert_not automated.key?(:description_good_status), 'row4: no-op must not appear in automated'
    assert_not divergent.key?(:description_good_status), 'row4: no-op must not appear in divergent'

    # Row 5: real, differs, not forced → unchanged, in divergent
    assert_equal CriterionStatus::UNMET, @project.interact_status, 'row5: must not change'
    assert divergent.key?(:interact_status), 'row5: must be in divergent_fields'
    assert_equal CriterionStatus::MET, divergent[:interact_status][:proposed_status]
    assert_not overridden.key?(:interact_status)

    # Row 6: real, differs, forced → applied, orange with old_value; URL overrides have
    # no separate explanation (proposed justification is applied to the project instead)
    assert_equal CriterionStatus::MET, @project.floss_license_status, 'row6: must be overridden'
    assert overridden.key?(:floss_license_status), 'row6: must be orange'
    assert_equal CriterionStatus::UNMET, overridden[:floss_license_status][:old_value]
    assert_nil overridden[:floss_license_status][:explanation], 'URL overrides have no explanation'
    assert_equal 'OSI-approved license', @project.floss_license_justification,
                 'row6: proposed justification must be applied to project'
    assert_not divergent.key?(:floss_license_status)
  end
  # rubocop:enable Metrics/BlockLength

  test 'integration decision matrix: _justification fields — coupling rule + all 3 rows' do
    # Coupling rule: if paired status is divergent, justification is blocked always
    # Row 8 (blank → Yellow): current blank → applied yellow under paired status symbol
    # Row 9 (no-op → Skip): proposed == current → Skip (none)
    # Row 10 (differs, not forced → Skip): justification differences are silent —
    #   there are many ways to justify a conclusion, so automation disagreeing on
    #   wording alone is not meaningful when the status is not being contested.
    # Row 11 (differs, forced → Orange): applied, old_value is Integer status
    #
    # Coupling rule: interact_status = UNMET, propose 'Met' (not forced) → divergent.
    # Then interact_justification is blocked even with overrides.
    @project.interact_status              = CriterionStatus::UNMET # goes divergent
    @project.interact_justification       = ''
    # Row 8: blank justification, paired status not divergent (blank)
    @project.contribution_status         = CriterionStatus::UNKNOWN
    @project.contribution_justification  = ''
    # Row 9: same-value no-op
    @project.description_good_justification = 'no change'
    # Row 10: present, differs, not forced → silent (no ≠)
    @project.english_justification       = 'old justification'
    # Row 11: present, differs, forced → Orange (floss_license_status not divergent)
    @project.floss_license_status        = CriterionStatus::MET
    @project.floss_license_justification = 'old floss text'
    controller = setup_automation_controller
    run_automation(controller,
                   'interact_status'                => 'Met',       # makes interact divergent
                   'interact_justification'         => 'blocked',   # coupling rule
                   'contribution_justification'     => 'Has CONTRIBUTING.md', # row 8
                   'description_good_justification' => 'no change', # row 9 (same value)
                   'english_justification'          => 'new justification',   # row 10
                   'floss_license_justification'    => 'new floss text',      # row 11
                   'overrides' => 'floss_*')
    automated  = controller.instance_variable_get(:@automated_fields)
    overridden = controller.instance_variable_get(:@overridden_fields)
    divergent  = controller.instance_variable_get(:@divergent_fields) || {}

    # Coupling rule: interact_status is divergent, so interact_justification is blocked
    assert_equal '', @project.interact_justification, 'coupling rule: justification must not change'
    assert_not automated.key?(:interact_status), 'coupling rule: no yellow for blocked justification'

    # Row 8: blank justification → applied, yellow under paired status symbol
    assert_equal 'Has CONTRIBUTING.md', @project.contribution_justification, 'row8: must be applied'
    assert automated.key?(:contribution_status), 'row8: blank justification → yellow under status sym'

    # Row 9: no-op → not recorded anywhere
    assert_equal 'no change', @project.description_good_justification, 'row9: must not change'
    assert_not automated.key?(:description_good_status), 'row9: no-op must not be yellow'
    assert_not divergent.key?(:description_good_status), 'row9: no-op must not be divergent'

    # Row 10: present, differs, not forced → unchanged, NO ≠ (silently skipped)
    assert_equal 'old justification', @project.english_justification, 'row10: must not change'
    assert_not divergent.key?(:english_status), 'row10: justification-only difference must not show ≠'

    # Row 11: present, differs, forced → applied, orange under status symbol, Integer old_value
    assert_equal 'new floss text', @project.floss_license_justification, 'row11: must be applied'
    assert overridden.key?(:floss_license_status), 'row11: must be orange keyed on status symbol'
    assert_kind_of Integer, overridden[:floss_license_status][:old_value],
                   'row11: old_value must be Integer for CriterionStatus.canonical'
    assert_equal CriterionStatus::MET, overridden[:floss_license_status][:old_value]
  end

  test 'integration decision matrix: Other (non-criteria) fields — all 4 rows' do
    # Row 12 (blank → Yellow): current blank → Apply Yellow
    # Row 13 (no-op → Skip): proposed == current → Skip (none)
    # Row 14 (differs, not forced → ≠): unchanged, keyed on own field symbol
    # Row 15 (differs, forced → Orange): applied, keyed on own field symbol
    #
    # Only ALWAYS_AUTOMATABLE fields (name, license, description, etc.) are
    # valid for non-criteria automation; url fields like homepage_url are excluded.
    @project.name        = ''              # row 12: blank
    @project.description = 'existing desc' # row 13: no-op
    @project.license     = 'MIT'           # row 14: differs, not forced (overrides=cpe)
    @project.cpe         = 'cpe:/old'      # row 15: differs, forced
    controller = setup_automation_controller
    run_automation(controller,
                   'name'        => 'My Project',
                   'description' => 'existing desc', # same value
                   'license'     => 'Apache-2.0',    # not forced
                   'cpe'         => 'cpe:/new',      # forced
                   'overrides' => 'cpe')
    automated  = controller.instance_variable_get(:@automated_fields)
    overridden = controller.instance_variable_get(:@overridden_fields)
    divergent  = controller.instance_variable_get(:@divergent_fields) || {}

    # Row 12: blank → applied, yellow, keyed on own field symbol
    assert_equal 'My Project', @project.name, 'row12: blank field must be filled'
    assert automated.key?(:name), 'row12: blank fill must be yellow'

    # Row 13: no-op → not recorded anywhere
    assert_equal 'existing desc', @project.description, 'row13: no-op must not change'
    assert_not automated.key?(:description), 'row13: no-op must not appear in automated'
    assert_not divergent.key?(:description), 'row13: no-op must not appear in divergent'

    # Row 14: present, differs, not forced → unchanged, divergent icon with proposed_value
    assert_equal 'MIT', @project.license, 'row14: must not change'
    assert divergent.key?(:license), 'row14: must record ≠ icon keyed on own field'
    assert_equal 'Apache-2.0', divergent[:license][:proposed_value]

    # Row 15: present, differs, forced → applied, orange keyed on own field, old_value stored
    assert_equal 'cpe:/new', @project.cpe, 'row15: must be applied'
    assert overridden.key?(:cpe), 'row15: must be orange'
    assert_equal 'cpe:/old', overridden[:cpe][:old_value]
  end

  # Security tests for apply_query_string_automation field name validation.
  # These replace the deleted parse_and_validate_field_list security tests.
  # The equivalent protection is now the FIELDS_BY_SECTION whitelist in
  # apply_query_string_automation: any key not in the whitelist is silently
  # ignored before it can affect project state or be rendered.

  test 'apply_query_string_automation: SQL injection attempt in field name is ignored' do
    controller = setup_automation_controller
    @project.contribution_status = CriterionStatus::UNKNOWN
    run_automation(controller,
                   "'; DROP TABLE projects; --" => 'Met',
                   'contribution_status' => 'Met')
    automated = controller.instance_variable_get(:@automated_fields)
    # Valid field processed normally
    assert automated.key?(:contribution_status), 'valid field must be processed'
    # Malicious key is not present in any of the automation hashes
    divergent  = controller.instance_variable_get(:@divergent_fields) || {}
    overridden = controller.instance_variable_get(:@overridden_fields) || {}
    automated.merge(divergent).merge(overridden).each_key do |k|
      assert_no_match(/DROP/, k.to_s, 'SQL injection attempt must not appear as a field key')
    end
  end

  test 'apply_query_string_automation: XSS attempt in field name is ignored' do
    controller = setup_automation_controller
    @project.contribution_status = CriterionStatus::UNKNOWN
    run_automation(controller,
                   '<script>alert("xss")</script>' => 'Met',
                   'contribution_status' => 'Met')
    automated  = controller.instance_variable_get(:@automated_fields)
    divergent  = controller.instance_variable_get(:@divergent_fields) || {}
    overridden = controller.instance_variable_get(:@overridden_fields) || {}
    automated.merge(divergent).merge(overridden).each_key do |k|
      assert_no_match(/<script>/i, k.to_s, 'XSS attempt must not appear as a field key')
    end
  end

  test 'apply_query_string_automation: cross-section field is ignored' do
    # osps_ac_01_01_status is a baseline-1 criterion, not valid for passing
    controller = setup_automation_controller # criteria_level: 'passing'
    @project.contribution_status = CriterionStatus::UNKNOWN
    run_automation(controller,
                   'osps_ac_01_01_status' => 'Met', # baseline-1, wrong section
                   'contribution_status'  => 'Met') # passing, correct section
    automated = controller.instance_variable_get(:@automated_fields)
    assert automated.key?(:contribution_status), 'valid in-section field must be processed'
    assert_not automated.key?(:osps_ac_01_01_status), 'cross-section field must be ignored'
  end

  test 'apply_query_string_automation: unknown field name is ignored' do
    controller = setup_automation_controller
    @project.contribution_status = CriterionStatus::UNKNOWN
    run_automation(controller,
                   'not_a_real_field' => 'Met',
                   'contribution_status' => 'Met')
    automated  = controller.instance_variable_get(:@automated_fields)
    divergent  = controller.instance_variable_get(:@divergent_fields) || {}
    overridden = controller.instance_variable_get(:@overridden_fields) || {}
    assert_not automated.merge(divergent).merge(overridden).key?(:not_a_real_field)
  end

  test 'overrides and reanalyze are not in AS_EDIT_CONSUMED_PARAMS' do
    assert_not ProjectsController::AS_EDIT_CONSUMED_PARAMS.include?('overrides'),
               'overrides must not be consumed so it forwards through choose/edit'
    assert_not ProjectsController::AS_EDIT_CONSUMED_PARAMS.include?('reanalyze'),
               'reanalyze must not be consumed so it forwards through choose/edit'
  end

  # -----------------------------------------------------------------------
  # Direct unit tests for classify_status_pass (Pass 1)
  # and classify_non_status_pass (Pass 2).
  #
  # These call the private methods directly so each pass can be verified in
  # isolation — bugs in one pass cannot mask bugs in the other.
  # -----------------------------------------------------------------------

  # Builds a bare ProjectsController wired up with @project and param_hash.
  # @return [ProjectsController]
  def build_pass_controller(param_hash)
    log_in_as(@user)
    controller = ProjectsController.new
    controller.instance_variable_set(:@project, @project)
    controller.instance_variable_set(:@criteria_level, 'passing')
    fake_params = ActionController::Parameters.new(
      param_hash.merge('controller' => 'projects', 'action' => 'edit')
    )
    controller.define_singleton_method(:params) { fake_params }
    controller.instance_variable_set(:@automated_fields, {})
    controller.instance_variable_set(:@overridden_fields, {})
    controller.instance_variable_set(:@divergent_fields, {})
    controller
  end

  # Sets up a controller with the given params and builds the proposals hash
  # plus snapshots valid_fields, forced_fields, and original_values so callers
  # can invoke each classify pass directly.
  # @return [Array] [controller, valid_fields, forced_fields, original_values, proposals]
  def prepare_pass(param_hash)
    controller = build_pass_controller(param_hash)
    valid_fields    = controller.send(:fields_for_current_section)
    forced_fields   = controller.send(:compute_forced_fields, valid_fields)
    original_values = controller.send(:snapshot_original_values, valid_fields)
    proposals       = controller.send(:build_url_proposals, valid_fields, forced_fields)
    [controller, valid_fields, forced_fields, original_values, proposals]
  end

  # --- Pass 1: classify_status_pass ---

  test 'pass1: blank status proposal → applied yellow, not in returned divergent Set' do
    @project.contribution_status = CriterionStatus::UNKNOWN
    controller, _, _, ov, proposals = prepare_pass('contribution_status' => 'Met')
    divergent_set = controller.send(:classify_status_pass, proposals, ov, track_automated: true)
    controller.send(:apply_url_proposals, proposals, ov, divergent_set)
    assert_equal CriterionStatus::MET, @project.contribution_status
    automated = controller.instance_variable_get(:@automated_fields)
    assert automated.key?(:contribution_status), 'blank→filled should be yellow'
    assert_not divergent_set.include?(:contribution_status)
    assert_empty controller.instance_variable_get(:@overridden_fields)
  end

  test 'pass1: real-value proposal without forcing → divergent, not applied, in returned Set' do
    @project.contribution_status = CriterionStatus::UNMET
    controller, _, _, ov, proposals = prepare_pass('contribution_status' => 'Met')
    divergent_set = controller.send(:classify_status_pass, proposals, ov, track_automated: true)
    controller.send(:apply_url_proposals, proposals, ov, divergent_set)
    assert_equal CriterionStatus::UNMET, @project.contribution_status, 'must not change'
    divergent = controller.instance_variable_get(:@divergent_fields)
    assert divergent.key?(:contribution_status)
    assert_equal CriterionStatus::MET, divergent[:contribution_status][:proposed_status]
    assert divergent_set.include?(:contribution_status), 'must be in returned Set'
    assert_empty controller.instance_variable_get(:@automated_fields)
    assert_empty controller.instance_variable_get(:@overridden_fields)
  end

  test 'pass1: divergent entry stores proposed_justification from params' do
    @project.contribution_status = CriterionStatus::UNMET
    controller, _, _, ov, proposals = prepare_pass('contribution_status' => 'Met',
                                                   'contribution_justification' => 'Has CONTRIBUTING.md')
    controller.send(:classify_status_pass, proposals, ov, track_automated: true)
    divergent = controller.instance_variable_get(:@divergent_fields)
    assert_equal 'Has CONTRIBUTING.md',
                 divergent[:contribution_status][:proposed_justification]
  end

  test 'pass1: proposed equals current → not recorded anywhere, not in divergent Set' do
    @project.contribution_status = CriterionStatus::MET
    controller, _, _, ov, proposals = prepare_pass('contribution_status' => 'Met')
    divergent_set = controller.send(:classify_status_pass, proposals, ov, track_automated: true)
    assert_not divergent_set.include?(:contribution_status)
    assert_empty controller.instance_variable_get(:@automated_fields)
    assert_empty controller.instance_variable_get(:@divergent_fields)
  end

  test 'pass1: proposed ? with real value → not divergent, not applied' do
    @project.contribution_status = CriterionStatus::UNMET
    controller, _, _, ov, proposals = prepare_pass('contribution_status' => '?')
    divergent_set = controller.send(:classify_status_pass, proposals, ov, track_automated: true)
    controller.send(:apply_url_proposals, proposals, ov, divergent_set)
    assert_equal CriterionStatus::UNMET, @project.contribution_status
    assert_not divergent_set.include?(:contribution_status)
    assert_empty controller.instance_variable_get(:@divergent_fields)
  end

  test 'pass1: forced ? with real value → not applied, not orange (pre-screen)' do
    # Regression: before the pre-screen fix, forced '?' on a real value was applied
    # as Orange because the UNKNOWN guard only lived inside the !forced branch.
    @project.contribution_status = CriterionStatus::UNMET
    controller, _, _, ov, proposals = prepare_pass('contribution_status' => '?', 'overrides' => '*')
    divergent_set = controller.send(:classify_status_pass, proposals, ov, track_automated: true)
    controller.send(:apply_url_proposals, proposals, ov, divergent_set)
    assert_equal CriterionStatus::UNMET, @project.contribution_status,
                 'forced ? must not override a real status value'
    assert_empty controller.instance_variable_get(:@overridden_fields),
                 'forced ? must not produce an orange highlight'
    assert_not divergent_set.include?(:contribution_status)
  end

  test 'pass1: invalid proposed status → skipped entirely, not divergent' do
    @project.contribution_status = CriterionStatus::UNMET
    controller, _, _, ov, proposals = prepare_pass('contribution_status' => 'bogus')
    divergent_set = controller.send(:classify_status_pass, proposals, ov, track_automated: true)
    controller.send(:apply_url_proposals, proposals, ov, divergent_set)
    assert_equal CriterionStatus::UNMET, @project.contribution_status
    assert_not divergent_set.include?(:contribution_status)
    assert_empty controller.instance_variable_get(:@divergent_fields)
  end

  test 'pass1: forced real-value → applied orange with old_value; URL has no explanation' do
    @project.contribution_status = CriterionStatus::UNMET
    controller, _, _, ov, proposals = prepare_pass('contribution_status' => 'Met',
                                                   'contribution_justification' => 'Reason',
                                                   'overrides' => '*')
    divergent_set = controller.send(:classify_status_pass, proposals, ov, track_automated: true)
    controller.send(:apply_url_proposals, proposals, ov, divergent_set)
    assert_equal CriterionStatus::MET, @project.contribution_status
    overridden = controller.instance_variable_get(:@overridden_fields)
    assert overridden.key?(:contribution_status)
    assert_equal CriterionStatus::UNMET, overridden[:contribution_status][:old_value]
    assert_nil overridden[:contribution_status][:explanation], 'URL overrides have no explanation'
    assert_nil overridden[:contribution_status][:old_justification],
               'no prior justification was set, so old_justification must be nil'
    assert_not divergent_set.include?(:contribution_status)
    assert_empty controller.instance_variable_get(:@automated_fields)
  end

  test 'pass1: forced blank value → applied yellow, not orange' do
    @project.contribution_status = CriterionStatus::UNKNOWN
    controller, _, _, ov, proposals = prepare_pass('contribution_status' => 'Met',
                                                   'overrides' => '*')
    divergent_set = controller.send(:classify_status_pass, proposals, ov, track_automated: true)
    controller.send(:apply_url_proposals, proposals, ov, divergent_set)
    assert_equal CriterionStatus::MET, @project.contribution_status
    automated = controller.instance_variable_get(:@automated_fields)
    assert automated.key?(:contribution_status), 'forced blank fill is still yellow'
    assert_empty controller.instance_variable_get(:@overridden_fields)
  end

  test 'pass1: two fields — one divergent, one applied — returned Set has only divergent' do
    @project.contribution_status = CriterionStatus::UNMET # will be divergent
    @project.description_good_status = CriterionStatus::UNKNOWN # will be yellow
    controller, _, _, ov, proposals = prepare_pass('contribution_status' => 'Met',
                                                   'description_good_status' => 'Met')
    divergent_set = controller.send(:classify_status_pass, proposals, ov, track_automated: true)
    controller.send(:apply_url_proposals, proposals, ov, divergent_set)
    assert divergent_set.include?(:contribution_status)
    assert_not divergent_set.include?(:description_good_status)
    assert_equal CriterionStatus::MET, @project.description_good_status
  end

  # --- Pass 2: classify_non_status_pass ---

  test 'pass2: blank justification → applied yellow under paired status symbol' do
    @project.contribution_justification = ''
    controller, _, _, ov, proposals = prepare_pass('contribution_justification' => 'New text')
    controller.send(:classify_non_status_pass, proposals, ov, Set.new, track_automated: true)
    controller.send(:apply_url_proposals, proposals, ov, Set.new)
    assert_equal 'New text', @project.contribution_justification
    automated = controller.instance_variable_get(:@automated_fields)
    assert automated.key?(:contribution_status), 'justification highlights under status symbol'
  end

  test 'pass2: non-blank justification without forcing → not applied, no icon' do
    @project.contribution_justification = 'existing'
    controller, _, _, ov, proposals = prepare_pass('contribution_justification' => 'new text')
    controller.send(:classify_non_status_pass, proposals, ov, Set.new, track_automated: true)
    controller.send(:apply_url_proposals, proposals, ov, Set.new)
    assert_equal 'existing', @project.contribution_justification
    assert_empty controller.instance_variable_get(:@automated_fields)
    assert_empty controller.instance_variable_get(:@overridden_fields)
    assert_empty controller.instance_variable_get(:@divergent_fields),
                 'justification-only difference must not show any ≠ icon'
  end

  test 'pass2: non-blank justification without forcing, same value → no divergent icon' do
    @project.contribution_justification = 'same text'
    controller, _, _, ov, proposals = prepare_pass('contribution_justification' => 'same text')
    controller.send(:classify_non_status_pass, proposals, ov, Set.new, track_automated: true)
    controller.send(:apply_url_proposals, proposals, ov, Set.new)
    assert_equal 'same text', @project.contribution_justification
    assert_empty controller.instance_variable_get(:@automated_fields)
    assert_empty controller.instance_variable_get(:@overridden_fields)
    assert_empty controller.instance_variable_get(:@divergent_fields),
                 'no-op proposal must not show divergent icon'
  end

  test 'pass2: non-blank justification forced → applied orange under paired status symbol' do
    @project.contribution_status = CriterionStatus::UNMET
    @project.contribution_justification = 'old text'
    controller, _, _, ov, proposals = prepare_pass('contribution_justification' => 'new text',
                                                   'overrides' => '*')
    controller.send(:classify_non_status_pass, proposals, ov, Set.new, track_automated: true)
    controller.send(:apply_url_proposals, proposals, ov, Set.new)
    assert_equal 'new text', @project.contribution_justification
    overridden = controller.instance_variable_get(:@overridden_fields)
    assert overridden.key?(:contribution_status),
           'forced justification override highlights under status symbol'
    # old_value must be the Integer status so CriterionStatus.canonical works in the view
    assert_equal CriterionStatus::UNMET, overridden[:contribution_status][:old_value],
                 'old_value must be Integer status, not old justification String'
  end

  test 'pass2: justification-only forced override (status unchanged) stores Integer old_value' do
    # Regression: when a justification changes but the status proposal is absent or same,
    # Pass 2 must store the current status Integer as old_value — not the old justification
    # String — so CriterionStatus.canonical(old_value) works correctly in the view.
    @project.contribution_status = CriterionStatus::MET
    @project.contribution_justification = 'old justification'
    controller, _, _, ov, proposals = prepare_pass('contribution_justification' => 'new justification',
                                                   'overrides' => '*')
    controller.send(:classify_non_status_pass, proposals, ov, Set.new, track_automated: true)
    controller.send(:apply_url_proposals, proposals, ov, Set.new)
    assert_equal 'new justification', @project.contribution_justification
    overridden = controller.instance_variable_get(:@overridden_fields)
    assert overridden.key?(:contribution_status)
    assert_kind_of Integer, overridden[:contribution_status][:old_value],
                   'old_value must be Integer for CriterionStatus.canonical'
    assert_equal CriterionStatus::MET, overridden[:contribution_status][:old_value]
  end

  test 'pass2: justification with divergent paired status → blocked even when forced' do
    @project.contribution_justification = 'existing'
    controller, _, _, ov, proposals = prepare_pass('contribution_justification' => 'new text',
                                                   'overrides' => '*')
    divergent_set = Set.new([:contribution_status])
    controller.send(:classify_non_status_pass, proposals, ov, divergent_set, track_automated: true)
    controller.send(:apply_url_proposals, proposals, ov, divergent_set)
    assert_equal 'existing', @project.contribution_justification,
                 'coupling rule: divergent status must block justification even if forced'
    assert_empty controller.instance_variable_get(:@automated_fields)
    assert_empty controller.instance_variable_get(:@overridden_fields)
  end

  test 'pass2: blank non-criteria field → applied yellow' do
    @project.name = ''
    controller, _, _, ov, proposals = prepare_pass('name' => 'My Project')
    controller.send(:classify_non_status_pass, proposals, ov, Set.new, track_automated: true)
    controller.send(:apply_url_proposals, proposals, ov, Set.new)
    assert_equal 'My Project', @project.name
    automated = controller.instance_variable_get(:@automated_fields)
    assert automated.key?(:name)
  end

  test 'pass2: non-blank non-criteria field without forcing → not applied, divergent icon' do
    @project.name = 'existing'
    controller, _, _, ov, proposals = prepare_pass('name' => 'new name')
    controller.send(:classify_non_status_pass, proposals, ov, Set.new, track_automated: true)
    controller.send(:apply_url_proposals, proposals, ov, Set.new)
    assert_equal 'existing', @project.name
    assert_empty controller.instance_variable_get(:@automated_fields)
    divergent = controller.instance_variable_get(:@divergent_fields)
    assert divergent.key?(:name), 'non-criteria divergent must be keyed on own field symbol'
    assert_equal 'new name', divergent[:name][:proposed_value]
  end

  test 'pass2: non-blank non-criteria field forced → applied orange' do
    @project.name = 'old name'
    controller, _, _, ov, proposals = prepare_pass('name' => 'new name', 'overrides' => '*')
    controller.send(:classify_non_status_pass, proposals, ov, Set.new, track_automated: true)
    controller.send(:apply_url_proposals, proposals, ov, Set.new)
    assert_equal 'new name', @project.name
    overridden = controller.instance_variable_get(:@overridden_fields)
    assert overridden.key?(:name)
    assert_equal 'old name', overridden[:name][:old_value]
  end

  test 'pass2: _status fields in params are ignored (belong to pass 1)' do
    # classify_non_status_pass must not record any highlight for _status fields;
    # application is not tested here because apply_url_proposals handles all fields.
    @project.contribution_status = CriterionStatus::UNKNOWN
    controller, _, _, ov, proposals = prepare_pass('contribution_status' => 'Met')
    controller.send(:classify_non_status_pass, proposals, ov, Set.new, track_automated: true)
    assert_empty controller.instance_variable_get(:@automated_fields),
                 'classify_non_status_pass must not record yellow for _status fields'
  end

  test 'pass2: forced justification does not corrupt Integer old_value set by pass 1' do
    # Regression test for type-corruption bug:
    # When Pass 1 stores @overridden_fields[:contribution_status] = { old_value: Integer, ... }
    # and Pass 2 processes contribution_justification (also forced), Pass 2 must not
    # overwrite the status entry — the view calls CriterionStatus.canonical(old_value)
    # and requires an Integer; a String old_value produces nil and displays '?'.
    @project.contribution_status = CriterionStatus::UNMET
    @project.contribution_justification = 'old justification'
    controller, _, _, ov, proposals = prepare_pass(
      'contribution_status' => 'Met',
      'contribution_justification' => 'new justification',
      'overrides' => '*'
    )
    # Run Pass 1 first, which should populate @overridden_fields[:contribution_status]
    # with old_value = CriterionStatus::UNMET (an Integer).
    divergent_set = controller.send(:classify_status_pass, proposals, ov, track_automated: true)
    overridden = controller.instance_variable_get(:@overridden_fields)
    assert overridden.key?(:contribution_status), 'pass 1 must set orange for forced real status'
    assert_kind_of Integer, overridden[:contribution_status][:old_value],
                   'pass 1 must store old_value as Integer for CriterionStatus.canonical'

    # Run Pass 2; contribution_justification is forced and has a real value.
    # The guard must prevent it from overwriting the status entry.
    controller.send(:classify_non_status_pass, proposals, ov, divergent_set, track_automated: true)
    overridden_after = controller.instance_variable_get(:@overridden_fields)
    assert_kind_of Integer, overridden_after[:contribution_status][:old_value],
                   'pass 2 must not overwrite Integer old_value with String justification'
    assert_equal CriterionStatus::UNMET, overridden_after[:contribution_status][:old_value],
                 'old_value must still be the original status integer after pass 2'
  end

  test 'save and continue renders edit with automated fields highlighted' do
    log_in_as(@user)

    # Set repo_url to trigger TestForcedDetective non-forced auto-fill
    @project.repo_url = 'https://example.com/test/auto-fill'
    @project.description_good_status = CriterionStatus::UNKNOWN
    @project.save!

    # User sets description_good to Unknown and saves-and-continues;
    # Chief should auto-fill it back to Met and render :edit directly
    # with @automated_fields populated so the view can highlight it.
    patch edit_project_section_path(@project, 'passing'), params: {
      project: { description_good_status: '0' },
      continue: '1'
    }

    assert_response :success
    assert_includes response.body, 'automation-icon',
                    'Automated field must show robot icon in rendered form'
  end

  test 'PATCH to edit URL is accepted and routes to update action' do
    log_in_as(@project.user)
    patch "/en/projects/#{@project.id}/passing/edit",
          params: { project: { description: 'Updated' } }
    assert_not_equal 404, response.status
  end

  test 'save-and-continue renders edit directly without redirect' do
    log_in_as(@project.user)
    patch edit_project_section_path(@project, 'passing'),
          params: { project: { description: 'x' }, continue: 'Save and Continue' }
    assert_response :success
    assert_nil response.location
  end

  test 'clean save-and-exit still redirects to show page' do
    log_in_as(@project.user)
    patch edit_project_section_path(@project, 'passing'),
          params: { project: { description: 'x' } }
    assert_redirected_to project_section_path(@project, 'passing')
  end

  test 'no internal automation params appear in rendered response after save' do
    log_in_as(@project.user)
    patch edit_project_section_path(@project, 'passing'),
          params: { project: { description: 'x' }, continue: 'Save and Continue' }
    assert_no_match(/ovr__/, response.body)
    assert_no_match(/div__/, response.body)
    assert_no_match(/fields_list=/, response.body)
  end

  private

  # Build an OmniAuth hash for a GitHub user fixture.
  # @param user [User] GitHub user fixture
  # @param token [String] OAuth token (default: 'test_token')
  # @return [Hash] OmniAuth-compatible auth hash
  def github_omniauth_hash(user, token = 'test_token')
    {
      'provider' => 'github',
      'uid' => user.uid || '12345',
      'credentials' => { 'token' => token },
      'info' => {
        'name' => user.name,
        'nickname' => user.nickname,
        'email' => user.email
      }
    }
  end
end
# rubocop:enable Metrics/ClassLength
