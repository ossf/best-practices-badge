# Automation rules for the edit form

We have some built-in automation analysis mechanisms
(implemented by a Chief and various detectives),
as well as support for externally-provided analysis.
These automations are used while editing a project entry.

## Highlighting

Changes made by automation are highlighted in the edit form so the
user stays informed:

- **Yellow (automated)**: Automation filled in a value that was
  previously unknown ('?') or blank. The user can freely change these.
- **Orange (overridden)**: Automation *replaced* a real value the user
  (or an earlier automation) had set. This signals that the underlying
  repository data disagrees with the old value, and changing it back
  may require a change to the repository.

A change to *either* the criterion status *or* its justification
(from *either* built-in or external automation) causes that criterion
to be highlighted.

Highlighting state is carried in hidden form fields so it survives
a "save and continue" redirect.

## Rule 1 -- Invariant: the user is always shown the results

The user is *always* shown highlighted automation results whenever
project data is changed by automation, so that the user always stays
informed. If a change is not an override, the user is always in
control and can change it before saving.

## Rule 2 -- Initial edit of a section (Chief)

On the *first* edit of a project section (`SECTION_saved` is false),
the `edit` method calls `run_first_edit_automation_if_needed`, which:

1. Snapshots every automatable field for the current section
   (`capture_original_values`).
2. Runs `Chief#autofill` scoped to the fields in the current section.
   The Chief asks each detective to propose changes; proposals with
   confidence >= `CONFIDENCE_OVERRIDE` (4) are "forced" and will
   overwrite even non-'?' values. Lower-confidence proposals only
   fill in '?' / blank fields.
3. Calls `categorize_automation_changes` to compare old vs new values
   and populate `@automated_fields` (yellow) and `@overridden_fields`
   (orange). The categorization logic is:
   - Status field changed from '?' to a real value --> automated.
   - Status field changed from one real value to another --> overridden.
   - Justification changed --> automated (attributed to its status field).
   - Non-criteria field (name, license, description,
     `implementation_languages`) filled from blank --> automated.

The `SECTION_saved` flag is *not* set here; it is only set when the
user actually saves. If they abandon the edit without saving, the
next visit will re-run Chief automation.

We only run the Chief on the initial edit because it can be slow
(external API calls, rate limits). After the first time, users
should not be delayed for a quick edit.

## Rule 3 -- Query string proposals (external automation)

On *every* entry to the `edit` method -- even when `SECTION_saved`
is true -- the method calls `apply_query_string_automation`, which:

1. Snapshots just the fields whose names appear in the query string
   (`capture_query_string_field_values`).
2. Calls `apply_query_string_proposals_to_project` to apply valid
   query-parameter values to the project's in-memory model.
   Only parameters whose names match a field in the current section's
   `FIELDS_BY_SECTION` set are accepted. Status values must be one of
   `Met`, `Unmet`, `N/A`, or `?` (case-insensitive). Blank values are
   accepted for non-status fields. Invalid or unrecognized parameters
   are silently ignored.
3. For each field that actually changed, appends an entry to
   `@automated_fields` (yellow highlighting).

This runs *after* the initial-edit Chief automation (Rule 2), so
query-string values can override what Chief set. However, the
Chief does not distinguish between query-string-set values and
user-entered values on later saves -- they are just values being
proposed for saving.

The query string is consumed on entry to `edit` and does *not*
propagate past a "save and continue" or "save and exit".
Thus, externally-proposed automations are not "stuck" - humans can
decide to override those proposals, and those human changes will be accepted
unless the built-in rules override them.

Example URL:

```text
/en/projects/123/passing/edit?contribution_status=Met&name=MyProject
```

## Rule 4 -- Save always runs the Chief

After any save (either "save and continue" or "save and exit"),
`run_save_automation` runs the Chief via `Chief#propose_changes`
(not `autofill`). This uses `propose_changes` + `apply_changes`
so the controller can inspect proposals before applying them.
The processing differs between the two save types (Rules 5 and 6).

## Rule 5 -- Save and continue

