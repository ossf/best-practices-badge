# Badge warning and loss notification failures

This document records a defect found on 2026-07-31 in the badge-loss and
badge-warning notification code, the evidence that identifies its cause,
its effect on our users, and the options for repairing it.

The defect caused the same notification emails to be re-sent every night,
in the worst case for 35 consecutive nights, while the daily task
reported success and the database recorded nothing at all.

## Where this stands, and how to resume

Written 2026-08-01 at the end of the first working session, updated
2026-08-03.

### Where the work lives

Branch `notification_write_fix`, pushed, with draft pull request
[#2893](https://github.com/ossf/best-practices-badge/pull/2893) open
against `main`:

| Commit | Contents |
| ------ | -------- |
| `104f4634` | this document |
| `c66c0f86` | set 1, the defect fix |
| `0431d26a` | set 2, the unification |
| `a9e18a6e` | set 3 subdivided, deployment deferred |
| `d482f123` | step 3a, the outcome vocabulary |
| `0ce23368` | step 3b, synchronous delivery |
| `ae8020ff` | step 3c, the warning relevance guard |
| `97ac2930` | step 3c follow-up, the no-deadline message |
| `3001e0b0` | step 3d, suppression defers |
| `7aca2c1a` | step 3e-1, the attempt counters and their reset |
| `c308f004` | step 3e-2, classification and bounded retry |
| `1eb214e8` | step 3f, the end-of-run check |
| `c6b372ff` | simplifying that loop, and full local `rake` |

Sets 1 to 3 are pushed as of 2026-08-03, and `rake default` passes
locally at that point, coverage included. Every check on GitHub passes
for them: the test build, Brakeman, all four CodeQL analyses, DCO,
spelling, and Kusari. Set 4, the per-project CDN purge, was added
afterward and has not yet been pushed.

Brakeman matters most here. It gates `main`, runs only on GitHub, and
had never seen the parameterized `UPDATE` that set 1 introduces. It
raised no objection to the interpolated column names, so no
`config/brakeman.ignore` entry was needed and the rationale recorded in
[option 1D](#option-1d-a-parameterized-sql-statement-chosen) has not
had to be used.

The pull request is still marked draft.

### Production state right now

* Both notification caps are **zero**. That is the only thing preventing
  duplicate mail, nothing anywhere tracks that they are off, and the
  planned monitoring will not catch it (a cap of zero exits the loop
  legitimately). Restore them to 20 once all of set 3 is deployed; see
  [Deployment: everything lands together](#deployment-everything-lands-together).
* 8 badge-loss flags are pending, deliberately: 8887, 11675, 11718,
  11957, 11985, 11996, 12038, 12059. Each owner is owed exactly one
  email when the caps come back.
* All warning flags and the 5 older loss flags are cleared.
* The baseline recalculation has been run; badge data and the CDN are
  correct.

### What is done and what is next

Sets 1 to 4 are implemented. Sets 1 to 3 are green in CI; set 3 was
written as the seven steps under [The plan](#the-plan), each with its
own tests. Set 4 is local only so far. The remaining separable items
are not started.

What remains:

1. Push set 4, then take the pull request out of draft and get it
   reviewed. This is a
   large change to code that mails people, so a second pair of eyes is
   worth more here than usual.
2. Decide the separable items in or out. None of them block.
3. The operational sequence under [Operational](#operational): deploy,
   restore both caps to 20, then confirm on the following run that the
   8 pending loss emails went out exactly once each and their flags
   cleared.

Note for whoever runs the suite next: editing `config/locales/en.yml`
in step 3c makes the precompiled assets stale, so four tests in
`test/controllers/badge_static_controller_test.rb` fail with "Stale
precompiled assets detected" until `rake assets:precompile` is run.
`public/assets` is gitignored, so this is a local step, not a commit.

### Deployment: everything lands together

Decided 2026-08-03, revising the earlier intent to deploy set 1 on its
own and restore the caps at that point.

Nothing is merged or deployed until all of set 3 is complete. The caps
stay at zero until then, and are restored only after the whole pipeline
is in place.

The earlier plan had set 1 deploy alone, on the reasoning that set 1 is
what makes duplicates impossible and that leaving legitimate
notifications suppressed any longer than necessary is its own quiet
failure. That reasoning still holds as far as it goes, but three things
outweigh it:

* **We learn more by finishing.** Set 3 changes delivery semantics
  (`deliver_now`), what a set flag means (deferred rather than
  discarded), and adds retry state. Implementing all of it is likely to
  surface facts that would change how we would have wanted set 1 to
  behave in production. Mailing under one semantics and then changing
  the semantics underneath the same queue is avoidable work.
* **Waiting is strictly better for at least one owner.** Under set 1 and
  2 as they stand, an owner we cannot email has their flag cleared and
  their notification discarded. Project 12038 has no usable address and
  is in the pending set right now, so deploying before set 3 would throw
  its notification away permanently. Set 3's suppression rule defers
  instead, so waiting preserves it.
* **Little accumulates in the meantime.** The pending flags are raised
  only by `update_all_badge_percentages` and `save_warning_columns`,
  both reached only from operator-run rake tasks, never from an ordinary
  project edit. If we run no recalculation during this window, the
  pending set stays exactly as it is: 8 loss flags and no warnings.

The cost we are accepting is that those 8 owners wait longer for the one
email each is owed. That is bounded and known.

The residual risk is the one the first bullet under
[Production state right now](#production-state-right-now) names: the
caps are off, nothing tracks that, and the longer this work takes the
longer that stays true with no alarm. If set 3 stalls, restoring the
caps on top of sets 1 and 2 remains available as a fallback, at the cost
of project 12038's pending notification. Deciding to stop and ship is
better than drifting into a stop by inattention.

### Decisions already made

Do not relitigate these; the reasoning is in this document. Option 1D
(parameterized SQL, not the ORM), 3B and 3C for tests, concern 5 for the
counter, design 6B with bounded retries and attempt counters, suppression
defers rather than discards, relevance guards, concern 7's unification,
and deploying everything together rather than set 1 first.

Two open nits, both deliberate and neither urgent: `NOTIFICATION_SERIES`
is shallow-frozen, and `send_notifications` sits in the file's loss
region while serving both series.

### To re-establish the picture

```bash
heroku config --app production-bestpractices | grep BADGEAPP_MAX
```

```bash
heroku pg:psql --app production-bestpractices -c "SELECT count(*) FILTER (WHERE unreported_baseline_badge_warning > 0) AS warn, count(*) FILTER (WHERE unreported_baseline_badge_loss > 0) AS loss, count(*) FILTER (WHERE last_warning_sent_at IS NOT NULL) AS warned FROM projects;"
```

Expect caps of 0, and `warn 0, loss 8, warned 11`.

### Things that cost time this session

* `heroku logs` retains roughly **four minutes** on this app. Anything
  older must come from Papertrail. An empty `heroku logs | grep` proves
  nothing.
* `heroku run` passes its command through a shell on the dyno, so `$stdout`
  and friends are expanded before Ruby sees them. Feed scripts to
  `rails runner -` over a quoted heredoc instead.
* Multi-line pastes get mangled in this terminal. Put SQL in a file, or
  use `heroku pg:psql -c "..."` on one line.
* Implicit ActiveRecord behavior has bitten this code three times:
  `update_columns` adds the locking column to `WHERE`, `update_all` adds
  an increment to `SET`, and `order` **appends** to a `default_scope`
  order rather than replacing it (`reorder` replaces). Read the generated
  SQL before believing any of it.
* `FastlyRails.purge_all` logs nothing on success and swallows every
  failure, so it cannot be confirmed from logs. Fetch a badge body
  instead. `curl -I` on a badge URL returns `no-store`, which means the
  request never reached the badge action.

## Summary

`Project.send_loss_notifications` and `Project.send_warning_notifications`
load each project with a tight `SELECT` that omits `lock_version`, then
call `update_columns` to clear the pending-notification flag. Because
`update_columns` adds the optimistic-locking column to its `WHERE`
clause, and the omitted column defaults to `0`, the `UPDATE` matches
**zero rows** for every project that has ever been edited.
`update_columns` returns `false` rather than raising, both call sites
discard that return value, and the flag survives. The next night the same
project is selected again and the same email is sent again.

The emails were delivered successfully every time. Nothing was ever
recorded as sent.

## Symptom

As of 2026-07-31, on the production site:

* 11 projects had `unreported_baseline_badge_warning > 0` with
  `badge_warning_effective_date = 2026-07-31`, set on 2026-07-18.
* 5 projects had `unreported_baseline_badge_loss > 0`, set on or about
  2026-06-26.
* `last_warning_sent_at` and `last_loss_sent_at` were `NULL` on every row
  in the table. Neither column had ever been written.

Meanwhile the nightly `rake reminders` task reported success. From
Papertrail, the run of 2026-07-22:

```text
Sending inactive project reminders. List of reminded project ids:
[5098, 1886, ... 2957]
Sending badge-loss notifications. Emails sent:
5
Sending badge-warning notifications. Emails sent:
11
```

The run of 2026-07-30 was identical except that the warning count was 10.
The task completed normally; there was no exception and no crash. The
production caps at the time were
`BADGEAPP_MAX_BADGE_LOSS_NOTIFICATIONS=20` and
`BADGEAPP_MAX_BADGE_WARNING_NOTIFICATIONS=20`, so the loops were not
stopping early on the rate limit.

## Root cause

`update_columns` honors optimistic locking. In
`activerecord-8.1.3.1/lib/active_record/locking/optimistic.rb`:

```ruby
def _query_constraints_hash
  return super unless locking_enabled?

  locking_column = self.class.locking_column
  super.merge(locking_column => _lock_value_for_database(locking_column))
end
```

The `projects` table has a `lock_version` column (`db/schema.rb`), so
locking is enabled for `Project`. Neither `LOSS_NOTIFY_PROJECT_FIELDS`
nor `WARN_NOTIFY_PROJECT_FIELDS` in `app/models/project.rb` includes it,
so a record loaded through either list has no value for `lock_version`
and falls back to the column default of `0`. Rails then emits:

```sql
UPDATE "projects" SET "unreported_baseline_badge_warning" = 0,
       "last_warning_sent_at" = '...'
WHERE "projects"."id" = 9101 AND "projects"."lock_version" = 0
```

Any project that has been edited at least once has a non-zero
`lock_version`, so the statement affects no rows. `update_columns`
returns `false`; it does not raise. Both call sites ignore the return
value, so the loop proceeds to the next project as though the flag had
been cleared.

`Project.update_all_badge_warnings` is *not* affected, because
`save_warning_columns` receives fully loaded records from `find_each`,
which carry the real `lock_version`. That is why setting the flags on
2026-07-18 worked while clearing them never did. It also means projects
that have never been edited since creation, whose `lock_version` really
is `0`, would have been cleared correctly. The defect only bites records
that have been saved at least once.

## Evidence

### The instrumented run

Run against production on 2026-07-31, inside a transaction that was
rolled back, exercising both load patterns in the same process and on the
same connection. Project 9101 was loaded with the tight `SELECT` used by
the notification loop; project 12049 was loaded in full with `find`:

```text
PARTIAL id=9101 id_in_database=9101 readonly=false loaded_attrs=10
PARTIAL constraints={"id" => 9101, "lock_version" => 0}
  Project Update  UPDATE "projects" SET "unreported_baseline_badge_warning" = $1,
  "last_warning_sent_at" = $2 WHERE "projects"."id" = $3
  AND "projects"."lock_version" = $4
  [["unreported_baseline_badge_warning", 0], ["last_warning_sent_at", ...],
   ["id", 9101], ["lock_version", 0]]
PARTIAL update_columns => false
PARTIAL readback=1

FULL id=12049 loaded_attrs=448
  Project Update  UPDATE "projects" SET ... WHERE "projects"."id" = $3
  AND "projects"."lock_version" = $4
  [..., ["id", 12049], ["lock_version", 19]]
FULL update_columns => true
FULL readback=0
```

The contrast is exact. The partially loaded record guessed
`lock_version = 0` and matched nothing. The fully loaded record carried
the true value of 19 and succeeded. Same process, same connection, same
method, two different projects so that neither result could mask the
other.

To reproduce: run `rails runner -` on a one-off dyno with the script fed
over a quoted heredoc, so that no shell expands it. Set
`ActiveRecord::Base.logger` to `STDOUT` at `DEBUG`, load one project
through `Project::WARN_NOTIFY_PROJECT_FIELDS` and another through
`Project.find`, call `update_columns` on each inside
`ActiveRecord::Base.transaction`, print each return value and
`_query_constraints_hash`, and end with `raise ActiveRecord::Rollback`
so nothing is written.

### Why our tests did not catch this

`test/fixtures/projects.yml` defines seven projects (`one`, `two`,
`no_repo`, `perfect_unjustified`, `perfect_passing`, `perfect_silver`,
`perfect`) and sets `lock_version` on none of them, so every fixture
project sits at the column default of `0`. That is precisely the value
the defective `WHERE` clause guesses, so the `UPDATE` matches in the test
environment and the assertions pass.

Nine tests in `test/integration/recalc_test.rb` exercise this code, five
for the loss path and four for the warning path, including
`send_loss_notifications enqueues email and clears column` and
`send_warning_notifications sets last_warning_sent_at`. All nine assert
the outcome with a fresh `Project.find`, and all nine pass, locally and
in CI.

This is worth dwelling on. We had direct, specific test coverage of the
exact behavior that was broken in production, written by someone who
correctly identified what needed asserting, and it was green the entire
time. The fixtures made the broken query accidentally correct.

### The same trap was already known

A survey of every other site that writes without validations found no
second instance, but it did find this, at
`app/controllers/projects_controller.rb:220`:

```ruby
# lock_version isn't needed for mere viewing, but it's a *big* problem
# if we forget to include it where needed, so let's include it.
PROJECT_BASE_FIELDS = (
  %i[
    ...
    lock_version disabled_reminders last_reminder_at
  ] + Sections::LEVEL_SAVED_FLAGS.values
).freeze
```

Someone had already met this trap, understood it exactly, and guarded
the controller's field lists against it. `set_level_saved_flag` writes
with `update_column` through a record loaded by `set_project_for_section`,
which is a partial `SELECT`, and it works only because of that comment
and the line it protects.

The knowledge existed in the codebase, one file away from the defect,
and did not reach `LOSS_NOTIFY_PROJECT_FIELDS` or
`WARN_NOTIFY_PROJECT_FIELDS`. This is the strongest argument for option
3B: a comment asking humans to remember was written, was correct, was
followed in one place, and still did not propagate. Non-zero
`lock_version` values in the fixtures make the requirement mechanical
instead of documentary.

The remaining write sites are safe for other reasons.
`app/controllers/sessions_controller.rb:131` writes to `users`, which
has no `lock_version` column, and
`app/controllers/unsubscribe_controller.rb:56` uses relation-level
`update_all`, which never consults loaded attributes.

### Delivery records

Every notification was delivered. Solid Queue keeps finished jobs
(nothing prunes them; `PurgeCdnProjectJob` rows go back to 2025-02-23),
so the full history is available:

```sql
SELECT date_trunc('day', created_at)::date AS day,
       count(*) AS jobs,
       count(*) FILTER (WHERE finished_at IS NOT NULL) AS finished
FROM solid_queue_jobs
WHERE class_name = 'ActionMailer::MailDeliveryJob'
GROUP BY 1 ORDER BY 1;
```

221 jobs, every one finished. No unfinished jobs, and the only three
rows in `solid_queue_failed_executions` are `PurgeCdnProjectJob`
instances orphaned by dyno restarts in March, May, and July. The daily
pattern:

| Period | Jobs per night |
| ------ | -------------- |
| 2026-06-26 | 5 |
| 2026-06-27 to 2026-07-04 | 3 |
| 2026-07-05 to 2026-07-17 | 2 |
| 2026-07-18 to 2026-07-27 | 13 |
| 2026-07-28 to 2026-07-30 | 12 |

These sum to exactly 221. The step on 2026-07-18 is the day the 11
baseline warning flags were set. Reminder emails do not appear here
because `ProjectsController.send_reminders` uses `deliver_now`, so
essentially every row in this table is one of these repeated
notifications.

Note the general lesson for answering "was this user emailed?": the
`unreported_*` and `last_*_sent_at` columns are **not** a record of
delivery. `solid_queue_jobs` is, and it was the only source that could
settle the question.

**That is reversed by step 3b**, which switched these two loops to
`deliver_now`. From that point they enqueue no job at all, so
notification mail leaves no trace in `solid_queue_jobs`, and
`last_loss_sent_at` and `last_warning_sent_at` become the record of
delivery, which is the entire point of design 6B. A future investigation
that reaches for `solid_queue_jobs` first, as this one did, will find
nothing and must not read that as nothing having been sent.

### A discrepancy worth noting

The task reported 16 emails on 2026-07-22 (5 loss plus 11 warning) but
only 13 jobs were enqueued. The gap is a second, independent defect:
`send_loss_email` returns early when the badge has since been regained,
before calling `deliver_later`, but the caller increments `emails_sent`
regardless. The counter therefore reports mail that was never created,
which is part of why the nightly log looked healthy.

### What was ruled out

Each of these was checked and eliminated before the cause was found.
They are recorded so that nobody re-treads them.

* **An enclosing transaction that rolled back.** There is no
  `transaction` block anywhere in this path. More conclusively, Solid
  Queue writes to the same database on the same connection
  (`config.solid_queue.connects_to` is commented out), and
  `enqueue_after_transaction_commit` defaults to `false` in
  activejob 8.1, so a rollback would have destroyed the mail job rows as
  well. Those rows exist and are finished.
* **Database triggers or rules on `projects`.** None exist
  (`pg_trigger`, `pg_rules`).
* **Row-level security.** Not enabled on `projects`.
* **A second writer restoring the flags.** The `versions` table shows
  only ordinary daytime edits by real user accounts, nothing near the
  23:01 UTC run.
* **A read replica or a second database.** One database,
  `pg_is_in_recovery()` is false, and `DATABASE_URL` matches the add-on
  that `heroku pg:psql` connects to.
* **Stale deployed code.** `app/models/project.rb` is unchanged between
  the deployed commit and the reviewed source. This became moot anyway:
  the instrumented run reproduces the defect in production itself.
* **An ActiveRecord monkeypatch.** None in `config/initializers/` or
  `app/lib/`.
* **The scheduler not running the task.** Papertrail shows the
  `rake reminders` banner every night from 2026-07-17 through
  2026-07-30, the range checked, with no gaps. That task is the only
  caller of `send_reminders`.
* **A crashed worker dyno.** The `worker` dyno is a do-nothing stub; see
  [Unrelated problems](#unrelated-problems-found-during-this-investigation).

## Current state of the data

At the time of writing, before any recalculation, the projects with
`unreported_baseline_badge_warning > 0` are:

```text
9101, 12049, 11987, 12059, 11957, 11718, 8887, 12038, 11996, 11675, 11985
```

A dry run of `rake badge_warning_report` on 2026-07-31 shows that only
**8** of these would now lose a baseline level: 8887, 11675, 11718,
11957, 11985, 11996, 12038, and 12059. The other three appear to have
corrected their entries in the intervening two weeks, which is the
warning emails working as designed, however many of them arrived. No
metal-level losses are pending.

The badge recalculation itself has not yet been run.

## Effect on users

All of these messages were delivered:

* About 140 duplicate "your badge may lose baseline status" emails to
  11 project owners, roughly 13 each, between 2026-07-18 and 2026-07-30.
* About 81 badge-loss emails between 2026-06-26 and 2026-07-30, two to
  three per night. The per-night count fell from five to two as
  affected projects regained their badges and `send_loss_email` began
  returning early, so the owners still in that set received on the order
  of 35 copies each. Exactly who received how many can be confirmed
  from the serialized arguments in `solid_queue_jobs` if needed.

This is exactly the behavior that gets a sender classified as a spammer,
which is why the rate limits exist in the first place.

## Mitigation applied

On 2026-07-31, before any fix, both daily caps were set to zero so that
the loops exit before sending or writing anything:

```bash
heroku config:set BADGEAPP_MAX_BADGE_LOSS_NOTIFICATIONS=0 \
  BADGEAPP_MAX_BADGE_WARNING_NOTIFICATIONS=0 \
  --app production-bestpractices
```

This is temporary. It stops the repeated mail; it does not fix the
defect, and it also suppresses legitimate notifications. The caps must be
restored once the defect is fixed.

## Actions taken on 2026-07-31

1. Both notification caps set to zero on production, stopping the
   repeated mail.
2. Staging refreshed from a production backup (`rake
   production_to_staging`), its caps also set to zero so that the copied
   production email addresses could not be mailed from the staging tier,
   and the recalculation rehearsed there. The staging web dyno crashed
   at 22:07:06 UTC during the restore window, about 70 seconds before
   the recalculation began, so the two are unrelated; the evidence had
   scrolled out of Heroku's short log window before it could be
   examined. Staging web is a Basic dyno, production is Standard-2X, so
   staging is not a fair comparison for resource limits in any case.
3. `rake recalc_baseline_and_notify_losses` run on production
   (`run.6532`, 22:17:48 to 22:19:27 UTC, exit status 0, about 100
   seconds for the full table). The result matches the staging
   rehearsal exactly, project for project.
4. The stale flags cleared in SQL, per
   [Disposition of the pending flags](#disposition-of-the-pending-flags):
   the 11 baseline warning flags (`UPDATE 11`) and the 5 older loss
   flags (`UPDATE 2` and `UPDATE 3`). Verified afterward: no warnings
   pending, 8 losses pending, 11 projects recording a warning delivery,
   2 recording a loss delivery.

Eight projects lost a baseline level, as predicted by the dry run:

| Project | Level lost |
| ------- | ---------- |
| 8887 dnsplane | baseline-3 |
| 12038 SGO - Sistema de Gestao Operacional | baseline-3 |
| 11718 t3x-rte_ckeditor_image | baseline-2 |
| 11957 Zen-Ai-Pentest | baseline-2 |
| 11996 lemuria | baseline-2 |
| 11675 HamyarPaygahPy | baseline-1 |
| 11985 go-llm-lens | baseline-1 |
| 12059 Borgitory | baseline-1 |

All eight now sit at 96 percent toward baseline-1, which is expected:
the new criteria added the same requirements to every project. Three of
the original eleven kept their badges (9101, 11987, 12049), having
corrected their entries after being warned.

That cleanup incidentally supplied the last piece of confirmation the
diagnosis never explicitly collected. A plain SQL `UPDATE` against
exactly the rows the application could not write reported `UPDATE 11`
immediately. The database was never the problem; the fault lay entirely
in the `WHERE` clause Rails built from a partially loaded record.

State left behind, all of it intentional:

* 8 pending badge-loss flags, one per project that lost a level today.
  Each owner is owed a single notification once the code is fixed and
  the caps are restored. Nothing will be mailed while they are zero.
* No pending warning flags.
* Both caps still at zero.

The CDN purge at the end of `update_all_badge_percentages` did take
effect. It cannot be confirmed from the log, because `purge_all` logs
nothing on success and returns early and silently when Fastly
credentials are blank, so its absence from the log proves nothing either
way. It was confirmed instead by fetching a badge through the CDN:

```text
$ curl -sS https://www.bestpractices.dev/projects/8887/baseline
<svg ... aria-label="openssf baseline v2026.02.19: in progress 96%">
```

That matches the recalculated database value, so the stale
`baseline-3` image is no longer being served.

Note for future checks: `curl -I` on a badge URL returns
`cache-control: no-store`, which is *not* the badge action's response.
`projects_controller.rb:100-104` skips the default `no-store` only for
`badge`, `baseline_badge`, and `show_json`, so a `no-store` reply means
the request was redirected or rejected rather than served by the badge
action. Fetch the body instead; it is unambiguous.

## Disposition of the pending flags

Decided 2026-07-31. Nothing here can mail while the caps are zero; these
dispositions determine what happens when the caps are restored.

### The 11 baseline warning flags

All stale: for the 8 that lost a level the badge is now actually gone,
and for the other 3 there is nothing left to warn about. Their effective
date has passed, so the email would state a deadline in the past. Clear
them without sending, and record the last genuine delivery, because
these owners really were warned, roughly 13 times each:

```sql
UPDATE projects
SET unreported_baseline_badge_warning = 0,
    last_warning_sent_at = TIMESTAMP '2026-07-30 23:01:00'
WHERE unreported_baseline_badge_warning > 0
  AND badge_warning_effective_date = DATE '2026-07-31';
```

Leaving the timestamp null would leave the database asserting that these
owners were never warned, which is precisely the misleading state that
made this investigation difficult.

### The 8 new loss flags

Set by the recalculation on 2026-07-31. **Each owner should receive one
badge-loss email**, once the code fix is deployed and the caps are
restored. They were warned repeatedly and their badge really is gone,
so a single accurate notification is owed to them. Leave these flags
set.

### The 5 older loss flags

Set on or about 2026-06-26. Reading `baseline_tiered_percentage` against
the encoding documented in `db/schema.rb`:

| Project | Level lost | Now | Status |
| ------- | ---------- | --- | ------ |
| 34 Linux Kernel | baseline-2 | 300, baseline-3 | regained |
| 552 Weblate | baseline-1 | 168, baseline-1 | regained |
| 4368 Warnings plugin | baseline-1 | 174, baseline-1 | regained |
| 3564 Meshery | baseline-1 | 96, in progress | still lost |
| 7176 fabric-token-sdk | baseline-1 | 96, in progress | still lost |

Only two of the five ever produced mail, because `send_loss_email`
returns before `deliver_later` when the badge has been regained. That
independently confirms the delivery record above: two jobs per night
from 2026-07-05 onward are exactly these two projects, and the step down
from three on that date matches project 4368 being updated at
2026-07-04 23:20, shortly before that night's run.

Clear all five without sending. Meshery and fabric-token-sdk have
already received roughly 35 copies each; a thirty-sixth serves nobody.
The two groups differ in what is true about them, so they are recorded
differently:

```sql
-- Delivered many times over; record the last genuine delivery.
UPDATE projects
SET unreported_baseline_badge_loss = 0,
    last_loss_sent_at = TIMESTAMP '2026-07-30 23:01:00'
WHERE id IN (3564, 7176);

-- Never emailed about this loss, and since regained. No delivery to record.
UPDATE projects
SET unreported_baseline_badge_loss = 0
WHERE id IN (34, 552, 4368);
```

Three of these five flags were pure noise: projects that had fixed their
entries and would never have been emailed, whose flags nonetheless sat
pending for five weeks because the clear never worked. Under the fixed
code they would have been cleared on the first night, silently and
correctly.

## Affected code

All in `app/models/project.rb`:

* `LOSS_NOTIFY_PROJECT_FIELDS` and `WARN_NOTIFY_PROJECT_FIELDS`, the two
  column lists that omit `lock_version`.
* `send_loss_notifications` and `send_warning_notifications`, which
  discard the `update_columns` return value.
* `send_loss_email`, whose early return is not reflected in the
  `emails_sent` counter.

Not affected: `update_all_badge_warnings` and
`update_all_badge_percentages`, which write through fully loaded records.

## Options for the fix

Five separate concerns. Each is listed with its alternatives, then a
recommendation follows in [The plan](#the-plan).

### 1. Making the write succeed

#### Option 1A: add `lock_version` to both column lists

```ruby
WARN_NOTIFY_PROJECT_FIELDS =
  'id, user_id, updated_at, unreported_badge_warning, ' \
  'unreported_baseline_badge_warning, badge_warning_effective_date, ' \
  'tiered_percentage, badge_percentage_baseline_1, ' \
  'badge_percentage_baseline_2, badge_percentage_baseline_3, lock_version'
```

* **Pro.** Smallest possible change, two lines. Preserves optimistic
  locking, so a concurrent user edit correctly prevents a stale write.
* **Pro.** Keeps `update_columns`, which the surrounding code and its
  comments already assume.
* **Con.** The trap remains armed. Anyone who later trims these lists
  for memory reasons, which is exactly the stated purpose of these
  constants, silently reintroduces the defect.
* **Con.** A concurrent edit between the `SELECT` and the `UPDATE` still
  produces a silent `false`, so option 2 is required regardless.

#### Option 1B: load full records instead of a tight `SELECT`

* **Pro.** Cannot go wrong; matches the pattern that works elsewhere.
* **Con.** Directly contradicts a deliberate design decision. A
  `projects` row is over 400 columns wide, about half of them text, and
  these constants exist specifically to keep the notification loops off
  the heap. This project has already been bitten by memory exhaustion in
  bulk loops (see `BULK_RECALC_BATCH_SIZE`). Rejected.

#### Option 1C: write with `update_all` scoped by id (superseded)

```ruby
updated = Project.where(id: project.id).update_all(
  unreported_baseline_badge_warning: 0, last_warning_sent_at: now
)
```

This was chosen first, then abandoned during review of the
implementation. `update_all` carries hidden behavior of its own: when the
model has a locking column and the updates hash does not mention it,
Rails appends `lock_version = lock_version + 1` to the `SET` clause
(`activerecord/lib/active_record/relation.rb`). The project edit form
submits `lock_version` as a hidden field and the controller rescues
`StaleObjectError` with "changed since you started editing"
(`projects_controller.rb`), so bumping it would make an owner's in-flight
edit fail because of our bookkeeping, telling them their work collided
when nothing of theirs had changed. The `default_scope` order also turned
a simple `WHERE id = ?` into a needless `IN (SELECT ... ORDER BY ...)`
subquery.

Both were fixable, with `unscoped` and by assigning the locking column to
itself, but that is compensating machinery: roughly twenty lines of
workaround and explanation for a two-column write. See option 1D.

* **Pro.** Immune to the original defect by construction. `update_all`
  builds its own `WHERE` from the relation and never consults the loaded
  attributes.
* **Pro.** Returns the number of affected rows, which makes the check in
  concern 2 natural rather than bolted on.
* **Con.** Silently bumps `lock_version`, with the user-visible
  consequence above. This is a second piece of hidden ORM behavior in the
  same few lines of code, after the one that caused the incident.
* **Con.** Needs `unscoped` to avoid a pointless subquery.
* **Con.** Does not refresh the in-memory object. Harmless in these two
  loops, which never re-read the cleared attribute, but worth noting.

#### Option 1D: a parameterized SQL statement (chosen)

```ruby
sql = sanitize_sql_array(
  [
    "UPDATE projects SET #{assignments} WHERE id = ?",
    *columns.values, id
  ]
)
with_connection { |conn| conn.update(sql) }
```

**Decision: this is the option to implement.** The deciding argument is
empirical. These same twenty lines have now been broken twice by implicit
ORM behavior, each time invisible in the Ruby and visible only in the
generated SQL: `update_columns` adding `lock_version` to the `WHERE`
clause, and `update_all` adding an increment to the `SET` clause. A
literal statement has no such surface.

* **Pro.** Says exactly what it does. It touches only the columns named,
  leaves `lock_version` alone by never mentioning it, ignores
  `default_scope`, and does not touch `updated_at`.
* **Pro.** Stable across ORM upgrades, which the two failures above show
  is not a theoretical concern here.
* **Pro.** Shorter overall: no `unscoped`, no self-assignment constant,
  and none of the commentary needed to explain either.
* **Pro.** `connection.update` returns the affected row count directly.
* **Con.** Departs from this codebase's stated preference for the
  ActiveRecord query interface, which `projects_to_remind` justifies on
  portability grounds. The force of that is low here: every environment
  in `config/database.yml` is PostgreSQL, and a single-table
  `UPDATE ... WHERE id = ?` is plain ANSI SQL that every engine supports.
* **Con.** Column names are interpolated rather than bound, so they are
  validated against `column_names` first. Values remain bound parameters.
  Static analysis may still object, in which case a
  `config/brakeman.ignore` entry with this rationale is appropriate: the
  statement is short enough to verify by inspection.

* **Pro.** Immune to the defect by construction. `update_all` builds its
  own `WHERE` from the relation and never consults the loaded
  attributes, so no future edit to the column lists can break it.
* **Pro.** Returns the number of affected rows, which makes the check in
  concern 2 natural rather than bolted on.
* **Pro.** Arguably the correct semantics. These are bookkeeping
  columns, not user-editable state. A user editing their entry at 23:01
  should not cause us to re-send a notification the following night.
* **Con.** Bypasses optimistic locking. That is the intent here, but it
  must be commented so it is not mistaken for an oversight.
* **Con.** Does not refresh the in-memory object. Harmless in these two
  loops, which never re-read the cleared attribute, but worth noting.

### 2. Making a failed write loud

#### Option 2A: check the return value and raise

* **Pro.** Fail-fast. A zero-row update aborts the task instead of
  quietly re-sending forever.
* **Con.** One bad row stops the whole queue, including the projects
  behind it. That is the failure mode that would have hidden this in a
  different way.

#### Option 2B: check, log to Sentry, skip, continue

* **Pro.** The queue keeps draining; the anomaly is still visible.
  Sentry is already configured (`config/initializers/sentry.rb`, active
  whenever `SENTRY_DSN` is set).
* **Con.** Requires someone to be watching Sentry.

#### Option 2C: clear the flag first, then send

```ruby
next unless clear_warning_flag(project, now)

send_warning_email(...) if can_email
```

* **Pro.** Makes a repeated send structurally impossible rather than
  conditionally unlikely. If the write fails, no mail goes out at all.
* **Pro.** Converts the worst case from "send the same email 35 times"
  to "fail to send one email", which is plainly the better failure for
  a badge notification.
* **Con.** A crash between the clear and the send loses that
  notification silently. `last_*_sent_at` still records the attempt, so
  it is auditable.
* **Con, and it is decisive.** Recording the attempt is exactly what we
  decided these timestamps must *not* do. See
  [concern 6](#6-recording-deliveries-and-retrying), which supersedes
  this option.

2B still applies for visibility. 2A and 2C are subsumed by concern 6.

### 3. Preventing recurrence through tests

These options interact with the choice of 1C, and the interaction is
easy to get backwards. Once the write uses `update_all`, `lock_version`
no longer appears in these statements at all, so a test written *about*
`lock_version` asserts a mechanism the fixed code does not use. Such a
test would be describing history, not protecting the future.

What still matters is whether the test data can *detect* a return to a
locking-sensitive write. With every fixture at `lock_version = 0`, a
reintroduced `update_columns` on a partially loaded record would succeed
in the test suite exactly as it did in production for five weeks. That
is the trap worth closing, and it is a property of the fixtures rather
than of any single test.

#### Option 3A: one targeted regression test (dropped)

A test that hand-sets `lock_version = 7` and asserts the flag clears.

* **Pro.** Fails against today's code, passes after the fix.
* **Con.** After 1C it asserts a mechanism the fixed code no longer
  relies on, so it documents the defect rather than guarding against
  it.
* **Con.** Its only durable value is as a tripwire for a reintroduced
  `update_columns`, and 3B provides that generally instead of for one
  hand-picked row.
* **Verdict.** Dropped. Subsumed by 3B plus 3C.

#### Option 3B: give the fixtures non-zero `lock_version` values (keep)

Worth restating what this is: not a test about locking, but the removal
of an unrealistic special case from the fixtures. A `lock_version` of
zero describes a project that has never been saved. Essentially every
real project we notify has been saved, often many times; project 12049
in production is at 19.

* **Pro.** Gives 3C its teeth. Without it, an idempotency test still
  passes when the code regresses to `update_columns`, because at
  `lock_version = 0` the broken query is accidentally correct. This is
  the whole reason the defect survived CI.
* **Pro.** Closes the class rather than the instance. Any future code
  path that writes through a partially loaded `Project` fails in CI
  immediately.
* **Con.** May surface other latent failures in the existing suite. That
  is a benefit disguised as a cost, but it does mean the change is not
  free to land.
* **Fallback.** If the full change proves disruptive, set a non-zero
  `lock_version` on the handful of fixtures these notification tests
  use. Narrower, but it preserves the property that matters.

#### Option 3C: an idempotency test (chosen)

Run `send_warning_notifications` twice and assert the second run enqueues
nothing; same for `send_loss_notifications`.

* **Pro.** Tests the property we actually care about, independent of
  mechanism. Would have caught this defect whatever its cause, and will
  catch the next one.
* **Con.** Depends on 3B for its detection power. On its own, against
  zeroed fixtures, it is satisfied by broken code.

### 4. Detecting a stuck queue

#### Option 4A: end-of-run invariant check

After each run, if notifications remain pending while the run stopped
short of its cap, something is wrong. Report it.

Note that the other decisions in this document weaken the invariant.
Once suppression defers rather than discards, and once transient
failures leave the flag set for a later retry, a healthy run can
legitimately end with work still pending. The check must therefore
exclude projects that are suppressed or mid-retry, or it will cry wolf
every night and be ignored, which is the habit that let this defect run
for five weeks.

* **Pro.** Catches any future cause of a stuck queue, not just this one.
* **Pro.** No new schema of its own; suppression is derivable by joining
  `users`, and the retry state is the attempt counter added for
  concern 6.
* **Con.** The invariant is no longer exact, so the exclusions have to
  be kept in step with any future reason for deferring a notification.
  A reason to defer that the check does not know about becomes a
  nightly false alarm.
* **Con.** Silent if the cap is genuinely reached every night, though
  the drain would then be legitimately in progress.

#### Option 4B: age check in the daily task

Report `unreported_*` rows that have been pending for more than a few
days.

* **Pro.** Catches the slow case that 4A misses.
* **Con.** There is no "flag set at" timestamp for the loss columns, so
  age has to be inferred or a column added.

#### Option 4C: expose pending counts on an admin page

* **Pro.** Useful for other questions too.
* **Con.** Requires someone to look. Not a detector on its own.

### 5. Counter accuracy (chosen)

Increment `emails_sent` only when mail was actually enqueued, by having
`send_loss_email` and `send_warning_email` return a boolean.

* **Pro.** The nightly log becomes trustworthy. Its inaccuracy is part
  of why this ran for five weeks.
* **Con.** None. This is a straightforward correction.

### 6. Recording deliveries and retrying

Two decisions recorded elsewhere in this document contradict each other,
and the contradiction has to be settled before any code is written.

* Option 2C says to clear the pending flag *before* sending, so that a
  failed write can never cause a repeated send.
* The answer under [Open questions](#open-questions) says
  `last_warning_sent_at` and `last_loss_sent_at` should record
  **successful deliveries**, and that a transient failure should be
  retried later.

Clearing first records an attempt, not a delivery, and leaves nothing
behind to retry. Both cannot be true as written.

There is a further complication. With `deliver_later`, the notification
loop never learns whether delivery succeeded. It only learns that a job
was enqueued; the mail is rendered and delivered afterward, in the web
dyno, by Solid Queue. Under the current code the loop is structurally
incapable of recording a delivery.

#### Design 6A: enqueue, and have the job confirm

Keep `deliver_later`, clear the flag at enqueue time, and have a
dedicated job stamp `last_*_sent_at` after `deliver_now` succeeds inside
it. Retries become the job queue's responsibility via `retry_on`.

* **Pro.** No duplicate is possible; the flag is cleared exactly once,
  before any mail exists.
* **Pro.** Retries get proper exponential backoff from Solid Queue
  rather than a once-a-day cadence.
* **Pro.** The timestamp records a real delivery.
* **Con.** Requires a new job class, because
  `ActionMailer::MailDeliveryJob` is generic and cannot write back to
  the project row.
* **Con.** The flag and the timestamp become separated in time, so
  between them a project is in a state that means "queued but not yet
  delivered" with nothing recording it.

#### Design 6B: send synchronously and record the result (recommended)

Replace `deliver_later` with `deliver_now` in these two loops, exactly
as `ProjectsController.send_reminders` already does. On success, clear
the flag and stamp `last_*_sent_at` in a single `update_all`. On a
transient failure, leave the flag set, log, and let the next nightly run
retry.

* **Pro.** Satisfies both decisions directly. The loop knows the
  outcome, so the timestamp means delivery and the flag means "not yet
  delivered". Retry falls out of leaving the flag set.
* **Pro.** No new class, and it reuses a pattern already proven in this
  codebase at a larger volume: `send_reminders` delivers up to 40
  messages synchronously every night.
* **Pro.** Both columns are written in one statement, so they cannot
  disagree.
* **Con.** Reverses 2C's ordering, so a successful send followed by a
  failed write would duplicate. This is tonight's exact failure mode,
  which is why the `update_all` of concern 1C and the affected-row check
  of concern 2B are prerequisites rather than nice-to-haves. Keyed on
  the primary key alone, that write cannot silently match zero rows.
* **Con.** SMTP latency moves into the nightly task. Bounded by the cap
  of 20, against `send_reminders` already doing 40.

#### Required regardless: bound the retries

"Retry later" must not become "retry forever". A permanently rejected
address, say a 550 from the receiving server, would otherwise raise
every night and recreate this incident with a different cause. The fix
must distinguish the cases:

1. Suppressed, meaning we choose not to send: the owner has
   `important_notifications` false, or has no usable address. **Leave
   the flag set**, do not count it, and do not increment the attempt
   counter. See
   [Suppression must not discard the notification](#suppression-must-not-discard-the-notification).
2. No longer relevant. Clear the flag and send nothing. See
   [Relevance guards](#relevance-guards).
3. Transient failure (timeout, 4xx, connection refused). Leave the flag
   set and retry on a later run.
4. Permanent failure (5xx), or transient failures persisting beyond a
   bounded number of attempts. Clear the flag, log the abandonment, and
   report it to Sentry. Without a bound, category 3 silently becomes an
   unbounded send loop.

#### Classifying failures

Category 3 versus category 4 is the crux of the retry logic, so the
classification belongs in the code as an explicit list rather than in a
reviewer's head:

* **Transient:** `Net::SMTPServerBusy` (4xx), `Net::OpenTimeout`,
  `Net::ReadTimeout`, `Errno::ECONNRESET`, `Errno::ECONNREFUSED`,
  `IOError`.
* **Permanent:** `Net::SMTPFatalError` (5xx), `Net::SMTPSyntaxError`,
  `Net::SMTPAuthenticationError`.

**Anything unrecognized must default to transient.** The attempt bound
caps the cost of guessing wrong in that direction at
`BADGEAPP_MAX_NOTIFICATION_ATTEMPTS` retries, and the abandonment is
then reported. Defaulting to permanent drops notifications silently,
with no bound and no signal, which is the failure mode this whole
document exists to prevent.

#### Suppression must not discard the notification

The current code clears the flag whether or not it could send, because
`update_columns` sits outside the `if can_email` block. An owner with
`important_notifications` false therefore loses the pending
notification permanently: re-enabling notifications a week later
delivers nothing, because the flag is already gone and no new one is
raised unless the badge changes level again.

That is the wrong behavior. Suppression should defer, not discard, so
that an owner who opts back in still receives anything they are eligible
for. Leave the flag set and skip the project.

Left alone, that would accumulate pending rows forever for permanently
opted-out owners, which is why the relevance guards below are a
requirement rather than a refinement, and why concern 4A must exclude
suppressed projects from its alarm along with retrying ones.

#### Relevance guards

Before sending, each notification kind checks that it still means
something. If it does not, clear the flag and send nothing.

* **Loss:** skip if the badge has since been regained. This check
  already exists in `send_loss_email` and is why three of the five
  older loss flags never produced mail.
* **Warning:** skip if `badge_warning_effective_date` has passed. No
  such check exists today, which is why the 11 stale flags of
  2026-07-31 would have sent warnings announcing a deadline in the
  past, and why they had to be cleared by hand.

These guards bound the row accumulation that deferring on suppression
would otherwise cause: a suppressed warning clears itself once its date
passes, and a suppressed loss persists only while the badge really is
still lost, which is precisely when the owner would want it on opting
back in.

We already have a concrete example, from the 8 loss flags left pending
by tonight's recalculation. Project 12038 has no usable owner address;
the dry-run report rendered it as `Alesso <>`, and it is one of the
reasons the nightly warning count fell from 11 to 10 on 2026-07-28. Its
badge is genuinely lost, so the relevance guard will never clear it and
suppression will never send it. Under the new rules that flag stays
pending indefinitely, and the invariant check must not treat it as a
stuck queue. It is the first permanent resident of the pending set, and
a useful test case: whatever exclusion concern 4A uses has to keep quiet
about this project every night, forever, without also going quiet about
a genuinely stuck one.

#### The attempt counter

A count of attempts is the mechanism for the bound. The alternative,
treating `badge_warning_effective_date` as an age reference, only works
for warnings; the loss columns have no equivalent date, so it cannot
cover both queues. Two small integer columns are the simplest thing
that works:

```text
warning_send_attempts  integer NOT NULL DEFAULT 0
loss_send_attempts     integer NOT NULL DEFAULT 0
```

Two, not one, because the two queues are independent and a project can
be pending in both at once.

Two, not four, even though there are four notification kinds. Metal and
baseline already share a single sent-at column apiece
(`last_loss_sent_at`, `last_warning_sent_at`), and the two kinds within
a series are delivered to the same address in the same iteration, so a
transient SMTP failure affects both identically. The counters follow
the existing granularity. Record this as a deliberate choice: if the
series ever diverge, for instance by mailing different addresses, the
counters must split too.

Give both columns a `comment:` in the migration, as the other columns in
this table do; `db/schema.rb` carries those comments and they are how a
future reader learns what `unreported_baseline_badge_warning` means
without reading the model.

Details that have to be decided together, because getting any one of
them wrong reintroduces a version of this incident:

1. **Reset when the flag is set.** `update_all_badge_warnings` and
   `update_all_badge_percentages` must zero the matching counter when
   they raise a flag. Otherwise a project that exhausted its attempts
   in June is permanently unnotifiable, and the next legitimate warning
   is silently dropped. This is the most important of these rules and
   the easiest to overlook.
2. **Increment only on transient failure.** Not on success, and not on
   the undeliverable cases the mailer already returns early for.
3. **Give up on permanent failures immediately**, without waiting for
   the count to run out. A 5xx rejection will not improve tomorrow.
4. **Threshold.** Five attempts, at a nightly cadence, gives five days
   to ride out a transient outage. Make it a constant in the same style
   as the existing caps, for example
   `BADGEAPP_MAX_NOTIFICATION_ATTEMPTS`, so it can be changed without a
   deploy.
5. **On abandonment**, clear the flag, log to `Rails.logger.error`, and
   report to Sentry with the project id and the failure. The counter
   keeps its final value, which is the record of why the notification
   stopped.
6. **Adding the columns is cheap.** PostgreSQL 11 and later add a
   `NOT NULL DEFAULT` column without rewriting the table, which matters
   on a `projects` table this wide and this busy.

#### Interaction with the invariant check

Concern 4A reports pending notifications that survive a run which did
not reach its cap. A project legitimately waiting for tomorrow's retry
would trip that check every night and train us to ignore it, which is
precisely the habit that let this defect run for five weeks. The
invariant must therefore exclude, or count separately, projects whose
attempt counter is above zero. A project stuck at attempts of one for
weeks is a different signal from one that was never tried at all, and
they should not share an alarm.

#### Residual risk, accepted

If the receiving server accepts a message and the connection then drops,
`deliver_now` raises after the mail was in fact delivered, and the retry
sends a duplicate. The bound caps that at the threshold: five copies in
the worst case rather than thirty-five. That is an acceptable trade for
not silently dropping notifications, but it should be a conscious
choice, which is why it is recorded here.

**Decision: 6B, with the bounded retry and the attempt counters above.**
6A is the better design in the abstract, but it separates the flag from
the timestamp and adds a class, and its main advantage, queue-managed
backoff, matters little for a notification that is at worst a day late.

### 7. One notification pipeline, not two (chosen)

`send_loss_notifications` and `send_warning_notifications` are already
near-identical, about forty lines each, differing only in which columns
they touch, which mailer they call, and whether they re-check for a
regained badge. Everything this document proposes adding, the attempt
counter, the failure classification, the relevance guard, the write
result check and the invariant check, would otherwise be written twice.
That is roughly sixty lines of new logic duplicated, in a codebase whose
guidance states that if the same method is written more than once, it is
wrong.

Unify them into a single routine driven by a per-kind descriptor, so
that adding a third notification kind later is a data change rather than
another copy of the loop. A descriptor names everything that varies:

As implemented in set 2, the descriptor groups the four kinds under
their two series, because the cap, the pending query, and the sent-at
column belong to the series rather than to the individual kind:

```ruby
NOTIFICATION_SERIES = {
  loss: {
    sent_at: :last_loss_sent_at,
    kinds: [
      { flag: :unreported_badge_loss,
        levels: BADGE_LEVELS, suffix: 'badge' },
      { flag: :unreported_baseline_badge_loss,
        levels: BASELINE_BADGE_LEVELS, suffix: 'baseline' }
    ]
  },
  warning: { ... }
}.freeze
```

The pending relation, the cap, and the delivery method are passed by the
two thin entry points, which keeps lambdas and `send` out of the
constant. Set 3 adds the attempts column, the relevance guard, and the
failure classification to these same entries.

The generic routine then does the work once: select pending projects,
respect the cap, skip suppressed owners without clearing, apply the
relevance guard, send, classify any failure, update the columns in one
statement, verify the affected row count, and check the end-of-run
invariant.

* **Pro.** Every mechanism in this plan is implemented once. A future
  notification kind inherits the retry bound, the guards, and the
  monitoring for free.
* **Pro.** The four kinds currently differ in ways nobody intended.
  Only the loss path re-checks relevance; only the loss path has the
  regained-badge subtlety that made its counter overcount. Unifying
  forces those differences to be deliberate.
* **Pro.** One set of tests covers all kinds, which matters given the
  branch count the retry logic adds.
* **Con.** A larger diff than patching both loops, touching code that is
  currently working for the metal series. Mitigated by the fact that we
  are already modifying every line of both.
* **Con.** Descriptors with lambdas are less obvious to read than
  straight-line code. Keep the descriptor small and the generic routine
  short, and name the lambdas clearly.

#### A note on test coverage

The project requires 100 percent statement coverage outside rake tasks,
and this code is in a model, so the new branches all need tests:
suppressed, not relevant, transient failure, permanent failure,
attempts exhausted, and write-affected-no-rows. None require a real SMTP
server; stubbing the mailer to raise the relevant exception class covers
the classification paths, and stubbing the write to report zero rows
covers the invariant. Unification means writing this suite once rather
than twice.

## Unrelated problems found during this investigation

We were not looking for these, but both should be fixed.

### The Fastly credential check has never run

`config/initializers/fastly.rb` verifies `FASTLY_API_KEY` and
`FASTLY_SERVICE_ID` against the Fastly API at boot, specifically so that
a misconfiguration is caught at deploy time rather than silently
corrupting CDN state. It fails on every boot:

```text
FASTLY WARNING: Cannot reach Fastly API at startup
(NameError: uninitialized constant FastlyRails).
```

`NameError` is a `StandardError`, so the initializer's own
`rescue StandardError` swallows it and reports a transient network
problem, which is misleading. The check has therefore never validated
anything.

The cause is initializer ordering. Zeitwerk's main autoloader is set up
in Rails' Finisher, which runs *after* `config/initializers/`, so
autoloaded constants under `app/` are not resolvable there. The comment
at `config/initializers/fastly.rb:64-66` asserts the opposite and is
wrong. `FastlyRails` resolves correctly at runtime, which is why CDN
purging works.

**Fix.** Move the verification block into
`Rails.application.config.after_initialize`. This repo already
establishes that pattern, with a good explanatory comment, in
`config/initializers/zzz_eager_load_helpers.rb`. Correct the misleading
comment at the same time, and consider narrowing the `rescue` so a
`NameError` is not reported as a network problem.

**Done 2026-08-03**, on branch `fix_fastly_check_and_worker`, all three
parts. The diagnosis was confirmed rather than assumed: a probe
initializer showed `FastlyRails` raising `NameError` in the initializer
body and resolving in `after_initialize`. The `rescue` now lists the
network exception classes, and anything else is reported as a bug in the
check rather than as a Fastly outage. Both remain non-fatal; failing to
verify the CDN is no reason to refuse to start.

### The `worker` dyno runs a stub and crash-loops

`heroku ps` shows a `worker` dyno of size Standard-2X running
`bundle exec rake jobs:work`, which is a deliberate do-nothing stub
(`lib/tasks/default.rake`, "Stub do-nothing jobs:work task to eliminate
Heroku log complaints"). It exits immediately, so Heroku reports the
dyno as crashed and restarts it with backoff. Jobs are actually worked
inside Puma via `SOLID_QUEUE_IN_PUMA=true`.

**Fix.** Scale the `worker` process type to zero, or remove it from the
Procfile, whichever matches how the formation is managed. Then decide
whether the stub task is still needed at all. This is costing a
Standard-2X dyno to do nothing and producing a permanently red process
in `heroku ps`, which trains us to ignore that display. That habit is
part of why this investigation started later than it should have.

**Done 2026-08-03**, on branch `fix_fastly_check_and_worker`. Both tiers
were running it, production at Standard-2X and staging at Basic, and
both were confirmed to have `SOLID_QUEUE_IN_PUMA=true`, so nothing was
relying on the worker. Scaling it to zero could not affect job
processing: the task it ran has an empty body, so it never worked a job
in the first place.

The stub task is gone, and the Procfile now explains why there is no
`worker` line, since the trap is that Heroku's Ruby buildpack supplies
`bundle exec rake jobs:work` as its default for a `worker` process type
we never declared. Deleting the stub without saying that would invite
someone to add it back the next time a stray worker filled the log with
"Don't know how to build task".

### The recalculation purges the whole CDN cache

`update_all_badge_percentages` ends with an unconditional
`FastlyRails.purge_all` (`app/models/project.rb`), justified by a comment
saying we "have no cheap way to know which ones changed". That is no
longer true, and the staging rehearsal of 2026-07-31 proves it: the loop
calls `project.save(validate: false, touch: false)`, Rails skips the
`UPDATE` when nothing changed, and thousands of projects logged only a
`SELECT ... FOR UPDATE` followed by `COMMIT`. So `project.changed?`,
checked immediately before the save, identifies exactly the affected
rows at no cost.

Everything needed to purge precisely already exists, and is better than
what the recalculation uses. `record_key` is `projects/<id>`; every
cached representation of a project carries it as a surrogate key
(`set_surrogate_key_header` on `badge`, `baseline_badge`, and
`show_json`), so one purge by that key clears all of them.
`PurgeCdnProjectJob` purges by key with polynomial backoff and five
retries, whereas `purge_all` is fire-and-forget and swallows every
error.

**Fix.** Collect the `record_key` of each project the recalculation
actually modified, and purge only those. **The per-project purge must
happen only after the updated data is stored**, or the CDN will re-cache
the old value from a request that arrives between the purge and the
commit, leaving stale badges behind with no further purge coming. The
controller already follows this ordering around saves.

This paragraph originally went on to recommend keeping `purge_all` as a
fallback when the changed set exceeds a threshold, on the grounds that
thousands of individual Fastly calls would hit rate limits. **That was
wrong, and the implementation does not do it.** Rate limiting arrives as
an unsuccessful HTTP response, so `purge_by_key` returns false,
`PurgeCdnProjectJob` raises, and Active Job retries with backoff. A
large recalculation therefore purges more slowly; it does not lose
purges. The threshold would have traded a mechanism that already
handles the problem for one that cold-starts the cache of a site that is
extremely busy and constantly under attack.

**Done 2026-08-03**, in this branch rather than separately; see
[Set 4](#set-4-purge-only-the-projects-that-changed).

The cost of the present behavior is not hypothetical. The production
recalculation on 2026-07-31 changed a small number of projects and cold
started the cache for an entire site that is, by its own description,
extremely busy and constantly under attack.

## How the work is split

The repair described above grew from "add `lock_version` to two
constants" into a unification, two new columns, failure classification,
guards, and monitoring. That is proportionate to a defect that delivered
roughly 220 duplicate emails undetected for five weeks, but it is far
too much to review as one change. It is therefore split into separate,
independently reviewable change sets.

Two principles apply throughout:

* **Keep each change set small.** A reviewer should be able to hold the
  whole diff in their head. If a set starts sprawling, split it again.
* **Reuse what already exists.** The mailers, the level-name constants,
  the `Sections` helpers, the `reminders` rake task, the existing rate
  caps, and Solid Queue all stay. Prefer extending current structures to
  introducing new ones. That preference is why design 6B was chosen over
  6A, which would have needed a new job class.

Splitting is safe right now because both caps are zero, so nothing mails
until we deliberately restore them. Intermediate states cannot reach a
user.

### Set 1: the defect itself

The write fix (1C), the affected-row check (2B), the counter correction
(5), and the tests that would have caught this (3B and 3C). Small,
targeted, and directly closes the incident.

The `update_all` call goes in one small private helper shared by both
existing loops. That is not the full unification of concern 7; it is the
minimum needed so the fix is not written twice.

This set was originally intended to deploy on its own, with the caps
restored as soon as it did. That is no longer the plan; see
[Deployment: everything lands together](#deployment-everything-lands-together).
It remains true that set 1 is what makes duplicates impossible, and so
what makes restoring the caps safe at all.

### Set 2: unification, with no behavior change

Concern 7 only: collapse the loops into one routine driven by
`NOTIFICATION_SERIES`. Nothing observable changes, which makes review a
question of equivalence alone, the easiest kind to do well. Landing it
on its own also means set 3 is written once rather than four times.

### Set 3: delivery semantics and resilience

Design 6B (`deliver_now`, so the timestamps record deliveries), the
guards from concern 6 (suppression defers, relevance clears), the
bounded retry with its two new columns and migration, and the invariant
check (4A). This set carries the schema change and the behavior changes,
so it deserves the most careful review; putting it last means it lands
on an already-unified, already-correct pipeline.

By the principle above, this set sprawls, so it is split again. See
[Set 3 in the plan](#set-3-delivery-semantics-and-resilience-1) for the
seven steps.

### Separable at any time

The two unrelated findings are independent of all of the above and of
each other: the Fastly initializer ordering, and retiring the stub
`worker` dyno. Each is a small change on its own.

## The plan

In execution order, grouped by change set; see
[How the work is split](#how-the-work-is-split).

### Set 1: the defect itself

1. **Fix the write with option 1D.** A parameterized `UPDATE` in one
   small private helper shared by both existing loops, with column names
   validated against the schema and values bound.
2. **Check the result (2B).** Report any write affecting other than one
   row to `Rails.logger.error` and Sentry. A silent `false` is what cost
   us five weeks.
3. **Fix the counter (concern 5).** Count mail actually enqueued, not
   calls attempted.
4. **Add the tests 3B and 3C.** Non-zero `lock_version` in the fixtures,
   and an idempotency test on each notification path: run it twice,
   assert the second run sends nothing. Expect 3B to require fixing
   whatever else it uncovers; that is the point.

Done, and green in CI. Not deployed on its own; everything lands
together once set 3 is complete.

### Set 2: unification, no behavior change

1. **Unify the loops (concern 7).** One routine driven by a
   `NOTIFICATION_SERIES` descriptor covering metal and baseline, loss and
   warning. Nothing observable changes, so review is a question of
   equivalence alone. Landing this before set 3 means set 3 is written
   once instead of four times.

### Set 3: delivery semantics and resilience

Subdivided 2026-08-03 into seven steps, in dependency order. Set 3 is
the largest and riskiest part of this repair, and the steps below exist
so that each piece can be reviewed and tested on its own rather than as
one diff carrying a schema change, a delivery-semantics change, and new
control flow all at once. Nothing merges until all seven are done; see
[Deployment: everything lands together](#deployment-everything-lands-together).

The keystone is step 3a. As set 2 left it, `send_notifications` receives
a **Boolean** from its yield block, and set 3 needs at least five
distinct outcomes: sent, not relevant, suppressed, transient failure,
and permanent failure. Widening that contract first, without changing
any behavior, gives every later step a seam to plug into.

Three of the seven change nothing observable (3a, 3e-1, 3f is purely
additive), which leaves only four steps that alter what an owner
receives.

1. **Step 3a: an outcome vocabulary. No behavior change. Done
   2026-08-03.**
   Replace the Boolean yield contract with a symbol from
   `NOTIFICATION_OUTCOMES`. Three cases are conflated today:
   `send_loss_email` returns `false` when the badge has been regained,
   and `send_notifications` treats "we cannot email this owner"
   identically, so the caller cannot tell a notification that is over
   from one that is merely undeliverable today. `:sent`,
   `:not_relevant`, and `:suppressed` name them apart while all three
   still behave exactly as they do now.

   As landed, an unknown outcome raises rather than being read as "no
   mail sent", so a block left on the old Boolean contract fails in CI
   instead of quietly undercounting. Review is a question of
   equivalence; the existing tests in `test/integration/recalc_test.rb`
   passed with one mechanical change, a block returning `true` that now
   returns `:sent`.
2. **Step 3b: `deliver_now` (design 6B). Done 2026-08-03.** One line in
   each of `send_loss_email` and `send_warning_email`, so
   `last_*_sent_at` records a delivery rather than an enqueue. This is
   safe to land before any failure handling exists, and the reason is
   worth stating: the flag is already cleared *after* the yield, so an
   SMTP exception aborts the run with the flag still set, and the next
   night retries. No duplicate is possible in that window. Tests move
   from `assert_enqueued_emails` to `assert_emails`.

   Two things this turned up. First, mail templates were checked before
   the change for anything the tight `SELECT` lists do not load;
   `lost_level.text.erb` and `warned_level.text.erb` use only
   precomputed instance variables, and `Project` does not override
   `to_param`, so rendering a partially loaded record is safe. Under
   `deliver_later` this would not have mattered, because Active Job
   serializes through a Global ID and the job reloads the record in
   full. Anything later added to those templates now has to be in
   `LOSS_NOTIFY_PROJECT_FIELDS` or `WARN_NOTIFY_PROJECT_FIELDS`.

   Second, these tests never rendered the mail at all before, since
   `deliver_later` only enqueued it; line coverage rose by 37 lines when
   they started delivering for real. The mailer and its templates had
   been exercised only by the mailer tests.
3. **Step 3c: relevance guards. Done 2026-08-03.** For warnings, return
   `:not_relevant` when `badge_warning_effective_date` has passed;
   `WARN_NOTIFY_PROJECT_FIELDS` already selects that column. For
   losses, the regained-badge check already exists inside
   `send_loss_email`; express it through 3a's vocabulary so both series
   use one mechanism rather than two.

   The loss half needed no work: step 3a had already converted that
   check to `:not_relevant`, so this step was the warning guard alone.
   Each guard lives in its own mailer helper, parallel to the other,
   rather than in `send_notifications`. The two tests have nothing in
   common beyond their answer, and putting them in the descriptor would
   have meant the lambdas that concern 7 deliberately keeps out of it.

   **A warning with no recorded date is sent, not skipped**, and says
   nothing about when. This is a decision, not an oversight, and it is
   the reason the guard tests the date rather than trusting it: we
   cannot show a deadline has passed when we do not know what it was.
   Skipping would discard the notification for good and say nothing,
   which is the exact failure this document exists to prevent, and a
   fault in our own bookkeeping is a poor reason to leave an owner
   unwarned about their badge. `save_warning_columns` always records a
   date, so a missing one is a fault on our side, not theirs. It also
   turns out that no fixture sets that column, so skipping would have
   quietly turned six existing tests into tests that pass for the wrong
   reason.

   The first cut sent the ordinary message with the date interpolated
   as blank, which reads as "may be lost on ." and then refers the
   owner to a date it never gave. That is a poor thing to send. So
   `warned_level.text.erb` now chooses between two messages, and
   `report_mailer.warned_level_message_no_date` warns without naming a
   day. The rendered output of both was checked by hand as well as by
   test, since an ERB conditional in a plain-text mail can easily leave
   stray blank lines. The new key exists only in `en.yml`; the other
   locales fall back to English until translation.io carries it, which
   is the normal path for a new string.

   The boundary is inclusive: a warning whose deadline is today is
   still sent, because that date is the last day the warning is true
   rather than the first day it is stale.
4. **Step 3d: suppression defers. Done 2026-08-03.** An owner we cannot
   email keeps their pending flag instead of losing it. It is separated
   from 3c because it is the step that creates permanently pending
   rows, which is the fact step 3f has to be built around.

   Larger than the "two lines" this step was first scoped at, because
   of something noticed while doing 3b: `send_notifications` and the
   mailers disagreed about what "can email" means. The loop checked
   `important_notifications?` and `encrypted_email.present?`, while
   `email_owner_with_user` and `warn_owner_with_user` *also* returned
   early when the address would not decrypt, when `email?` was false,
   or when the address had no `@`. An owner failing only the mailer's
   checks was counted as `:sent` and had their flag cleared, though no
   mail existed. That is a second source of the overcount this document
   attributes to `send_loss_email` alone, and it applied to warnings
   too. Confirmed directly rather than by reading: for a user whose
   address lacks an `@`, the old check answers true and the new one
   false.

   The repair is `User#deliverable_email?`, the single place that
   question is now answered. Both the loop and both mailers call it, so
   a caller deciding whether to send cannot disagree with the mailer
   that does the sending. Putting it on `User` rather than in
   `Project` is what makes the agreement structural instead of a
   convention someone must remember.

   **A correction to the note this step was written from.** That note
   guessed project 12038 fails a mailer-side check rather than having a
   blank `encrypted_email`. The evidence does not support the guess:
   the report renders it as `Alesso <>`, which is what an empty or
   absent address produces, so the old check very likely caught it
   already. Both cases are handled now and both defer, so nothing in
   the code turns on this. Confirming 12038 against production is still
   worth doing before the caps are restored, but as a check on what the
   pending set contains rather than as a load-bearing assumption.
5. **Step 3e-1: the attempt columns and their reset. No behavior
   change. Done 2026-08-03.** The migration adding
   `warning_send_attempts` and `loss_send_attempts`, each with a
   `comment:`, **and** the reset wherever a flag is raised:
   `update_all_badge_percentages` for the loss columns and
   `save_warning_columns` for the warning columns. Nothing reads the
   new columns yet.

   This is the most valuable split in the set. The reset rule is the
   one this document calls the easiest to overlook, and the one whose
   omission makes a project permanently unnotifiable. Landing it while
   it is the only thing in the diff makes it impossible to overlook.

   The loss half moved into a new `record_pending_losses`, which also
   shortens `update_all_badge_percentages`; the reset is the reason
   that logic is worth naming. The warning half resets unconditionally,
   because `update_all_badge_warnings` reaches `save_warning_columns`
   only when a level is at risk. Three tests assert the reset happens
   on a loss, on a baseline loss, and on a warning, and a fourth
   asserts a recalculation that loses nothing leaves the count alone:
   the count belongs to the notification still pending, not to the run.
   The migration was rolled back and re-applied to confirm it reverses.

   **These two columns were briefly published in the project JSON API,
   and are not any more.** `_project.json.jbuilder` emitted every
   attribute with no exclusion list, so they appeared in
   `/projects/:id.json` beside `unreported_badge_loss`,
   `last_loss_sent_at`, and `lock_version`. That was resolved before
   this branch merged, in set 5, which is why the counters never became
   public API in a released version.
6. **Step 3e-2: classification and the bounded retry. Done
   2026-08-03.** The transient and permanent exception lists, with
   anything unrecognized treated as transient; a `rescue` in
   `attempt_notification` rather than in each mailer helper, so it is
   written once; increment on transient failure; clear, log, and report
   to Sentry on permanent failure or on exhausting
   `BADGEAPP_MAX_NOTIFICATION_ATTEMPTS`.

   The counters joined the tight `*_NOTIFY_PROJECT_FIELDS` lists, since
   incrementing means reading the current value. Editing those lists is
   precisely what caused the original defect, so they now carry a
   warning, and it is worth recording why the risk is smaller than it
   looks: an omitted column raises `ActiveModel::MissingAttributeError`
   rather than failing quietly. That was confirmed directly, not
   assumed. The trap was never that reading a missing column is silent;
   it was that `update_columns` *wrote* one silently.

   Two things came out differently from the sketch. `checked_outcome`
   is deliberately outside the `rescue`, so a block answering outside
   the vocabulary still fails loudly instead of being filed as a
   network problem. And an unrecognized exception is reported to Sentry
   at once, not five nights later when the attempts run out: we treat
   it as transient because that is the safe direction, but failing to
   classify it is a gap in those two lists and deserves a human sooner
   than that.

   `clear_notification_flag` was renamed, because it now counts
   attempts and stamps deliveries as well as clearing, and a method
   named for one of the three things it does invites the reader to
   assume the others do not happen. It is called
   `write_bookkeeping_columns` today; the reminder task and the
   recalculation write through it too, so it is no longer only about
   notifications.

   **Only `:sent` writes the sent-at column now.** Previously a
   no-longer-relevant notification stamped it too. Since step 3b those
   columns are the record of delivery, so stamping one when nothing was
   delivered would recreate the misleading state that made this
   incident hard to diagnose. This was not in the sketch for this step,
   but abandonment forced the same question, and the answer has to be
   the same in every case.

   **The cap counts mail sent, not attempts made.** Decided 2026-08-03,
   after the alternative was raised and rejected: what matters is
   whether a message got through, not how many times we tried. So a run
   continues through the whole pending set even when every delivery is
   failing. The consequence to know about is that during a sustained
   outage each pending notification burns one attempt per night on the
   same cause, and after `BADGEAPP_MAX_NOTIFICATION_ATTEMPTS` nights
   they are abandoned together: "our mail was down for five days, so
   every pending notification was dropped at once". That is the bound
   working as designed and every abandonment is logged and reported, so
   it is loud rather than silent. If it ever needs softening, the way
   is to tell a per-project failure from a systemic one, for instance
   by not counting an attempt when every delivery in a run has failed.
7. **Step 3f: the invariant check (4A). Done 2026-08-03.** Purely
   additive; it touches no mail path. Excludes notifications we
   deliberately left pending, so normal operation raises no nightly
   false alarm. Defer 4B; with the attempt counters in place, 4A plus
   the abandonment report covers the same ground.

   It ended up stronger than the sketch. Rather than reasoning about
   which projects *ought* to be excluded by joining `users` and reading
   attempt counters, `report_stuck_queue` re-counts the pending set in
   the database and compares it with the number the run knowingly
   deferred. `record_outcome` answers whether each notification is
   still pending, so the expected figure is a fact the run observed
   rather than a rule that has to be kept in step with every future
   reason for deferring. The concern about exclusions drifting out of
   date, recorded under option 4A, largely goes away.

   The point of counting from the database is that it takes no layer at
   its word. The original defect reported eleven emails sent and eleven
   flags cleared and left eleven flags set; every layer said it had
   worked. A test reproduces exactly that, by making the write a no-op
   that still claims one row, and the check catches it.

   It stays quiet when the run reached its cap, because the rest of the
   queue was never examined and there is nothing to conclude. That
   condition is simply `emails_sent < cap`, which is how option 4A
   words the invariant. An earlier version tracked which of the two
   `break`s the loop took, and that flag was both more code and an
   awkward thing to test; deriving the answer costs only that a run
   which examined everything and landed exactly on the cap also skips
   the check, one night's alarm at worst.

   The per-project work moved into `notify_project`, which returns how
   many emails it sent and whether anything is still pending for that
   project. `send_notifications` is then short enough to read at a
   glance, and both cap checks are ordinary guard clauses that the
   existing tests exercise.

Each step carries its own tests. Between them they cover the branches
listed under [concern 7](#a-note-on-test-coverage): suppressed, not
relevant, transient, permanent, exhausted, and write-affected-no-rows.

### Set 4: purge only the projects that changed

Done 2026-08-03. Listed among the separable items at first, then moved
into this branch: the recalculation is what takes a badge away, so
purging the badge that is no longer true belongs with it. Leaving it out
would have meant shipping a repair that notifies an owner their badge is
gone while the CDN carries on serving the old one.

1. **Purge per project, after its own commit.**
   `update_all_badge_percentages` asks `project.changed?` immediately
   before saving, and enqueues `PurgeCdnProjectJob` for that project's
   `record_key` once `with_lock` has committed. One key covers the
   badge, the baseline badge, and the JSON, since all three carry it as
   a surrogate key.
2. **Purge twice, briefly apart.** The whole-cache purge this replaces
   ran at the end of the recalculation, long after most projects had
   committed, so the reorder race did not arise: a response in flight at
   commit time had long since landed. Purging each project as soon as it
   is saved brings that race back, so it is closed the way
   `projects_controller` closes it around its own saves, with a repeat
   after `BADGEAPP_PURGE_DELAY`. Both are jobs, so a failed purge is
   retried with backoff rather than swallowed as `purge_all` swallows
   it.
3. **No fallback to `purge_all`, at any size.** This document
   originally called for one above a threshold, and a first cut
   implemented it; it was removed on review, and the reasoning is worth
   keeping because the fallback sounds prudent. Its purpose was to
   avoid Fastly's rate limits, but rate limiting arrives as an
   unsuccessful HTTP response, so `purge_by_key` returns false, the job
   raises, and Active Job retries with backoff. The problem was already
   handled. What the fallback added was a way to cold-start the cache
   of a very busy site in order to avoid going slowly, which is the
   worse trade, plus a constant, a branch, and a test that had to swap
   a constant out from under the class to reach it. The recalculation
   now logs how many projects it changed and purged, which `purge_all`
   never did.

The claim this rests on, that `project.changed?` identifies exactly the
affected rows at no cost, is now checked by a test rather than inferred
from a staging log: a recalculation run twice purges nothing the second
time. Doing that revealed something worth knowing about the fixtures.
They are hand-written and their stored percentages do not match what
recalculation computes, so the first run modifies every one of them; a
test about "nothing changed" has to settle them first. Production is the
other way round, which is what makes this change worth having.

A recalculation that changes nothing now costs the CDN nothing at all,
where before it cold-started the cache of an extremely busy site every
time.

### Set 5: stop publishing badging-process bookkeeping

Done 2026-08-03. `app/views/projects/_project.json.jbuilder` emitted
every one of a project's 450 columns, so `/projects/:id.json` published
our notification flags, sent-at timestamps, delivery attempt counters,
`last_reminder_at`, `lock_version`, and the per-level `*_saved`
edit-automation flags. `Project::BOOKKEEPING_FIELDS` now names those and
the view withholds them.

This is in the branch for two reasons, one urgent and one structural.

The urgent one: `loss_send_attempts` and `warning_send_attempts` are new
here and had never shipped. Publishing a field is easy and withdrawing
one is a breaking API change, so the moment to decide was before the
merge, not after.

The structural one is the more interesting. Because the JSON published
everything, every bookkeeping write changed a CDN-cached response, which
made *every* write a write that must purge. That is how
`send_reminders` came to leave stale cached JSON for ten days at a time
without anyone noticing, and the same was true of
`write_bookkeeping_columns` and `save_warning_columns` in this very
branch. Withholding these columns removes the reason those writes
invalidate anything, which is a better answer than adding a purge to
each of them and accepting nightly CDN churn for fields nobody reads.

That is not a hypothetical preference. `send_reminders` was first fixed
the other way, by adding a purge, and this set made that purge
pointless: it writes only `last_reminder_at`, which is now withheld and
appears on no cached page. The purge was removed again, and the reason
recorded where it was, so nobody restores it. Two purge jobs a night
per reminded project, for a field no reader can see, is exactly the
waste this list is meant to prevent.

`update_all_badge_percentages` uses the same rule: a project whose only
change was a pending-notification flag is not purged, because nothing
cached shows that flag. In practice a raised loss flag always
accompanies a percentage change, so this changes no behavior today; it
states the rule in the one place where it could otherwise drift.

The constant is deliberately a list of what to **withhold**, not what to
publish. New project data should reach the JSON without anyone having to
ask; only a column that answers "what has the badge application done
lately" belongs on the list. A model test asserts every name in it is a
real column, since a typo would silently publish the field it was meant
to withhold.

It is also the seed for
[section 11](cdn-cache-not-logged-in.md#11-potential-future-work-purge-the-cdn-from-a-model-callback) of the CDN document:
these are exactly the columns whose change cannot make any cached page
stale, so a future purge callback can skip a write that touched only
them.

### Separable, any time

1. **Fix the Fastly initializer ordering** and its misleading comment.
   Done 2026-08-03; see
   [the finding](#the-fastly-credential-check-has-never-run).
2. **Retire the stub `worker` dyno.** Done 2026-08-03; see
   [the finding](#the-worker-dyno-runs-a-stub-and-crash-loops).
3. **Audit for other writes that optimistic locking can disturb.**
   `projects` is the only table with a `lock_version` column today, and
   the survey in
   [The same trap was already known](#the-same-trap-was-already-known)
   found no other write through a partially loaded record. That survey
   asked only whether writes would *fail*. It did not ask the second
   question this review raised: which writes silently *bump*
   `lock_version` and can therefore make a project owner's in-flight edit
   fail with `StaleObjectError` for no reason the owner can see. Any
   `save`, `update`, `update_column`, or `update_all` on a project from a
   background task or an administrative path is a candidate. Where such a
   write is bookkeeping rather than user content, convert it to a
   parameterized SQL statement as in option 1D; that is both simpler and
   immune to this class of surprise.
4. **Purge individual project data instead of the whole CDN cache.**
   Moved into this branch and **done 2026-08-03**; it is not separable
   after all. The recalculation is what takes badges away, so the purge
   that stops a lost badge still being served is part of the same
   repair, not a tidy-up alongside it. See
   [Set 4](#set-4-purge-only-the-projects-that-changed).

### Operational

1. Run the baseline recalculation so the 8 affected projects show
   correct badge levels, and confirm the CDN purge at the end of
   `update_all_badge_percentages` actually runs. **Done on 2026-07-31**,
   purge confirmed; see [Actions taken](#actions-taken-on-2026-07-31).
2. Clear the 11 stale warning flags and the 5 older loss flags, using
   the statements in
   [Disposition of the pending flags](#disposition-of-the-pending-flags).
   **Done on 2026-07-31** and verified.
3. Leave the 8 new loss flags set, so those owners each receive one
   badge-loss email when the caps are restored. Disposition decided
   2026-07-31.
4. Restore `BADGEAPP_MAX_BADGE_LOSS_NOTIFICATIONS` and
   `BADGEAPP_MAX_BADGE_WARNING_NOTIFICATIONS` to 20 **after all three
   sets are deployed**, then confirm on the following run that the 8
   pending loss emails went out, exactly once each, and that the flags
   cleared. Revised 2026-08-03; this item previously called for
   restoring the caps as soon as set 1 was deployed. See
   [Deployment: everything lands together](#deployment-everything-lands-together).

## Open questions

* Should we notify the affected owners that the repeated emails were our
  error? Eleven owners received roughly 13 duplicates each and a few
  received far more.
  Answer: No. They've already received enough messages.
* Should `last_warning_sent_at` and `last_loss_sent_at` record attempts
  or deliveries? They currently record neither reliably, and this
  investigation showed that we reach for them first when asked whether
  someone was emailed.
  Answer: They should record *successful deliveries*. If there was a
  transient failure we should try again later. This contradicted option
  2C, which clears the flag before sending and so records attempts;
  [concern 6](#6-recording-deliveries-and-retrying) resolves the
  conflict and supersedes 2C.
* Are there other places in the codebase that write through a partially
  loaded record? A survey found none today: the other partial `SELECT`
  sites (badge display, index, feed, user lookups) are read-only, and
  `projects` is the only table with a `lock_version` column. Option 3B
  would turn this from a manual survey into an automatic check.
  Answer: surveyed and settled; see
  [The same trap was already known](#the-same-trap-was-already-known).
  One site does write through a partial `SELECT` and is safe only
  because someone deliberately included `lock_version` in its field
  list, which is the clearest argument for making the check mechanical.
