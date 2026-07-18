# Updating the Baseline Criteria

This document explains the steps to update the
[OpenSSF Open Source Project Security Baseline (OSPS Baseline)](https://baseline.openssf.org/)
criteria when a new version is published.

The baseline criteria are stored in `criteria/baseline_criteria.yml`.
When a new version is published, existing criteria may have updated text, and
new criteria may be added.

When we import the updated baseline criteria,
updated criteria text with an existing identifier is used immediately
(these are clarifications and/or minor relaxations).
New criteria are initially marked `future: true`
so they are visible in the form (with an "upcoming criterion" label) but do
not count toward the badge percentage until the transition period ends.

## Step 0: Verify No Current "Future" Criteria

Before starting an update, confirm that no criteria in the current file are
marked as future. This ensures you are beginning from a stable, fully-active
baseline before introducing new criteria.

```bash
grep -c 'future: true' criteria/baseline_criteria.yml
```

This should print `0`. If it prints a non-zero number, the previous update
cycle is not yet complete—existing future criteria have not yet been
activated. Resolve that first (see
[Completing the baseline update transition](#completing-the-baseline-update-transition)
below).

You can also run the validator to confirm the file is internally consistent:

```bash
rake baseline:validate
```

## Step 1: Identify the New Baseline Version

Visit <https://baseline.openssf.org/> to find the URL of the new version.
Version URLs follow the format
`https://baseline.openssf.org/versions/YYYY-MM-DD`.

Record both the old and new version strings. For example:

- Old version: `2025-10-10` (currently in `criteria/baseline_criteria.yml`
  under `_metadata.source_url` and in `config/baseline_config.yml`)
- New version: `2026-02-19` (replace with the actual new date)

## Step 2: Download the Updated Baseline Criteria HTML

Create the `tmp/` directory if it does not exist, then download the new
version's HTML page:

```bash
mkdir -p tmp
curl -s 'https://baseline.openssf.org/versions/YYYY-MM-DD' \
     -o tmp/baseline_source.html
```

Replace `YYYY-MM-DD` with the new version date (e.g., `2026-02-19`).

## Step 3: Parse and Extract the Criteria

Run the extraction script to parse the downloaded HTML and produce working
files in `tmp/`:

```bash
script/extract_baseline.rb
```

**Inputs:**

- `tmp/baseline_source.html` — the downloaded HTML from Step 2
- `criteria/baseline_criteria.yml` — the current criteria file, used to
  detect new, obsolete, and changed criteria and to preserve `future:` and
  `obsolete:` flags on re-extraction

**Outputs (in `tmp/`, not yet committed):**

- `tmp/baseline_extracted.yml` — criteria in the application's YAML format,
  with `future: true` automatically added to any criterion whose key does not
  yet exist in `criteria/baseline_criteria.yml`, and `obsolete: true`
  re-added to any existing criterion whose key is absent from the new version
- `tmp/baseline_extracted.json` — same data in JSON (useful for review)

It prints a summary showing how many controls were extracted, how they are
distributed across maturity levels and categories, and which (if any) keys
are new, obsolete, or had their description/details text changed.
Verify the counts look reasonable compared with the previous version.

**Re-running is safe.** Given the same inputs the script always produces the
same outputs—`future:` and `obsolete:` flags already present in
`criteria/baseline_criteria.yml` are preserved in the extracted file.
No data is lost by re-running.

## Step 4: Review and Merge Changes into baseline_criteria.yml

Copy the extracted file over the current criteria file and use `git diff`
to review what changed:

```bash
cp tmp/baseline_extracted.yml criteria/baseline_criteria.yml
git diff criteria/baseline_criteria.yml
```

The extraction script already annotates the two interesting cases
automatically and reports them on stdout:

- **New criteria** (not in the previous file): marked `future: true`
- **Obsolete criteria** (in the previous file but absent from the new
  upstream version): re-added at their original location with `obsolete: true`

Review the script's output to confirm these lists look reasonable. If the
number of obsolete criteria is unexpectedly large it likely indicates a
**failed or partial import** (e.g., the HTML parser missed a section).
In that case, stop, investigate `tmp/baseline_extracted.yml`, and re-run
Step 3 before continuing.

Obsolete criteria are shown on the baseline form with an "(Obsolete criterion)"
label so users can refer to them while updating their other answers. They are
excluded from badge percentage calculations. Do not drop the corresponding
database columns for obsolete criteria; retained columns cause no harm and
preserve historical data.

Also update the `_metadata` section at the top of
`criteria/baseline_criteria.yml` to reflect the new version:

```yaml
_metadata:
  source: OpenSSF Baseline HTML
  source_url: https://baseline.openssf.org/versions/YYYY-MM-DD
  extracted_at: 'YYYY-MM-DDTHH:MM:SS-ZZ:ZZ'
  auto_generated: true
  total_controls: NN
```

## Step 5: Generate and Run a Database Migration (New Criteria Only)

If any new criteria were added in Step 4, their `_status` and
`_justification` columns do not yet exist in the database. Generate the
migration:

```bash
rake baseline:generate_migration
```

**Inputs:**

- `criteria/baseline_criteria.yml` — source of truth for which criteria keys
  must exist
- `config/baseline_field_mapping.json` — maps criterion keys to database
  column names (created automatically if absent)

**Outputs:**

- `config/baseline_field_mapping.json` — updated with any new criteria keys
  not yet present in the file
- `db/migrate/TIMESTAMP_add_baseline_criteria_*.rb` — a new migration adding
  the `_status` and `_justification` columns for each new criterion

Be sure to `git add` both the updated mapping file and the new migration.

**Re-running:** If you re-run the task with no new criteria, it reports
"No new fields to add" and writes no migration. If there are new criteria
but you already ran the task, a second run will again find nothing to add
(the mapping file was already updated). Running the migration itself
(`rails db:migrate`) is always safe to re-run; Rails skips already-applied
migrations.

Apply the migration:

```bash
rails db:migrate
```

If no new criteria were added, skip this step (running
`rake baseline:generate_migration` will report "No new fields to add").

## Step 6: Update the i18n Translations

Extract the updated `description`, `details`, and placeholder text from
`criteria/baseline_criteria.yml` into `config/locales/en.yml`:

```bash
rake baseline:extract_i18n
```

**Inputs:** `criteria/baseline_criteria.yml`

**Output:** `config/locales/en.yml` — the section between markers
`# BEGIN BASELINE CRITERIA AUTO-GENERATED` and
`# END BASELINE CRITERIA AUTO-GENERATED` is replaced with the current
criteria text. All content outside those markers is preserved unchanged.

The extraction includes **all** criteria regardless of their `future:` or
`obsolete:` status, so text for upcoming and retired criteria is available
in the locale file for display on the form.

**Re-running is safe and idempotent.** Re-run it whenever you modify
`criteria/baseline_criteria.yml` to keep the locale file in sync.

## Step 7: Validate the Updated Criteria

Run the validator to confirm the files are internally consistent:

```bash
rake baseline:validate
```

**Inputs (read-only, nothing is written):**

- `criteria/baseline_criteria.yml`
- `config/locales/en.yml`
- `config/baseline_field_mapping.json` (if present)

**What it checks:**

- `criteria/baseline_criteria.yml` is valid YAML
- No criterion has both `future: true` and `obsolete: true` simultaneously
- Every criterion has a non-empty `description`
- Every criterion whose description is in the criteria YAML is also present
  in `config/locales/en.yml` (detects a missing `rake baseline:extract_i18n`
  run)
- `config/baseline_field_mapping.json` is valid JSON (if the file exists)

A passing run prints:

```
✓ Baseline criteria validation passed
```

Fix any reported errors before continuing.

## Step 8: Update the Baseline Version Constants

Edit `app/lib/baseline_config.rb` to reflect the transition. During the
transition period (after the new criteria are deployed but before they are
enforced), set `IN_TRANSITION` to `true` and fill in all four constants:

```ruby
module BaselineConfig
  CURRENT_VERSION = 'v2025.10.10'
  IN_TRANSITION   = true
  NEW_VERSION     = 'v2026.02.19'  # used only during transition
  ENFORCE_DATE    = '2026-06-01'   # used only during transition
end
```

- `CURRENT_VERSION` is the version whose criteria are currently active
  (the old version, until the enforce date). It also appears in badge
  text: `"openssf baseline CURRENT_VERSION"`.
- `NEW_VERSION` is the version being adopted (criteria shown as "upcoming").
- `ENFORCE_DATE` is the date (YYYY-MM-DD) when new criteria start counting
  toward the badge.

When not in transition (steady state), set `IN_TRANSITION = false` and
update `CURRENT_VERSION` to the new version string:

```ruby
module BaselineConfig
  CURRENT_VERSION = 'v2026.02.19'
  IN_TRANSITION   = false
  NEW_VERSION     = ''  # unused when not in transition
  ENFORCE_DATE    = ''  # unused when not in transition
end
```

The version notice partial (`app/views/projects/_form_baseline_version_notice.html.erb`)
reads from `BaselineConfig` automatically — no changes needed there.

## Step 8a: Regenerate Baseline Badge Images

Because `CURRENT_VERSION` appears in the badge text
(`"openssf baseline v2025.10.10"`), changing it changes the text width
and therefore the badge dimensions. Run the generator to produce correct
badge images:

```bash
ruby script/generate_baseline_badges.rb
```

The script measures text widths from the actual Verdana font using Python
and Pillow, then computes correct badge dimensions automatically. It prints
which measurement method it used. If Python or Verdana are not available it
falls back to a built-in character-width table and prints installation
instructions.

After the script completes, update the asset pipeline:

```bash
rake assets:precompile
```

## Step 9: Restart the Application

Criteria are loaded into `CriteriaHash` and `FullCriteriaHash` at Rails
startup in `config/initializers/00_criteria_hash.rb`. Changes to
`criteria/baseline_criteria.yml` or `config/locales/en.yml` do not take
effect until the application is restarted.

In development:

```bash
rails s
```

In production, follow the standard deployment procedure (e.g., restart
Puma workers).

## Step 10: Verify a Changed Criterion Shows the Updated Text

Open a project's baseline form (e.g., `/en/projects/1/baseline-1`) and
navigate to a criterion whose text was updated in Step 4. Confirm that the
form now displays the new description and details text.

Alternatively, check from the Rails console:

```ruby
Criteria['baseline-1']['osps_xx_nn_nn'].description
```

Replace `osps_xx_nn_nn` with the key of the changed criterion.

## Step 11: Verify a New Criterion Is Served but Marked "Future"

Open the same baseline form and locate the new criterion. It should be
visible with the label "(upcoming criterion)" before its description. This
label is rendered by `app/views/projects/_status_chooser.html.erb` when
`criterion.future?` returns `true`.

Confirm from the Rails console that the criterion exists but is excluded
from the active set:

```ruby
# Should exist:
Criteria['baseline-1']['osps_xx_nn_nn']

# Should NOT appear in the active list:
Criteria.active('baseline-1').map(&:name).include?('osps_xx_nn_nn')
# => false
```

Replace `osps_xx_nn_nn` with the new criterion's key.

## Step 12: Perform Machine Translation

After `config/locales/en.yml` has been updated with the new and changed
criterion text, run automated machine translation to fill in the other
supported locales:

```bash
rake translation:all
```

This iterates over all locales that have untranslated or stale segments
(i.e., where the English source has changed since the machine translation
was generated) and translates them using GitHub Copilot. It runs until all
locales are up to date. Human translations always take precedence over
machine translations.

You can check translation status before and after with:

```bash
rake translation:status
```

## Sending advance warnings (before the enforce date)

Before the enforce date arrives, you can preview which projects will lose a
badge, send them advance notice, and verify the count is manageable. None of
these steps are required, but they are strongly recommended.

### Step A: Preview affected projects

Run a dry-run report that shows every project which would lose a badge under
the new criteria. No database writes occur.

```bash
EFFECTIVE_DATE=YYYY-MM-DD rake badge_warning_report
```

Replace `YYYY-MM-DD` with the enforce date set in `BaselineConfig::ENFORCE_DATE`.
Each line of output shows:

```
Project 42 "My Project" | User 7 Alice <alice@example.com> | baseline-1 -> in_progress (baseline)
```

Review the list. If the count looks unexpectedly large, re-check the criteria
changes before proceeding; a very large loss count may indicate an import
error.

### Step B: Set warning flags

Once you are satisfied with the report, record the warning in the database so
that the daily notification job can start sending emails. Pass the enforce
date (`BaselineConfig::ENFORCE_DATE`) via `EFFECTIVE_DATE`, in `YYYY-MM-DD`
form (the same convention as `update_badge_warnings`):

```bash
EFFECTIVE_DATE=2026-07-31 rake update_baseline_badge_warnings
```

On the live site, run it through the Heroku CLI (the `env` prefix sets the
variable inside the one-off dyno):

```bash
heroku run --app production-bestpractices -- \
  env EFFECTIVE_DATE=2026-07-31 bundle exec rake update_baseline_badge_warnings
```

This writes `unreported_baseline_badge_warning` and
`badge_warning_effective_date` to each affected project row. It is scoped to
the baseline levels, so it does not disturb the metal badges.

To verify how many projects have pending warnings:

```ruby
# Rails console
Project.where('unreported_badge_warning > 0 OR unreported_baseline_badge_warning > 0').count
```

### Step C: Warning emails drain automatically

The `reminders` rake task (already configured on the scheduler) calls
`badge_warning_notifications` every day as part of its normal run. Each
invocation sends at most `BADGEAPP_MAX_BADGE_WARNING_NOTIFICATIONS` emails
(default: 10) and clears the flags for the projects it contacts. The queue
drains over successive days until all affected owners have been notified.

You can also trigger a manual drain at any time:

```bash
rake badge_warning_notifications
```

See [Email notification rate configuration](#email-notification-rate-configuration)
below for how to adjust the daily cap and check remaining counts.

## Completing the baseline update transition

When the enforce date arrives (the date set in `baseline_enforce_date`),
complete the transition: activate the new criteria, retire the obsolete
criteria from display, and close out the version notice.

1. **Activate the new criteria.** Remove `future: true` from each
   previously-future criterion in `criteria/baseline_criteria.yml`.
   If `future: false` was set explicitly, remove that line too (the
   default is `false`).

2. **Archive and remove obsolete criteria.** For each `obsolete: true`
   criterion in `criteria/baseline_criteria.yml`:

   a. Append an entry to `criteria/baseline_criteria_retired.yml`,
      recording the criterion key, English text, original upstream ID,
      and the baseline version in which it was retired. For example:

      ```yaml
      osps_br_01_02:
        original_id: OSPS-BR-01.02
        retired_baseline_version: 'v2026.02.19'
        removed_from_display: '2026-06-01'
        description: >-
          When a CI/CD pipeline uses a branch name in its functionality,
          that name value MUST be sanitized and validated prior to use
          in the pipeline.
        details: ''
      ```

      This file accumulates entries across update cycles and is never
      loaded by the application — it exists solely as a human-readable
      archive. If a criterion ever needs to be restored, the text is
      here. Create the file if it does not yet exist, with a comment
      header explaining its purpose.

   b. Delete the entire criterion entry (not just the `obsolete: true`
      line) from `criteria/baseline_criteria.yml`.

   After archiving, run `rake baseline:extract_i18n` to regenerate
   the locale file without the now-removed criteria. This is safe
   because the English text is preserved in the archive file.

3. **Validate.** Run `rake baseline:validate` to confirm the criteria file
   is still consistent:

   ```bash
   rake baseline:validate
   ```

4. **Update the version constants.** Edit `app/lib/baseline_config.rb`
   to reflect that the transition period has ended (see Step 8).
   Set `IN_TRANSITION = false` and update `CURRENT_VERSION` to the
   now-fully-active version string:

   ```ruby
   module BaselineConfig
     CURRENT_VERSION = 'vYYYY.MM.DD'
     IN_TRANSITION   = false
     NEW_VERSION     = ''
     ENFORCE_DATE    = ''
   end
   ```

   Then regenerate badge images (see Step 8a):

   ```bash
   ruby script/generate_baseline_badges.rb
   rake assets:precompile
   ```

5. **Restart the application.** The newly activated criteria will be
   included in `Criteria.active(level)`. Obsolete criteria will no
   longer appear on the form.

6. **Recalculate badge percentages and purge the CDN.** After the
   application restarts, the stored `badge_percentage_baseline_*`
   values in the database are stale; they were computed under the old
   set of active criteria. Projects will be corrected one-by-one as
   their owners save changes, but you must force an immediate bulk
   recalculation so that every project's badge reflects the new active
   criteria right away.

   Run the recalculation task:

   ```bash
   rake recalc_baseline_and_notify_losses
   ```

   On the live site, run it through the Heroku CLI:

   ```bash
   heroku run --app production-bestpractices -- \
     bundle exec rake recalc_baseline_and_notify_losses
   ```

   Do NOT put this recalculation inside a database migration. It walks every
   project and saves each one, and inside the single transaction that Rails
   wraps around a migration, ActiveRecord keeps every touched project row
   (each is very wide, about 400 columns) alive until the transaction commits.
   Memory then grows without bound and the dyno is killed (R14/R15, exit 137)
   partway through; the transaction rolls back, the migration never records,
   and it re-runs and re-dies on every deploy. The rake task runs outside any
   wrapping transaction, so each project's own short transaction commits and
   releases, which keeps memory bounded. (This is exactly why the earlier
   `RecalcBaselineBadgePercentages` migration was retired to a no-op.)

   `update_all_badge_percentages` calls `FastlyRails.purge_all` on
   completion, so the CDN badge cache is purged automatically; no
   manual cache invalidation is needed. The next request for any
   project's `/baseline` badge will fetch the freshly computed value.

   **Badge-loss notifications are sent automatically.** For each project
   whose badge level dropped, `update_all_badge_percentages` records the
   loss in `unreported_badge_loss` / `unreported_baseline_badge_loss`. The
   `reminders` rake task (already running daily on the scheduler) calls
   `badge_loss_notifications` every day, which sends at most
   `BADGEAPP_MAX_BADGE_LOSS_NOTIFICATIONS` emails (default: 10) and clears
   the flags. The queue drains over successive days with no further action
   required. To check how many loss notifications remain:

   ```ruby
   # Rails console
   Project.where('unreported_badge_loss > 0 OR unreported_baseline_badge_loss > 0').count
   ```

   See [Email notification rate configuration](#email-notification-rate-configuration)
   for how to adjust the daily cap if the default is too slow or too fast.

7. **Verify** from the Rails console:

   ```ruby
   # Previously-future criteria should now be active:
   Criteria.active('baseline-1').map(&:name).include?('osps_xx_nn_nn')
   # => true

   # Previously-obsolete criteria should no longer be loaded:
   Criteria['baseline-1']['osps_yy_nn_nn']
   # => nil
   ```

   Replace `osps_xx_nn_nn` and `osps_yy_nn_nn` with the actual keys.

## Email notification rate configuration

Two environment variables cap how many badge emails the daily job sends each
day. The caps exist to avoid being flagged as a spammer and to limit blast
radius if there is a bug.

| Variable | Default | Controls |
|---|---|---|
| `BADGEAPP_MAX_BADGE_WARNING_NOTIFICATIONS` | 10 | Advance-warning emails per day |
| `BADGEAPP_MAX_BADGE_LOSS_NOTIFICATIONS` | 10 | Badge-loss notification emails per day |

Set them in your hosting environment (e.g., on Heroku:
`heroku config:set BADGEAPP_MAX_BADGE_LOSS_NOTIFICATIONS=50`).

### Estimating days to drain the queue

Before changing a cap, check how many notifications are pending:

```ruby
# Rails console — pending loss notifications
Project.where('unreported_badge_loss > 0 OR unreported_baseline_badge_loss > 0').count

# Rails console — pending warning notifications
Project.where('unreported_badge_warning > 0 OR unreported_baseline_badge_warning > 0').count
```

Divide the count by the daily cap to get the approximate number of days
to drain the queue. For example, 50 pending loss notifications with the
default cap of 10 will drain in about 5 days. Raise the cap if you need
faster delivery; lower it if you want a slower rollout.

Note that silently-drained notifications (owners who have opted out of
important notifications) do not count toward the cap, so the actual
email count may be lower than the pending-row count.

### How the daily email task works

The `reminders` rake task (already run once per day by the Heroku Scheduler
or equivalent) automatically includes both notification drains alongside the
regular inactive-project reminders:

```
rake reminders
```

No separate scheduler entry is required for either notification type.
The tasks are also available as standalone commands if you need to trigger
a manual drain:

```bash
rake badge_loss_notifications
rake badge_warning_notifications
```
