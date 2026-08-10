# Automation Classification Decision Matrix — Refactor Notes

This document captures the analysis of the two automation classification
paths in `app/controllers/projects_controller.rb` and the plan for merging
them into a shared implementation.

## The Full Automation Flow

### `edit` action (line ~617)

1. `run_first_edit_automation_if_needed` (line ~1627) — runs only when the
   section has not been saved before (or `?reanalyze` is in the URL):
   - Calls `chief.propose_changes` to build a proposals hash.
   - Calls `classify_chief_proposals(proposals, original_values,
     track_automated: true)` — populates `@automated_fields`,
     `@overridden_fields`, `@divergent_fields`.
   - Calls `chief.apply_changes(@project, proposals)` — applies **all**
     proposals (blank fills + forced overrides) to `@project`.

2. `apply_query_string_automation` (line ~1778) — always runs, even on
   revisits:
   - Reads URL params and classifies them **inline** (classify + apply in
     one pass), merging into the instance variables via `||=`.
   - Runs **after** Chief so URL params can override Chief results.

### `update` action (line ~698)

1. User's form changes are applied to `@project`.
2. `run_save_automation(changed_fields, user_set_values,
   track_automated: bool)` (line ~2223):
   - Calls `chief.propose_changes`.
   - Calls `classify_chief_proposals(current_section_changes,
     user_set_values, track_automated: track_automated)`.
   - Calls `chief.apply_changes(@project, changes_to_apply)` where
     `changes_to_apply` is all proposals when `track_automated: true`,
     or only forced proposals when `track_automated: false`.

### When `track_automated` is true vs. false

`track_automated: true` — save-and-continue, first edit, or repo URL changed:

- All three highlight categories (Yellow, ≠, Orange) are recorded.
- All proposals (blank fills + forced overrides) are applied.

`track_automated: false` — save-and-exit:

- Only Orange (`@overridden_fields`) is recorded; Yellow and ≠ suppressed.
- Only **forced** proposals are applied; blank fills are silently skipped.

`apply_query_string_automation` behaves as `track_automated: true` always
(it only runs during `edit`, where the user is actively reviewing).

## The Decision Matrix

Both classification paths implement the same matrix:

### Status fields (`_status`)

| Condition | Result | Highlight |
|-----------|--------|-----------|
| Proposed unparsable or `?` (UNKNOWN) | Skip entirely | none |
| Current blank/UNKNOWN | Apply | Yellow (`@automated_fields`) |
| Current real, proposed == current | Skip (no-op) | none |
| Current real, proposed differs, NOT forced | Keep user value | ≠ (`@divergent_fields`) |
| Current real, proposed differs, forced | Overwrite | Orange (`@overridden_fields`) |

### Justification fields (`_justification`)

**Coupling rule**: if the paired `_status` field is divergent (kept), skip
the justification entirely — even if forced — because writing a justification
for the wrong status actively misleads the user.

| Condition | Result | Highlight |
|-----------|--------|-----------|
| Paired status is divergent | Skip entirely | none |
| Current blank | Apply | Yellow |
| Current present, proposed == current | Skip (no-op) | none |
| Current present, proposed differs, NOT forced | Skip silently | none |
| Current present, proposed differs, forced | Overwrite | Orange |

### Non-criteria fields (`name`, `description`, `license`, etc.)

| Condition | Result | Highlight |
|-----------|--------|-----------|
| Current blank | Apply | Yellow |
| Current present, proposed == current | Skip (no-op) | none |
| Current present, proposed differs, NOT forced | Keep user value | ≠ (`proposed_value:`) |
| Current present, proposed differs, forced | Overwrite | Orange |

### Highlight key conventions

- `@automated_fields` and `@overridden_fields` for justification fields are
  keyed on the **status symbol** so they appear on the correct criterion row.
- `@divergent_fields` for status fields is keyed on the status symbol.
- `@divergent_fields` for non-criteria fields is keyed on the field itself.

## The Two Implementations

### `classify_chief_proposals` (line ~2066, ~144 lines)

Implements the two-pass decision matrix inline. Input:
`{ field_sym => { value:, forced:, explanation: } }`.

Does **not** apply values — the caller handles application separately via
`chief.apply_changes`. The `explanation` field serves as both the orange
`explanation:` entry and the divergent status `proposed_justification:`.

Has 5 `rubocop:disable` directives because it is too long and complex.

### `apply_status_proposals` + `apply_non_status_proposals` (line ~1804, ~167 lines combined)

Implements the same two-pass matrix but:

- Iterates `params` instead of a proposals hash.
- Determines `forced` via `forced_fields.include?(field_sym)` (glob patterns
  from `overrides` URL param) instead of `data[:forced]`.
- **Applies values inline** — classify and apply are mixed in a single pass.
- Explanation is always `nil` (URL params carry no reason text by themselves).
- For divergent status fields, `proposed_justification` is read from the
  corresponding `params['foo_justification']` URL param.
