# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'
# See http://guides.rubyonrails.org/testing.html#testing-your-mailers

# rubocop:disable Metrics/ClassLength
class ReportMailerTest < ActionMailer::TestCase
  setup do
    @perfect_project = projects(:perfect_passing)
    # @user = users(:test_user)
  end

  test 'Does ReportMailer project_status_change send anything?' do
    email = ReportMailer.project_status_change(
      @perfect_project, false, true
    ).deliver_now
    assert_not ActionMailer::Base.deliveries.empty?
    # We don't want to modify the test when we reconfigure things.
    # So instead of insisting on specific values, we'll just
    # do a 'smoke test' to quickly check that it's sane.
    assert_predicate email.from, :present?
    assert_predicate email.to, :present?
    assert_predicate email.subject, :present?
  end

  test 'email_owner gained metal badge uses /badge suffix' do
    email = ReportMailer.email_owner(
      @perfect_project, 'in_progress', 'passing', false, 'badge'
    ).deliver_now
    assert_not ActionMailer::Base.deliveries.empty?
    assert_includes email.body.to_s, '/badge'
    assert_not_includes email.body.to_s, '/baseline'
  end

  test 'email_owner gained baseline badge uses /baseline suffix' do
    email = ReportMailer.email_owner(
      @perfect_project, 'in_progress', 'baseline-1', false, 'baseline'
    ).deliver_now
    assert_not ActionMailer::Base.deliveries.empty?
    assert_includes email.body.to_s, '/baseline'
    assert_not_includes email.body.to_s, '/badge'
  end

  test 'warn_owner_with_user sends warning email' do
    project = projects(:one)
    project.update_column(:badge_warning_effective_date, Time.zone.today + 30)
    user = project.user
    email = ReportMailer.warn_owner_with_user(
      project, user, 'passing', 'badge'
    ).deliver_now
    assert_not ActionMailer::Base.deliveries.empty?
    assert_predicate email.from, :present?
    assert_predicate email.to, :present?
    assert_predicate email.subject, :present?
  end

  test 'warn_owner_with_user names the date when there is one' do
    project = projects(:one)
    project.update_column(:badge_warning_effective_date, Time.zone.today + 30)
    email = ReportMailer.warn_owner_with_user(
      project, project.user, 'passing', 'badge'
    ).deliver_now
    assert_includes email.body.to_s, (Time.zone.today + 30).to_s
    assert_includes email.body.to_s, 'before that date'
  end

  # A warning with no recorded date is still sent, because a fault in our
  # bookkeeping is a poor reason to leave an owner unwarned.  It must not
  # name a day it does not know: no stray "lost on ." and no dangling
  # reference to a date the message never gave.
  test 'warn_owner_with_user warns without a date when none was recorded' do
    project = projects(:one)
    assert_nil project.badge_warning_effective_date
    email = ReportMailer.warn_owner_with_user(
      project, project.user, 'passing', 'badge'
    ).deliver_now
    body = email.body.to_s
    assert_includes body, 'may be'
    assert_includes body, 'lost when updated criteria take effect'
    assert_not_includes body, 'lost on'
    assert_not_includes body, 'before that date'
  end

  test 'warn_owner_with_user sends no email for nil project' do
    before = ActionMailer::Base.deliveries.count
    ReportMailer.warn_owner_with_user(nil, users(:test_user), 'passing', 'badge').deliver_now
    assert_equal before, ActionMailer::Base.deliveries.count
  end

  test 'warn_owner_with_user sends no email for project with nil id' do
    project = Project.new
    before = ActionMailer::Base.deliveries.count
    ReportMailer.warn_owner_with_user(project, users(:test_user), 'passing', 'badge').deliver_now
    assert_equal before, ActionMailer::Base.deliveries.count
  end

  test 'warn_owner_with_user sends no email for nil user' do
    before = ActionMailer::Base.deliveries.count
    ReportMailer.warn_owner_with_user(projects(:one), nil, 'passing', 'badge').deliver_now
    assert_equal before, ActionMailer::Base.deliveries.count
  end

  test 'warn_owner_with_user sends no email when email cannot be decrypted' do
    project = projects(:one)
    user = project.user
    def user.email_if_decryptable = 'CANNOT_DECRYPT'
    before = ActionMailer::Base.deliveries.count
    ReportMailer.warn_owner_with_user(project, user, 'passing', 'badge').deliver_now
    assert_equal before, ActionMailer::Base.deliveries.count
  end

  test 'warn_owner_with_user sends no email when email lacks @' do
    project = projects(:one)
    user = project.user
    def user.email_if_decryptable = 'noemail'
    def user.email? = true
    before = ActionMailer::Base.deliveries.count
    ReportMailer.warn_owner_with_user(project, user, 'passing', 'badge').deliver_now
    assert_equal before, ActionMailer::Base.deliveries.count
  end

  test 'Does the monthly announcement run?' do
    # This is a quick sanity test, not an in-depth test.
    # Use 'example.org' per RFC 2606
    ENV['REPORT_MONTHLY_EMAIL'] = 'mytest@example.org'
    awesome_projects = [
      [
        projects(:perfect_passing), projects(:perfect_silver),
        projects(:perfect)
      ], [projects(:perfect_silver), projects(:perfect)],
      [projects(:perfect)]
    ]
    email = ReportMailer
            .report_monthly_announcement(
              awesome_projects, '2015-02',
              project_stats(:one), project_stats(:two)
            )
            .deliver_now
    ENV['REPORT_MONTHLY_EMAIL'] = nil # Erase environment variable
    assert_not ActionMailer::Base.deliveries.empty?
    # We don't want to modify the test when we reconfigure things.
    # So instead of insisting on specific values, we'll just
    # do a 'smoke test' to quickly check that it's sane.
    assert_predicate email.from, :present?
    assert_predicate email.to, :present?
    assert_predicate email.subject, :present?
  end
end
# rubocop:enable Metrics/ClassLength
