# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# Full round-trip tests for docs/login-session-implementation.md section 15:
# a stashed pending resubmission must survive both local login and GitHub
# OAuth login (which leaves the site entirely and comes back), because
# counter_fixation's reset_session runs unconditionally on every login
# attempt, success or failure. Since docs/login-session-18.md's "Step 21",
# the token rides the login redirect's own request params, the same way a
# real browser's login-form hidden field or GitHub auth link would carry it,
# rather than session; these tests thread it through that way instead of
# reading it back from session mid-flow.
# rubocop:disable Metrics/ClassLength
class PendingResubmissionTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:one)
    @user = users(:test_user) # local user, owns @project
  end

  test 'local login carries the stash through and the resume button resubmits it' do
    new_name = "#{@project.name}_resubmitted"

    patch "/en/projects/#{@project.id}", params: { project: { name: new_name } }
    token = pending_resubmission_token_from_redirect
    assert_not_nil token
    assert_nil session[:pending_resubmission_token] # not written until login succeeds

    log_in_with_token(token)
    assert_redirected_to pending_resubmission_path
    # counter_fixation resets the session on every login attempt; confirm
    # the token actually survived via this login's own request param,
    # rather than this redirect happening to be right for some other
    # reason.
    assert_equal token, session[:pending_resubmission_token]

    follow_redirect!
    assert_response :success
    assert_select "input[type='hidden'][name='project[name]'][value='#{new_name}']"
    assert_select "input[type='hidden'][name='pending_resubmission_token'][value='#{token}']"

    # Click "Resume saving your changes." (the token rides along as a
    # hidden field, the same as the rendered form above.)
    patch "/en/projects/#{@project.id}", params: {
      project: { name: new_name }, pending_resubmission_token: token
    }
    @project.reload
    assert_equal new_name, @project.name

    # docs/login-session-evaluation.md finding #4: resubmitting is what finally consumes the
    # stash (ApplicationController#finalize_pending_resubmission), not the
    # earlier GET that rendered it.
    assert_not PendingResubmission.exists?(hashed_random_id: PendingResubmission.digest(token))
    assert_nil session[:pending_resubmission_token]
  end

  test 'revisiting after a closed tab (a fresh GET) still shows the stash' do
    # docs/login-session-evaluation.md finding #4: the old design destroyed the row and
    # session key on the first GET, so a closed tab (before ever clicking
    # "Resume") lost the edit for good. A second, independent GET (e.g.
    # "reopen closed tab", a fresh request, not a cached page) must work.
    new_name = "#{@project.name}_resubmitted"
    patch "/en/projects/#{@project.id}", params: { project: { name: new_name } }
    log_in_with_token(pending_resubmission_token_from_redirect)
    follow_redirect! # first view of the resume page; tab "closes" here

    get pending_resubmission_path
    assert_response :success
    assert_select "input[type='hidden'][name='project[name]'][value='#{new_name}']"

    patch "/en/projects/#{@project.id}", params: {
      project: { name: new_name }, pending_resubmission_token: session[:pending_resubmission_token]
    }
    @project.reload
    assert_equal new_name, @project.name
  end

  test 'a failed login attempt does not lose the stash' do
    patch "/en/projects/#{@project.id}", params: { project: { name: 'attempt' } }
    token = pending_resubmission_token_from_redirect
    assert_not_nil token

    log_in_with_token(token, password: 'wrong-password')
    assert_response :success # re-renders the login form; login failed
    # Login failed, so this never reached successful_login; the token
    # survives only because the re-rendered form echoes back this same
    # request's own pending_resubmission_token param, ready for a retry
    # with the correct password, not via session.
    assert_select "input[type='hidden'][name='session[pending_resubmission_token]']" \
                  "[value='#{token}']"
    assert PendingResubmission.exists?(hashed_random_id: PendingResubmission.digest(token))
  end

  test 'github oauth login carries the stash across the round trip' do
    patch "/en/projects/#{@project.id}", params: { project: { name: 'via github' } }
    token = pending_resubmission_token_from_redirect
    assert_not_nil token

    github_user = users(:github_user)
    # Both github-provider fixtures leave :uid unset (NULL for both), so
    # give it a real one first rather than relying on the mock's fallback
    # to disambiguate.
    github_user.update!(uid: 'github-test-uid')
    OmniAuth.config.test_mode = true
    OmniAuth.config.add_mock(
      :github,
      'provider' => 'github',
      'uid' => github_user.uid,
      'credentials' => { 'token' => 'test_token' },
      'info' => {
        'name' => github_user.name,
        'nickname' => github_user.nickname,
        'email' => github_user.email
      }
    )
    # Hits the request phase first, with the token as a query param the
    # same way the login page's "Log in with GitHub" link builds it, so
    # OmniAuth's own session['omniauth.params'] round trip actually
    # carries it across the redirect to GitHub and back, rather than this
    # test jumping straight to the callback and skipping that entirely.
    # POST, not GET: OmniAuth 2.x's default allowed_request_methods is
    # [:post] only, matching this app's own link (method: 'post'); a GET
    # here just 404s. The token rides the URL's own query string, not
    # the params: hash, since Rails' post/params: encodes that into the
    # request body, but OmniAuth reads request.GET (query string only),
    # the same as the real link.
    post "/auth/github?pending_resubmission_token=#{ERB::Util.url_encode(token)}"
    assert_response :redirect
    follow_redirect!
    assert_redirected_to pending_resubmission_path
  ensure
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:github] = nil
  end

  test 'merely viewing the login page the stash redirect sends you to does not destroy it' do
    # Regression test for a real incident on staging (2026-09-12):
    # ApplicationController#finalize_pending_resubmission used to be a
    # before_action, firing on ANY request carrying a pending_resubmission_token
    # param. redirect_to_login_stashing embeds that exact token in the
    # /login URL it redirects to (so the login page's view can thread it
    # into the GitHub/local-login links), so simply following that
    # redirect (a GET, not a resubmission) destroyed the row before the
    # user had even logged in, let alone resubmitted anything.
    patch "/en/projects/#{@project.id}", params: { project: { name: 'never resubmitted yet' } }
    token = pending_resubmission_token_from_redirect
    assert_not_nil token

    follow_redirect! # GET /en/login?pending_resubmission_token=...&return_to=...
    assert_response :success
    assert PendingResubmission.exists?(hashed_random_id: PendingResubmission.digest(token))

    # The normal flow still works fine afterward: logging in still resumes it.
    log_in_with_token(token)
    assert_redirected_to pending_resubmission_path
  end

  test 'a successful resubmission destroys the stash' do
    new_name = "#{@project.name}_resubmitted"
    patch "/en/projects/#{@project.id}", params: { project: { name: new_name } }
    token = pending_resubmission_token_from_redirect
    log_in_with_token(token)
    follow_redirect!

    patch "/en/projects/#{@project.id}", params: {
      project: { name: new_name }, pending_resubmission_token: token
    }
    @project.reload
    assert_equal new_name, @project.name
    assert_not PendingResubmission.exists?(hashed_random_id: PendingResubmission.digest(token))
  end

  test 'a resubmission that fails validation keeps the stash' do
    # finalize_pending_resubmission must only fire once we KNOW the change
    # was accepted (ProjectsController#successful_update only runs inside
    # `if @project.save`), not merely because a PATCH carrying the token
    # arrived: otherwise a validation failure on resubmission would lose
    # the draft for good, exactly what this whole feature exists to
    # prevent. TextValidator (app/validators/text_validator.rb) rejects
    # control characters, giving a reliable, unconditional validation
    # failure regardless of the project's other field values.
    patch "/en/projects/#{@project.id}", params: { project: { name: 'will retry' } }
    token = pending_resubmission_token_from_redirect
    log_in_with_token(token)
    follow_redirect!

    patch "/en/projects/#{@project.id}", params: {
      project: { name: "bad\x01name" }, pending_resubmission_token: token
    }
    assert_response :success # re-renders :edit; the save failed
    assert PendingResubmission.exists?(hashed_random_id: PendingResubmission.digest(token))
  end

  test 'a successful user-profile resubmission destroys the stash too' do
    # UsersController#update's `if @user.save` branch finalizes a pending
    # resubmission the same way ProjectsController#successful_update does;
    # this exercises that call site specifically; the tests above only
    # cover the ProjectsController one. Reuses the 'foo@bar.com' email
    # change and its matching VCR cassette from
    # test/integration/users_edit_test.rb's "successful edit" test: any
    # successful save by a local-provider user calls User#gravatar_exists?
    # (an HTTP HEAD to Gravatar), whether or not this particular update
    # actually changes the email, so the resubmit step needs a cassette
    # recorded for whatever email ends up saved.
    new_name = "#{@user.name}_resubmitted"
    patch "/en/users/#{@user.id}", params: { user: { name: new_name } }
    token = pending_resubmission_token_from_redirect
    assert_not_nil token

    log_in_with_token(token)
    follow_redirect!

    VCR.use_cassette('successful_edit_-_name_email') do
      patch "/en/users/#{@user.id}", params: {
        user: { name: new_name, email: 'foo@bar.com' }, pending_resubmission_token: token
      }
    end
    @user.reload
    assert_equal new_name, @user.name
    assert_not PendingResubmission.exists?(hashed_random_id: PendingResubmission.digest(token))
  end

  test 'a login without its own pending_resubmission_token never resumes a leftover one' do
    # Regression guard for the cross-user disclosure docs/login-session-18.md
    # "Step 21" closes: on a shared browser, an earlier abandoned stash must
    # not be resumed by a later, unrelated login that never carried its own
    # pending_resubmission_token param.
    patch "/en/projects/#{@project.id}", params: { project: { name: 'someone else' } }
    assert_not_nil pending_resubmission_token_from_redirect

    post login_path, params: {
      session: { email: @user.email, password: 'password', provider: 'local' }
    }
    assert_response :redirect
    assert_not_equal pending_resubmission_path, URI.parse(response.location).path
    assert_nil session[:pending_resubmission_token]
  end

  private

  # Extracts pending_resubmission_token from the most recent response's
  # redirect location, the same way a browser reads it off the URL it was
  # sent to rather than by peeking at session.
  def pending_resubmission_token_from_redirect
    Rack::Utils.parse_nested_query(URI.parse(response.location).query)[
      'pending_resubmission_token'
    ]
  end

  # Logs @user in locally, carrying the given pending_resubmission_token
  # as this login request's own param (docs/login-session-18.md "Step 21").
  def log_in_with_token(token, password: 'password')
    post login_path, params: {
      session: {
        email: @user.email, password: password, provider: 'local',
        pending_resubmission_token: token
      }
    }
  end
end
# rubocop:enable Metrics/ClassLength
