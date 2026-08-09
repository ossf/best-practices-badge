# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'
require 'minitest/mock' # for stubbing the mailer to raise

# rubocop:disable Metrics/ClassLength
class RecalcTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper
  include ActiveJob::TestHelper

  test 'Make sure recalc percentages only updates levels specified' do
    project = projects(:one)
    old_percentage = project.badge_percentage_1
    assert_equal 0, old_percentage, 'Old silver percentage wrong'
    # Update some columns without triggering percentage calculation
    # or change in updated_at
    assert_no_difference [
      'Project.find(projects(:one).id).badge_percentage_0',
      'Project.find(projects(:one).id).badge_percentage_1',
      'Project.find(projects(:one).id).badge_percentage_2',
      'Project.find(projects(:one).id).updated_at'
    ] do
      project.update_column(:crypto_weaknesses_status, 3) # Met
      project.update_column(:crypto_weaknesses_justification, 'It is good')
      project.update_column(:warnings_strict_status, 3) # Met
      project.update_column(:warnings_strict_justification, 'It is good')
    end
    # Run the update task, make sure updated_at and others don't change
    assert_no_difference [
      'Project.find(projects(:one).id).updated_at',
      'Project.find(projects(:one).id).badge_percentage_0',
      'Project.find(projects(:one).id).badge_percentage_2'
    ] do
      Project.update_all_badge_percentages(['1'])
    end
    # Check the badge percentage changed
    assert_not_equal(
      Project.find(projects(:one).id).badge_percentage_1,
      old_percentage
    )
  end

  # rubocop:disable Metrics/BlockLength
  test 'Make sure recalc percentages only updates levels affected' do
    project = projects(:one)
    old_percentage0 = project.badge_percentage_0
    old_percentage1 = project.badge_percentage_1
    assert_equal 1, old_percentage0, 'Old passing percentage wrong'
    assert_equal 0, old_percentage1, 'Old silver percentage wrong'
    # Update some columns without triggering percentage calculation
    # or change in updated_at
    assert_no_difference [
      'Project.find(projects(:one).id).badge_percentage_0',
      'Project.find(projects(:one).id).badge_percentage_1',
      'Project.find(projects(:one).id).badge_percentage_2',
      'Project.find(projects(:one).id).updated_at'
    ] do
      project.update_column(:crypto_weaknesses_status, 3) # Met
      project.update_column(:crypto_weaknesses_justification, 'It is good')
      project.update_column(:warnings_strict_status, 3) # Met
      project.update_column(:warnings_strict_justification, 'It is good')
    end
    # Run the update task, make sure updated_at and others don't change
    assert_no_difference [
      'Project.find(projects(:one).id).updated_at',
      'Project.find(projects(:one).id).badge_percentage_2'
    ] do
      # Level 2 does not depend on these keys
      # so it's percentage should not change
      Project.update_all_badge_percentages(Criteria.keys)
    end
    # Check the badge percentage changed
    assert_not_equal(
      Project.find(projects(:one).id).badge_percentage_0,
      old_percentage0,
      'passing badge percentage is supposed to change'
    )
    assert_not_equal(
      Project.find(projects(:one).id).badge_percentage_1,
      old_percentage1,
      'silver badge percentage is supposed to change'
    )
  end
  # rubocop:enable Metrics/BlockLength

  test 'Raises TypeError' do
    assert_raises(TypeError) { Project.update_all_badge_percentages('1') }
  end

  test 'Raises ArgumentError' do
    assert_raises(ArgumentError) do
      Project.update_all_badge_percentages(['3'])
    end
  end

  # --- update_all_badge_percentages loss-column tests ---

  test 'update_all_badge_percentages sets unreported_badge_loss on metal loss' do
    project = projects(:one)
    project.update_column(:badge_percentage_0, 100)
    project.update_column(:tiered_percentage, 100)
    Project.update_all_badge_percentages(['0'])
    assert_equal Sections::BADGE_LEVEL_RANK['passing'],
                 Project.find(project.id).unreported_badge_loss
  end

  test 'update_all_badge_percentages sets unreported_baseline_badge_loss on baseline loss' do
    project = projects(:one)
    project.update_column(:badge_percentage_baseline_1, 100)
    Project.update_all_badge_percentages(['baseline-1'])
    assert_equal Sections::BADGE_LEVEL_RANK['baseline-1'],
                 Project.find(project.id).unreported_baseline_badge_loss
  end

  test 'update_all_badge_percentages does not set columns when notify_losses: false' do
    project = projects(:one)
    project.update_column(:badge_percentage_0, 100)
    project.update_column(:tiered_percentage, 100)
    Project.update_all_badge_percentages(['0'], notify_losses: false)
    assert_equal 0, Project.find(project.id).unreported_badge_loss
  end

  # The attempt counters bound retries, so raising a flag must reset the
  # matching one.  Without this, a project that used up its attempts on
  # an earlier notification is permanently unnotifiable, and the next
  # genuine loss or warning is dropped in silence.  That is the failure
  # this whole repair exists to prevent, so it is asserted directly
  # rather than left to the retry logic that will read these columns.
  test 'update_all_badge_percentages resets loss_send_attempts on a loss' do
    project = projects(:one)
    project.update_column(:badge_percentage_0, 100)
    project.update_column(:tiered_percentage, 100)
    project.update_column(:loss_send_attempts, 5)
    Project.update_all_badge_percentages(['0'])
    assert_equal 0, Project.find(project.id).loss_send_attempts
  end

  test 'update_all_badge_percentages resets attempts on a baseline loss' do
    project = projects(:one)
    project.update_column(:badge_percentage_baseline_1, 100)
    project.update_column(:loss_send_attempts, 5)
    Project.update_all_badge_percentages(['baseline-1'])
    assert_equal 0, Project.find(project.id).loss_send_attempts
  end

  # A recalculation that loses nothing must leave the count alone; it
  # belongs to the notification still pending, not to the run.
  test 'update_all_badge_percentages leaves attempts alone without a loss' do
    project = projects(:one)
    project.update_column(:loss_send_attempts, 5)
    Project.update_all_badge_percentages(['0'])
    assert_equal 5, Project.find(project.id).loss_send_attempts
  end

  test 'update_all_badge_warnings resets warning_send_attempts' do
    project = projects(:one)
    project.update_column(:badge_percentage_0, 100)
    project.update_column(:tiered_percentage, 100)
    project.update_column(:warning_send_attempts, 5)
    Project.update_all_badge_warnings(Criteria.keys,
                                      effective_date: Time.zone.today + 30)
    assert_equal 0, Project.find(project.id).warning_send_attempts
  end

  # A recalculation writes values we computed ourselves, so it must not
  # bump lock_version.  If it did, every owner with an edit form open
  # when criteria change would be told their entry "changed since you
  # started editing", for a change that was none of their doing.  Their
  # own save recomputes these percentages anyway, so blocking them
  # protects nothing.
  test 'update_all_badge_percentages leaves lock_version alone' do
    project = projects(:one)
    project.update_column(:badge_percentage_0, 100)
    before = Project.where(id: project.id).pick(:lock_version)
    assert_predicate before, :positive?, 'fixture must exercise a real lock'

    Project.update_all_badge_percentages(['0'])

    fresh = Project.find(project.id)
    assert_not_equal 100, fresh.badge_percentage_0,
                     'recalculation should have rewritten this'
    assert_equal before, fresh.lock_version
  end

  # --- CDN purge tests ---

  # A project that actually changed must have its cached badge and JSON
  # purged, twice: once now and once after a delay, the second closing
  # the race where a response already in flight re-caches the old badge.
  test 'update_all_badge_percentages purges each changed project' do
    settle_badge_percentages
    project = projects(:one)
    project.update_column(:badge_percentage_0, 100)
    project.update_column(:tiered_percentage, 100)
    assert_enqueued_jobs 2, only: PurgeCdnProjectJob do
      Project.update_all_badge_percentages(['0'])
    end
    assert_enqueued_with(job: PurgeCdnProjectJob,
                         args: [project.record_key])
  end

  # The old code purged the entire cache every time, on the grounds that
  # it had no cheap way to know what changed.  Rails skips the UPDATE
  # when nothing differs, so project.changed? answers that for free, and
  # a recalculation that changes nothing should cost the CDN nothing.
  test 'update_all_badge_percentages purges nothing when nothing changed' do
    settle_badge_percentages
    purged_all = false
    assert_no_enqueued_jobs only: PurgeCdnProjectJob do
      FastlyRails.stub(:purge_all, ->(*) { purged_all = true }) do
        Project.update_all_badge_percentages(['0'])
      end
    end
    assert_not purged_all
  end

  # There is no "too many changed, purge everything instead" fallback,
  # and there should not be one: a rate-limited purge is retried with
  # backoff, so a big recalculation goes slower rather than losing
  # purges, while a whole-cache purge would cold-start a very busy site.
  test 'update_all_badge_percentages never purges the whole cache' do
    settle_badge_percentages
    project = projects(:one)
    project.update_column(:badge_percentage_0, 100)
    project.update_column(:tiered_percentage, 100)
    purged_all = false
    FastlyRails.stub(:purge_all, ->(*) { purged_all = true }) do
      Project.update_all_badge_percentages(['0'])
    end
    assert_not purged_all
    assert_enqueued_with(job: PurgeCdnProjectJob,
                         args: [project.record_key])
  end

  # The fixtures' stored percentages are hand-written and do not match
  # what recalculation computes, so the first run modifies every one of
  # them.  Run it once to settle them, so that a later run changes only
  # what the test itself changed.
  def settle_badge_percentages
    Project.update_all_badge_percentages(['0'])
  end

  # --- send_loss_notifications tests ---

  test 'send_loss_notifications sends email and clears column' do
    project = projects(:one)
    project.update_column(:unreported_badge_loss, 1) # rank of 'passing'
    assert_emails(1) do
      Project.send_loss_notifications
    end
    assert_equal 0, Project.find(project.id).unreported_badge_loss
  end

  test 'send_loss_notifications sends baseline email and clears column' do
    project = projects(:one)
    project.update_column(:unreported_baseline_badge_loss, 1) # rank of 'baseline-1'
    assert_emails(1) do
      Project.send_loss_notifications
    end
    assert_equal 0, Project.find(project.id).unreported_baseline_badge_loss
  end

  # Suppression defers rather than discards.  Clearing here would mean an
  # owner who re-enables notifications gets nothing, because no new flag
  # is raised unless the badge changes level again.
  test 'send_loss_notifications keeps the flag when notifications are off' do
    project = projects(:one)
    project.user.update_column(:important_notifications, false)
    project.update_column(:unreported_badge_loss, 1)
    assert_emails(0) do
      Project.send_loss_notifications
    end
    assert_equal 1, Project.find(project.id).unreported_badge_loss
    assert_nil Project.find(project.id).last_loss_sent_at
  end

  # The point of deferring: the notification is still there to deliver.
  test 'send_loss_notifications delivers once notifications are back on' do
    project = projects(:one)
    project.user.update_column(:important_notifications, false)
    project.update_column(:unreported_badge_loss, 1)
    assert_emails(0) do
      Project.send_loss_notifications
    end
    project.user.update_column(:important_notifications, true)
    assert_emails(1) do
      Project.send_loss_notifications
    end
    assert_equal 0, Project.find(project.id).unreported_badge_loss
  end

  # The defect found while doing step 3b: the loop tested only that
  # encrypted_email was present, while the mailer also required an
  # address that decrypts and contains "@".  An owner failing only the
  # mailer's test was counted as emailed and had the flag cleared,
  # though no mail was ever created.
  test 'send_loss_notifications keeps the flag for an unusable address' do
    project = projects(:one)
    user = project.user
    user.email = 'no-at-sign'
    user.save!(validate: false)
    project.update_column(:unreported_badge_loss, 1)
    assert_emails(0) do
      assert_equal 0, Project.send_loss_notifications
    end
    assert_equal 1, Project.find(project.id).unreported_badge_loss
  end

  test 'send_loss_notifications skips email if badge already regained' do
    # perfect_passing has tiered_percentage >= 100, so badge_level = 'passing'.
    # Setting unreported_badge_loss = 1 (passing) means the loss is no longer
    # current — the badge was regained — so no email should be sent.
    project = projects(:perfect_passing)
    project.update_column(:unreported_badge_loss, 1)
    assert_emails(0) do
      Project.send_loss_notifications
    end
    assert_equal 0, Project.find(project.id).unreported_badge_loss
  end

  test 'send_loss_notifications sets last_loss_sent_at' do
    project = projects(:one)
    project.update_column(:unreported_badge_loss, 1)
    assert_nil Project.find(project.id).last_loss_sent_at
    Project.send_loss_notifications
    assert_not_nil Project.find(project.id).last_loss_sent_at
  end

  # Idempotency. A second run must send nothing, because the first run
  # cleared the flag.  When clearing silently failed, the same email went
  # out every night for weeks; see docs/warning_failures.md.
  test 'send_loss_notifications does not repeat on a second run' do
    project = projects(:one)
    project.update_column(:unreported_badge_loss, 1)
    assert_emails(1) do
      Project.send_loss_notifications
    end
    assert_emails(0) do
      Project.send_loss_notifications
    end
  end

  test 'send_loss_notifications does not repeat baseline mail on a second run' do
    project = projects(:one)
    project.update_column(:unreported_baseline_badge_loss, 1)
    assert_emails(1) do
      Project.send_loss_notifications
    end
    assert_emails(0) do
      Project.send_loss_notifications
    end
  end

  # Notification bookkeeping must not disturb the edit flow.  If clearing a
  # flag bumped lock_version, an owner with the edit form already open would
  # be told their entry "changed since you started editing" when none of
  # their content had.
  test 'clearing a notification flag leaves lock_version alone' do
    project = projects(:one)
    project.update_column(:unreported_baseline_badge_warning, 1)
    before = Project.where(id: project.id).pick(:lock_version)
    assert_predicate before, :positive?, 'fixture must exercise a real lock'
    Project.send_warning_notifications
    assert_equal before, Project.where(id: project.id).pick(:lock_version)
  end

  test 'clearing a loss flag leaves lock_version alone' do
    project = projects(:one)
    project.update_column(:unreported_badge_loss, 1)
    before = Project.where(id: project.id).pick(:lock_version)
    Project.send_loss_notifications
    assert_equal before, Project.where(id: project.id).pick(:lock_version)
  end

  # Reaching the cap partway through a project must stop immediately: the
  # kind already handled is cleared, and the next kind of that same project
  # is left pending for the next run rather than being sent over the cap.
  test 'send_notifications stops at the cap partway through a project' do
    project = projects(:one)
    project.update_column(:unreported_badge_warning, 1)
    project.update_column(:unreported_baseline_badge_warning, 1)
    sent =
      Project.send(
        :send_notifications, Project.where(id: project.id), 1,
        Project::NOTIFICATION_SERIES[:warning]
      ) { |_project, _user, _level, _suffix| :sent }
    assert_equal 1, sent
    fresh = Project.find(project.id)
    assert_equal 0, fresh.unreported_badge_warning
    assert_equal 1, fresh.unreported_baseline_badge_warning
  end

  # Column names are interpolated into the UPDATE, so anything that is not
  # a real column must be refused rather than reaching the database.
  test 'write_bookkeeping_columns refuses a name that is not a column' do
    assert_raises(ArgumentError) do
      Project.send(
        :write_bookkeeping_columns, projects(:one),
        'unreported_badge_loss = 0; DROP TABLE projects; --' => 1
      )
    end
    assert_raises(ArgumentError) do
      Project.send(:write_bookkeeping_columns, projects(:one), no_such_column: 1)
    end
  end

  # The failure path must be noisy.  A bookkeeping write that quietly
  # changed nothing is exactly what let the same emails go out night after
  # night; see docs/warning_failures.md.
  test 'write_bookkeeping_columns reports a write that matches no rows' do
    missing = Project.new
    missing.id = -1 # no such row, so the update matches nothing
    logged = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(logged)
    begin
      assert_not Project.send(
        :write_bookkeeping_columns, missing, unreported_badge_loss: 0
      )
    ensure
      Rails.logger = original_logger
    end
    assert_match(/affected 0 rows/, logged.string)
    assert_match(/project -1/, logged.string)
  end

  # A block that answers in the old Boolean vocabulary must fail loudly.
  # Read as an outcome, "true" is simply unknown, and the quiet reading of
  # an unknown answer is "no mail was sent", which would undercount
  # silently and, once outcomes drive clearing, mishandle the flag.
  test 'send_notifications rejects an unknown outcome' do
    project = projects(:one)
    project.update_column(:unreported_badge_warning, 1)
    error =
      assert_raises(ArgumentError) do
        Project.send(
          :send_notifications, Project.where(id: project.id), 1,
          Project::NOTIFICATION_SERIES[:warning]
        ) { |_project, _user, _level, _suffix| true }
      end
    assert_match(/Unknown notification outcome/, error.message)
  end

  # Every outcome the vocabulary defines must be handled, not just the
  # ones today's two mailers happen to return.  Only :sent counts, and
  # the flag survives exactly the outcomes that expect another try.
  test 'send_notifications handles every outcome' do
    project = projects(:one)
    flag_after = {
      sent: 0, not_relevant: 0, suppressed: 1,
      transient_failure: 1, permanent_failure: 0
    }
    Project::NOTIFICATION_OUTCOMES.each do |outcome|
      project.update_column(:unreported_badge_warning, 1)
      project.update_column(:warning_send_attempts, 0)
      sent =
        Project.send(
          :send_notifications, Project.where(id: project.id), 1,
          Project::NOTIFICATION_SERIES[:warning]
        ) { |_project, _user, _level, _suffix| outcome }
      assert_equal (outcome == :sent ? 1 : 0), sent, "counted #{outcome}"
      assert_equal flag_after[outcome],
                   Project.find(project.id).unreported_badge_warning,
                   "flag after #{outcome}"
    end
  end

  # The counter must report mail actually sent.  perfect_passing has
  # regained the level, so send_loss_email returns :not_relevant and
  # nothing is sent; the count previously included such projects anyway.
  test 'send_loss_notifications does not count declined mail' do
    project = projects(:perfect_passing)
    project.update_column(:unreported_badge_loss, 1)
    assert_equal 0, Project.send_loss_notifications
  end

  # The sent-at columns are the record of delivery now that mail goes out
  # synchronously, so a notification that was never sent must not stamp
  # one.  Claiming a delivery that did not happen is the misleading state
  # that made this incident hard to diagnose.
  test 'send_loss_notifications records no delivery when not relevant' do
    project = projects(:perfect_passing)
    project.update_column(:unreported_badge_loss, 1)
    Project.send_loss_notifications
    fresh = Project.find(project.id)
    assert_equal 0, fresh.unreported_badge_loss
    assert_nil fresh.last_loss_sent_at
  end

  # --- delivery failure tests ---

  # Raise +error+ from the loss mailer for one pending project, and
  # return that project reloaded.
  def failing_loss_run(error, attempts: 0)
    project = projects(:one)
    project.update_column(:unreported_badge_loss, 1)
    project.update_column(:loss_send_attempts, attempts)
    ReportMailer.stub(:email_owner_with_user, ->(*) { raise error }) do
      assert_equal 0, Project.send_loss_notifications
    end
    Project.find(project.id)
  end

  # A transient failure keeps the notification for another night, and
  # counts the attempt so that "try again later" stays bounded.
  test 'send_loss_notifications keeps the flag after a transient failure' do
    fresh = failing_loss_run(Net::SMTPServerBusy.new('busy'))
    assert_equal 1, fresh.unreported_badge_loss
    assert_equal 1, fresh.loss_send_attempts
    assert_nil fresh.last_loss_sent_at
  end

  # An unrecognized failure must be treated as transient.  Guessing
  # "permanent" would drop the notification with no bound and no signal;
  # guessing "transient" costs at most MAX_NOTIFICATION_ATTEMPTS tries
  # and then reports.
  test 'send_loss_notifications treats an unknown failure as transient' do
    fresh = failing_loss_run(RuntimeError.new('something new'))
    assert_equal 1, fresh.unreported_badge_loss
    assert_equal 1, fresh.loss_send_attempts
  end

  # A 5xx will not improve overnight, so retrying only delays the report
  # and spends the attempt budget for nothing.
  test 'send_loss_notifications gives up at once on a permanent failure' do
    fresh = failing_loss_run(Net::SMTPFatalError.new('rejected'))
    assert_equal 0, fresh.unreported_badge_loss
    assert_equal 1, fresh.loss_send_attempts
    assert_nil fresh.last_loss_sent_at
  end

  # The bound itself: without it, a permanently failing address is this
  # incident again, one attempt per night forever.  Giving up must be
  # loud, because the owner never hears the message we abandoned.
  test 'send_loss_notifications gives up once the attempts run out' do
    logged = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(logged)
    begin
      fresh = failing_loss_run(
        Net::SMTPServerBusy.new('busy'),
        attempts: Project::MAX_NOTIFICATION_ATTEMPTS - 1
      )
    ensure
      Rails.logger = original_logger
    end
    assert_equal 0, fresh.unreported_badge_loss
    assert_equal Project::MAX_NOTIFICATION_ATTEMPTS,
                 fresh.loss_send_attempts
    assert_nil fresh.last_loss_sent_at
    assert_match(/Abandoning unreported_badge_loss/, logged.string)
    assert_match(/transient_failure/, logged.string)
  end

  # --- update_all_badge_warnings tests ---

  test 'update_all_badge_warnings sets unreported_badge_warning on metal loss' do
    project = projects(:one)
    project.update_column(:badge_percentage_0, 100)
    project.update_column(:tiered_percentage, 100)
    Project.update_all_badge_warnings(Criteria.keys,
                                      effective_date: Time.zone.today + 30)
    assert_equal Sections::BADGE_LEVEL_RANK['passing'],
                 Project.find(project.id).unreported_badge_warning
  end

  test 'update_all_badge_warnings sets badge_warning_effective_date' do
    project = projects(:one)
    project.update_column(:badge_percentage_0, 100)
    project.update_column(:tiered_percentage, 100)
    future_date = Time.zone.today + 30
    Project.update_all_badge_warnings(Criteria.keys,
                                      effective_date: future_date)
    assert_equal future_date,
                 Project.find(project.id).badge_warning_effective_date
  end

  test 'update_all_badge_warnings does not change badge_percentage_0 in DB' do
    project = projects(:one)
    project.update_column(:badge_percentage_0, 100)
    project.update_column(:tiered_percentage, 100)
    Project.update_all_badge_warnings(Criteria.keys,
                                      effective_date: Time.zone.today + 30)
    assert_equal 100, Project.find(project.id).badge_percentage_0
  end

  test 'update_all_badge_warnings sets unreported_baseline_badge_warning' do
    project = projects(:one)
    project.update_column(:badge_percentage_baseline_1, 100)
    Project.update_all_badge_warnings(['baseline-1'],
                                      effective_date: Time.zone.today + 30)
    assert_equal Sections::BADGE_LEVEL_RANK['baseline-1'],
                 Project.find(project.id).unreported_baseline_badge_warning
  end

  test 'update_all_badge_warnings with report: true prints project info' do
    project = projects(:one)
    project.update_column(:badge_percentage_0, 100)
    project.update_column(:tiered_percentage, 100)
    assert_output(/Project #{project.id}/) do
      Project.update_all_badge_warnings(Criteria.keys,
                                        effective_date: Time.zone.today + 30,
                                        report: true)
    end
    # Must not write warning columns in report mode
    assert_equal 0, Project.find(project.id).unreported_badge_warning
  end

  test 'update_all_badge_warnings report: true prints baseline info' do
    project = projects(:one)
    project.update_column(:badge_percentage_baseline_1, 100)
    assert_output(/\(baseline\)/) do
      Project.update_all_badge_warnings(['baseline-1'],
                                        effective_date: Time.zone.today + 30,
                                        report: true)
    end
    # Must not write warning columns in report mode
    assert_equal 0, Project.find(project.id).unreported_baseline_badge_warning
  end

  # --- end-of-run invariant tests ---

  # Run +block+ with the log captured, and return what was logged.
  def captured_log
    logged = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(logged)
    begin
      yield
    ensure
      Rails.logger = original_logger
    end
    logged.string
  end

  # The check that does not take the other layers at their word.  This is
  # the original defect's exact signature: every write reports success,
  # the count of mail sent looks right, and the flags are all still set.
  # Simulated by making the write a no-op that still claims one row.
  test 'send_loss_notifications reports a queue that did not drain' do
    project = projects(:one)
    project.update_column(:unreported_badge_loss, 1)
    log =
      captured_log do
        Project.stub(:update_one_project, 1) do
          assert_equal 1, Project.send_loss_notifications
        end
      end
    assert_equal 1, Project.find(project.id).unreported_badge_loss
    assert_match(/Notification queue did not drain/, log)
    assert_match(/1 projects still pending/, log)
  end

  test 'send_loss_notifications says nothing when the queue drains' do
    project = projects(:one)
    project.update_column(:unreported_badge_loss, 1)
    log = captured_log { Project.send_loss_notifications }
    assert_equal 0, Project.find(project.id).unreported_badge_loss
    assert_no_match(/did not drain/, log)
  end

  # A deliberate deferral is not a stuck queue.  If this alarmed, it
  # would alarm every night for as long as an owner stayed opted out,
  # and a nightly false alarm is the habit that let the original defect
  # run for five weeks.
  test 'send_loss_notifications does not alarm about a deferred owner' do
    project = projects(:one)
    project.user.update_column(:important_notifications, false)
    project.update_column(:unreported_badge_loss, 1)
    log = captured_log { Project.send_loss_notifications }
    assert_equal 1, Project.find(project.id).unreported_badge_loss
    assert_no_match(/did not drain/, log)
  end

  test 'send_loss_notifications does not alarm about a pending retry' do
    log =
      captured_log do
        failing_loss_run(Net::SMTPServerBusy.new('busy'))
      end
    assert_no_match(/did not drain/, log)
  end

  # Reaching the cap leaves work behind legitimately, and we have not
  # looked at the rest, so there is nothing to conclude and nothing to
  # report.
  test 'send_notifications does not alarm when it stops at the cap' do
    project = projects(:one)
    project.update_column(:unreported_badge_warning, 1)
    project.update_column(:unreported_baseline_badge_warning, 1)
    log =
      captured_log do
        Project.send(
          :send_notifications, Project.where(id: project.id), 1,
          Project::NOTIFICATION_SERIES[:warning]
        ) { |_project, _user, _level, _suffix| :sent }
      end
    assert_equal 1, Project.find(project.id).unreported_baseline_badge_warning
    assert_no_match(/did not drain/, log)
  end

  # The cap can also fall between two projects rather than between two
  # kinds of one project.  The next project must not be examined at all,
  # and its untouched flag must not be reported as a queue that failed
  # to drain.
  test 'send_notifications stops between projects at the cap' do
    ids = [projects(:one).id, projects(:two).id].sort
    ids.each do |id|
      Project.find(id).update_column(:unreported_badge_warning, 1)
    end
    log =
      captured_log do
        sent =
          Project.send(
            :send_notifications, Project.where(id: ids).reorder(:id), 1,
            Project::NOTIFICATION_SERIES[:warning]
          ) { |_project, _user, _level, _suffix| :sent }
        assert_equal 1, sent
      end
    assert_equal 0, Project.find(ids.first).unreported_badge_warning
    assert_equal 1, Project.find(ids.second).unreported_badge_warning
    assert_no_match(/did not drain/, log)
  end

  # --- send_warning_notifications tests ---

  test 'send_warning_notifications sends email and clears column' do
    project = projects(:one)
    project.update_column(:unreported_badge_warning, 1) # rank of 'passing'
    assert_emails(1) do
      Project.send_warning_notifications
    end
    assert_equal 0, Project.find(project.id).unreported_badge_warning
  end

  test 'send_warning_notifications sends baseline email and clears column' do
    project = projects(:one)
    project.update_column(:unreported_baseline_badge_warning, 1)
    assert_emails(1) do
      Project.send_warning_notifications
    end
    assert_equal 0, Project.find(project.id).unreported_baseline_badge_warning
  end

  test 'send_warning_notifications keeps the flag when notifications are off' do
    project = projects(:one)
    project.user.update_column(:important_notifications, false)
    project.update_column(:unreported_badge_warning, 1)
    assert_emails(0) do
      Project.send_warning_notifications
    end
    assert_equal 1, Project.find(project.id).unreported_badge_warning
    assert_nil Project.find(project.id).last_warning_sent_at
  end

  test 'send_warning_notifications sets last_warning_sent_at' do
    project = projects(:one)
    project.update_column(:unreported_badge_warning, 1)
    assert_nil Project.find(project.id).last_warning_sent_at
    Project.send_warning_notifications
    assert_not_nil Project.find(project.id).last_warning_sent_at
  end

  test 'send_warning_notifications does not repeat on a second run' do
    project = projects(:one)
    project.update_column(:unreported_badge_warning, 1)
    assert_emails(1) do
      Project.send_warning_notifications
    end
    assert_emails(0) do
      Project.send_warning_notifications
    end
  end

  test 'send_warning_notifications does not repeat baseline mail on a second run' do
    project = projects(:one)
    project.update_column(:unreported_baseline_badge_warning, 1)
    assert_emails(1) do
      Project.send_warning_notifications
    end
    assert_emails(0) do
      Project.send_warning_notifications
    end
  end

  # Relevance guard.  A warning announces a deadline, so once that date
  # is past the message would state a deadline in the past.  The 11 stale
  # flags of 2026-07-31 had to be cleared by hand for exactly this
  # reason; see docs/warning_failures.md.
  test 'send_warning_notifications skips a warning whose date has passed' do
    project = projects(:one)
    project.update_column(:unreported_badge_warning, 1)
    project.update_column(:badge_warning_effective_date,
                          Time.zone.today - 1)
    assert_emails(0) do
      Project.send_warning_notifications
    end
    assert_equal 0, Project.find(project.id).unreported_badge_warning
  end

  test 'send_warning_notifications skips a stale baseline warning' do
    project = projects(:one)
    project.update_column(:unreported_baseline_badge_warning, 1)
    project.update_column(:badge_warning_effective_date,
                          Time.zone.today - 1)
    assert_emails(0) do
      Project.send_warning_notifications
    end
    assert_equal 0,
                 Project.find(project.id).unreported_baseline_badge_warning
  end

  # The deadline is the last day the warning is true, not the first day
  # it is stale, so a warning due today is still worth sending.
  test 'send_warning_notifications still warns on the effective date' do
    project = projects(:one)
    project.update_column(:unreported_badge_warning, 1)
    project.update_column(:badge_warning_effective_date, Time.zone.today)
    assert_emails(1) do
      Project.send_warning_notifications
    end
  end

  # Deliberate: with no date recorded we cannot show the deadline has
  # passed, and skipping would discard the notification silently, which
  # is the failure this whole repair exists to stop.  Warn instead.
  test 'send_warning_notifications warns when no date was recorded' do
    project = projects(:one)
    project.update_column(:unreported_badge_warning, 1)
    assert_nil Project.find(project.id).badge_warning_effective_date
    assert_emails(1) do
      Project.send_warning_notifications
    end
  end
end
# rubocop:enable Metrics/ClassLength