When the user clicks "save and continue" (`params[:continue]` is
present), `run_save_automation` is called with
`track_automated: true`:

- The Chief proposes changes, filtered to the current section.
- Each proposal is categorized via `categorize_chief_proposal`.
  Forced overrides of real (non-'?') user values are **overridden**
  (orange) and always tracked. Fills of '?' or blank values are
  **automated** (yellow) and tracked because `track_automated` is true.
- *All* proposed changes (forced and non-forced) are applied to the
  project model before saving.
- The edit form is re-displayed with the highlighting so the user
  can review and change automation results before the next save.

## Rule 6 -- Save and exit

When the user clicks "save and exit" (`params[:continue]` is absent),
`run_save_automation` is called with `track_automated: false`:

- The Chief proposes changes, filtered to the current section.
- Each proposal is categorized, but non-forced fills are *not* tracked
  (since the user won't see an edit form).
- Only **forced** proposals (confidence >= `CONFIDENCE_OVERRIDE`) are
  applied. Non-forced proposals are discarded because the user has not
  reviewed them.
- If any forced changes override the user's values, the save still
  succeeds, but the user is redirected back to the edit form with
  the overridden fields highlighted (orange), so they are informed.

## Rule 7 -- Chief crash recovery

If the Chief raises an exception during `run_save_automation`, the
`handle_chief_save_failure` handler:

1. Logs the error.
2. Identifies which of the user's changed fields are potentially
   overridable by any detective (via `OVERRIDABLE_OUTPUTS`).
3. Restores the user's original values for those fields, so the
   user's input is not lost.
4. Sets `@chief_failed` so the view can show a flash warning.

The save then proceeds with the user's values intact (minus any
Chief changes that may have partially applied to non-overridable
fields).

## Rule 8 -- Override invariant

The system will never save to the database
that a project criterion is `Met`
if the built-in system overrides the criterion as `Unmet`
in *normal* operation.

In normal operation this holds: both save-and-continue (Rule 5,
applies all proposals) and save-and-exit (Rule 6, applies forced
proposals) will apply a forced `Unmet` override before persisting.

**Known gap -- Chief crash (Rule 7):** If Chief raises an exception
during save, `handle_chief_save_failure` restores the user's values
and the save proceeds (`@chief_failed` only controls the flash
message, not whether `@project.save` runs). This means the user's
`Met` can be persisted without Chief having a chance to override it.
On the *next* save Chief will run again and should correct it, but
if the user never returns or the Chief always crashes the `Met` persists.

This is a deliberate trade-off: Rule 7 prioritizes not losing user
data during errors over strict enforcement of this invariant.
The user could create a special repo system that
is intentionally uncooperative, but at that point they can just lie.

## Justification handling

In built-in automations (Chief/detectives), justifications for a
criterion are only changed when the corresponding status is changed.
When a justification is changed, it overwrites (not appends to) the
old justification. If the status is unchanged and a justification
already exists, the existing justification is preserved
(`Chief#apply_changes`).

External automation proposals (query string) can propose a change
to just a justification or just a status independently.

## Implementation reference

Key methods in `ProjectsController` (all private):

| Method | Purpose |
|---|---|
| `run_first_edit_automation_if_needed` | Rule 2: Chief on first edit |
| `apply_query_string_automation` | Rule 3: query string proposals |
| `run_save_automation` | Rules 4-6: Chief on save |
| `categorize_automation_changes` | Classify initial-edit changes |
| `categorize_chief_proposal` | Classify a single save-time proposal |
| `handle_chief_save_failure` | Rule 7: crash recovery |
| `capture_original_values` | Snapshot all automatable fields |
| `capture_query_string_field_values` | Snapshot query-string fields only |
| `apply_query_string_proposals_to_project` | Parse and apply query params |
| `filter_automated_fields_for_current_section` | Scope highlights to section |

The `SECTION_saved` flags (e.g., `passing_saved`, `baseline_1_saved`)
are defined in `Sections::LEVEL_SAVED_FLAGS` and stored as boolean
columns on the project. They are set to true by `set_level_saved_flag`
only during a save, never during initial-edit automation.