- Has post-apply no-op guards: after applying a value, if Rails validation
  clamps it back to the original the highlight entry is discarded.

## Differences at a Glance

| Aspect | URL (`apply_*`) | Chief (`classify_chief_proposals`) |
|--------|-----------------|-----------------------------------|
| Input source | `params` (iterable) | proposals hash (iterable) |
| Forced lookup | `forced_fields.include?` (from `overrides` glob) | `data[:forced]` |
| Explanation | read from `NAME_justification` param | `data[:explanation]` |
| Apply values | inline, mixed with classify | separate `chief.apply_changes` call |
| Post-apply no-op guard | yes | n/a (apply is separate) |
| `track_automated` | always true | parameterized |

Both input sources are iterable; that is not a real difference.
The `forced` mechanism differs in source but is the same concept and can be
unified by placing a `forced: bool` in the normalized proposals format.

## Proposed Refactor

### Unified "explanation" convention

For URL params, treat `NAME_justification` (or `BASENAME_justification` for
`_status` fields) as the explanation for any proposal named NAME. This
matches Chief's per-proposal `explanation` field:

- `foo_status=Met` → explanation comes from `params['foo_justification']`
- `name=acme` → explanation comes from `params['name_justification']` (if present)

The same `_justification` param that is a separate apply-able proposal for
criteria fields also doubles as the explanation for the status proposal.

### Normalized proposals format

Build URL params into the same format Chief already produces:

```ruby
{
  field_sym => {
    value:,                 # Integer for _status, String for others
    forced:,               # bool — from forced_fields or data[:forced]
    explanation:,          # nil or String
    proposed_justification # String? — for _status divergent entries only
                           # URL: params['foo_justification'].presence
                           # Chief: data[:explanation].presence
  }
}
```

Add `build_url_proposals(valid_fields, forced_fields)` to produce this from
`params` (with pre-screening: reject unparsable status values and UNKNOWN).

### Shared classify methods

Extract two pure-classify methods that operate on the normalized format and
have no side effects beyond populating `@automated_fields`,
`@overridden_fields`, `@divergent_fields`:

```ruby
classify_status_pass(proposals, original_values, track_automated:)
  # → returns divergent_status_fields Set

classify_non_status_pass(proposals, original_values,
                         divergent_status_fields, track_automated:)
```

### Refactored callers

```ruby
def apply_query_string_automation
  valid_fields    = fields_for_current_section
  return if valid_fields.nil?
  forced_fields   = compute_forced_fields(valid_fields)
  original_values = snapshot_original_values(valid_fields)
  @automated_fields  ||= {}
  @overridden_fields ||= {}
  @divergent_fields  ||= {}
  proposals = build_url_proposals(valid_fields, forced_fields)
  divergent = classify_status_pass(proposals, original_values,
                                   track_automated: true)
  classify_non_status_pass(proposals, original_values, divergent,
                           track_automated: true)
  apply_url_proposals(proposals)   # separate apply step; replaces inline apply
end

def classify_chief_proposals(proposals, original_values, track_automated:)
  divergent = classify_status_pass(proposals, original_values,
                                   track_automated: track_automated)
  classify_non_status_pass(proposals, original_values, divergent,
                           track_automated: track_automated)
end
```

`classify_chief_proposals` shrinks to 5 lines and loses all 5 rubocop
disables. The decision matrix lives in one place.

### Estimated savings

| Code | Current | After |
|------|---------|-------|
| `apply_status_proposals` | ~72 lines | → becomes `classify_status_pass` (~55 lines, no apply) |
| `apply_non_status_proposals` | ~70 lines | → becomes `classify_non_status_pass` (~60 lines, no apply) |
| `classify_chief_proposals` | ~144 lines | → ~5 lines |
| `build_url_proposals` | (new) | ~25 lines |
| `apply_url_proposals` | (new) | ~20 lines |
| **Total** | **~286 lines** | **~165 lines** |

Net: **~120 lines saved**, all rubocop disables on `classify_chief_proposals`
removed.

### Caveat: post-apply no-op guard

URL automation currently discards a highlight entry when Rails validation
clamps the applied value back to the original. After the refactor, classify
runs before apply, so this guard is lost.

Effect: a spurious yellow/orange highlight may appear in the rare case where
validation clamps a value. No data is corrupted. If this needs to be
preserved, add a post-apply sweep that removes entries from
`@automated_fields` / `@overridden_fields` where the final project value
equals `original_values[field]`.

## Tests

Tests for both methods are in `test/controllers/projects_controller_test.rb`:

- `classify_chief_proposals` tests: around line 2335
- `apply_query_string_automation` tests: around line 2774

The shared classify methods should pass all existing tests unchanged, since
the observable behavior (which highlights are produced) is identical.
