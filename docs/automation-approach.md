# Automation Approach

This document describes how the badge application handles automation
of field values.
proposals. This includes "external automation proposals" from
external tools (the URL query string) and from the
internal Chief/detective system (including files in the repo).
It covers where proposals originate, how
the projects controller acquires and classifies them, and how the results
reach the view. Method names are given so you can navigate directly to the
code in `app/controllers/projects_controller.rb`.

See `docs/automation-proposals.md` for the end-user-facing description of
the URL proposal interface.

## Two Sources of Proposals

### 1. URL Query-String Proposals (external automation proposals)

External tools can propose field values by encoding them as query parameters
in a project-edit URL. For example:

```
/en/projects/42/edit?contribution_status=Met&contribution_justification=Has+CONTRIBUTING.md&overrides=contribution_status
```

Any field name that is valid for the current badge section may appear.
The optional `overrides` parameter is a comma-separated list of
[`File.fnmatch`](https://ruby-doc.org/core/File.html#method-c-fnmatch)
glob patterns (e.g. `*`, `osps_ac_*`) that mark matching fields as
**forced**, meaning they may overwrite an existing answer. Unforced
proposals only fill blank or unknown (`?`) slots.

These proposals run on every visit to the edit page, so an external tool
can pre-fill the form by sending the user to a crafted URL.

### 2. Chief / Detective Proposals (internal automation)

The built-in automation runs detectives against the project's repository
data (GitHub API, `best-practices.json`, etc.) to derive proposed field
values. This runs automatically on:

- The **first edit** of each badge section (before the section has been saved)
- On entry when **`?reanalyze`** is in the URL.
- Every **save** event (Save and Continue, or Save and Exit), to
  detect changes made to the underlying repository since the last edit.
  "Save and Continue" runs full analysis and shows proposals.
  "Save and Exit" only runs analysis that might override; any override is
  *enforced* and saved, and then we re-display the forced values in an
  edit field (so the user is made *aware* of the forced values).

## The Chief / Detective Architecture

`Chief` (`app/lib/chief.rb`) is the coordinator. It discovers every class
that inherits from `Detective` by auto-loading all `app/lib/*_detective.rb`
files and inspecting `Detective.descendants`. The resulting `ALL_DETECTIVES`
array is frozen at startup.

The detectives do the work of gathering data and/or analyzing it
to determine automated results.
Each detective declares:

- `INPUTS`: field symbols it needs to read from the project to do its work
  (e.g. `[:repo_url]`).
- `OUTPUTS`: field symbols it can propose.
- `OVERRIDABLE_OUTPUTS`: a subset of `OUTPUTS` it is allowed to force
  (confidence ≥ `CONFIDENCE_OVERRIDE = 4`).
- `analyze(evidence, current)`: returns a hash of
  `{ field_sym => { value:, confidence:, explanation: } }`.

Chief runs the detectives in topological order (their dependency graph is
resolved with Kahn's algorithm) and merges their changesets. A proposal
with higher confidence wins over a lower-confidence proposal for the same
field; ties keep the earlier proposal. After merging, Chief translates each
proposal's confidence into a boolean `:forced` flag
(`confidence >= CONFIDENCE_OVERRIDE`) and discards the raw confidence from
the hash exposed to the controller, keeping that detail internal.
Currently confidence scales from 0..5 and `CONFIDENCE_OVERRIDE` is 4;
these confidence values are never shown publicly (so we can change them).

The public Chief methods used by the controller are:

- `propose_changes(needed_fields:, changed_fields:, only_consider_overrides:)`:
  runs detectives and returns the proposals hash without applying anything.
- `apply_changes(project, changes)`: writes the proposed values to `@project`.
- `autofill(...)`: convenience wrapper combining both (not used in the
  proposal-aware paths described here, where classification must happen
  between propose and apply).

## The Unified Proposals Format

Both sources normalize into the same format before classification:

```ruby
{
  field_sym => {
    value:,                  # Integer for _status, String for everything else
    forced:,                 # bool: overwrite an existing real value?
    explanation:,            # String or nil: why automation suggests this
    proposed_justification:  # String or nil: for _status fields only; the
                             # justification text shown in the ≠ popover
  }
}
```

For URL proposals, `explanation` is always `nil` (URLs carry no rationale),
and `proposed_justification` is read from the paired `NAME_justification`
parameter. Chief proposals carry an `explanation` from the detective's
`analyze` return value.

## Highlight Categories

After classification, each proposal falls into exactly one of three
instance-variable buckets that the view reads:

| Variable | CSS class | Meaning |
|---|---|---|
| `@automated_fields` | `.highlight-automated` (yellow) | Blank/unknown filled by automation |
| `@overridden_fields` | `.highlight-overridden` (orange) | Existing real value forced by automation |
| `@divergent_fields` | `.highlight-divergent` (blue ≠) | Automation disagreed but was not forced; user's value kept |

These are populated only, never cleared, so URL and Chief results
accumulate together via `||=` when both sources run on the same request.

The `track_automated` flag (a boolean threaded through `run_save_automation`
and `classify_chief_proposals`) controls whether yellow and ≠ are recorded:

- `true`: Save and Continue, first edit, or repo URL changed. All three
  categories are recorded so the user can review them on the redirected edit
  page.
- `false`: Save and Exit. Only orange (forced overrides) is recorded, and
  only forced proposals are applied. Non-forced blank-fills are silently
  skipped so no value lands in the database without the user having a chance
  to review it.

## The Decision Matrix

Both sources share the same two-pass matrix, implemented once in
`classify_status_pass` and `classify_non_status_pass`.

### Pass 1, `_status` fields

| Current value | Proposed value | Forced? | Result | Highlight |
|---|---|---|---|---|
| any | unparsable or `?` | - | Skip (pre-screened in `build_url_proposals`) | none |
| blank / `?` | any real value | either | Apply | 🤖 yellow |
| real, equals proposed | - | - | Skip (no-op) | none |
| real, differs | differs | no | Keep user value | ≠ blue |
| real, differs | differs | yes | Overwrite | ⚠️  orange |

### Pass 2, `_justification` and other non-`_status` fields

**Coupling rule**: if the paired `_status` field was divergent (kept), the
justification is skipped entirely (even if forced) because a justification
for the wrong status answer would actively mislead the user.

Otherwise, the following rules are used.

Highlights for criterion justification fields are keyed on the **status
symbol** (not the justification symbol) so they appear on the correct
criterion row in the view. When Pass 1 already stored an orange entry for
a status symbol, Pass 2 must not overwrite it. Pass 1's `old_value` is an
Integer required by `CriterionStatus.canonical`; replacing it with the old
justification String would corrupt the type and show `?` in the popover.

| Current value | Proposed value | Forced? | Field type | Result | Highlight |
| ------------- | -------------- | ------- | ---------- | ------ | --------- |
| blank         | any            | either  | justification or other | Apply | 🤖 yellow |
| present, equals proposed | - | - | any | Skip (no-op) | none |
| present, differs | differs | no | justification | Skip silently | none |
| present, differs | differs | no | other (name, license…) | Keep user value | ≠ blue |
| present, differs | differs | yes | any | Overwrite | ⚠️  orange |

## Controller Method Map

### `edit` action

```
edit
├── run_first_edit_automation_if_needed    (Chief; first visit or ?reanalyze)
└── apply_query_string_automation          (URL params; every visit)
```

### `run_first_edit_automation_if_needed`

Runs only when `level_already_saved?` is false or `?reanalyze` is in the URL.
Reloads the full project record (cross-section detective inputs need columns
from other sections), then:

1. `capture_original_values`: snapshots every status and justification field
   plus the non-criteria automatable fields, keyed by symbol.
2. `chief.propose_changes(needed_fields: fields_for_current_section)`:
   runs all applicable detectives.
3. `classify_chief_proposals(proposals, original_values, track_automated: true)`:
   classifies proposals into `@automated_fields`, `@overridden_fields`,
   `@divergent_fields`. Does **not** modify `@project`.
4. `chief.apply_changes(@project, proposals)`: applies **all** proposals
   (forced and non-forced) to `@project`, because the user is about to
   review them on the edit page.

Network or detective errors are caught; all three highlight hashes are reset
to empty so the page still renders.

### `apply_query_string_automation`

Runs on **every** initial
edit-page visit (after `run_first_edit_automation_if_needed`).
Results merge into any existing highlight state via `||=`, so URL params
can extend or override the initial Chief results.

1. `fields_for_current_section`: returns the `Set<Symbol>` of fields valid
   for the current section from `FIELDS_BY_SECTION`.
2. `compute_forced_fields(valid_fields)`: parses the `overrides` URL param
   (comma-separated glob patterns) and returns a frozen `Set<Symbol>` of
   forced fields. Forcing a `_status` field also forces its paired
   `_justification` when it is present in params. Inputs exceeding length
   limits are treated as "no overrides" to prevent DoS.
3. `snapshot_original_values(valid_fields)`: reads the current project
   values for every key present in params that is also a valid field.
4. `build_url_proposals(valid_fields, forced_fields)`: normalizes URL
   params into the shared proposals format. Status values are parsed via
   `parse_status_value` (`CriterionStatus.parse`); unparsable values and `?`
   are discarded here (pre-screening). Non-status values are stripped of
   leading/trailing whitespace. The `proposed_justification` for a status
   proposal is read from `params['CRITERION_justification']`.
5. `classify_status_pass(proposals, original_values, track_automated: true)`:
   populates `@automated_fields`, `@overridden_fields`, `@divergent_fields`
   for `_status` fields. Returns a `Set<Symbol>` of divergent status fields
   for use by Pass 2.
6. `classify_non_status_pass(proposals, original_values, divergent, track_automated: true)`:
   populates the same three hashes for justification and non-criteria fields.
7. `apply_url_proposals(proposals, original_values, divergent)`: applies
   the proposals to `@project`. Divergent fields (and their paired
   justifications) are not applied.

### `update` action

The `update` action applies the user's form submission first, then calls
`run_save_automation(changed_fields, user_set_values, track_automated:)`.

`track_automated` is `true` when the user clicked Save and Continue, or
when the repo URL changed (requiring a full re-analysis); `false` on Save
and Exit.

### `run_save_automation`

1. `chief.propose_changes(needed_fields:, changed_fields:, only_consider_overrides:)`:
   passes `only_consider_overrides: !track_automated` to skip non-forceable
   detectives on Save and Exit.
2. `filter_to_current_section(proposed_changes)`: restricts proposals to
   fields visible on the current section's form (detectives can propose
   cross-section fields that should not be applied here).
3. Initializes `@overridden_fields`, `@automated_fields`, `@divergent_fields`
   to `{}`.
4. `classify_chief_proposals(current_section_changes, user_set_values, track_automated:)`:
   classifies into the three hashes. `user_set_values` is the snapshot of
   what the user just typed (before Chief ran), used as the "original" for
   comparison.
5. `chief.apply_changes(@project, changes_to_apply)`: applies only forced
   proposals when `track_automated` is false; applies all proposals when
   true.

### `classify_chief_proposals`

Thin wrapper: calls `classify_status_pass` then `classify_non_status_pass`
with the appropriate `track_automated` flag. The Chief proposals hash
already uses the same `{ value:, forced:, explanation: }` shape, so no
normalization step is needed.

## Files to Read

| File | Purpose |
|---|---|
| `app/controllers/projects_controller.rb` | All controller methods above |
| `app/lib/chief.rb` | Orchestration, confidence→forced translation, `apply_changes` |
| `app/lib/detective.rb` | Base class: `INPUTS`, `OUTPUTS`, `OVERRIDABLE_OUTPUTS`, `analyze` |
| `app/lib/*_detective.rb` | Individual detectives (GitHub, repo JSON, mapping, etc.) |
| `lib/criterion_status.rb` | `UNKNOWN/UNMET/NA/MET` integers, `parse`, `canonical` |
| `app/helpers/projects_helper.rb` | `override_detail_block`, `divergent_detail_block`, `non_criteria_automation_display` |
| `app/views/projects/_status_chooser.html.erb` | Per-criterion highlight rendering |
| `app/views/projects/_form_basics.html.erb` | Non-criteria field highlight rendering |
| `app/assets/stylesheets/_projects.scss` | `.highlight-automated/overridden/divergent`, detail block styles |
