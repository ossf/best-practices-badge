# Simplified Edit URLs: Removing Internal Automation URL Params

## Background: The Current Approach and Its Problems

When the user saves an edit form, the controller runs Chief automation, which may:

- **Fill blank fields** (yellow highlight, `@automated_fields`)
- **Propose a different value for a field already set** (divergent indicator, `@divergent_fields`)
- **Force-override a field** at confidence ≥ 4 (orange highlight, `@overridden_fields`)

After saving, the controller needs to show the edit form again with those highlights in two
cases: a Chief force-override (user must review it), and "Save and Continue" (user is still
editing). Rails' Post-Redirect-Get (PRG) pattern means the controller redirects to a GET
request for the edit page — but instance variables are destroyed on redirect.

The current workaround serializes the automation state into URL parameters:

```text
/en/projects/42/passing/edit?
  overridden_fields_list=contribution_status&
  ovr__contribution_status=Met&
  ovr__contribution_status_justification=Has+CONTRIBUTING.md&
  ovr__contribution_status_explanation=No+CONTRIBUTING.md+found&
  automated_fields_list=license_status&
  divergent_fields_list=maintained_status&
  div__maintained_status=Unmet&
  div__maintained_status_justification=No+recent+commits
```

The `edit` action then deserializes those parameters back into `@overridden_fields`,
`@automated_fields`, and `@divergent_fields` for the view.

**Problems:**

1. **Accidental external interface.** The `ovr__*`, `div__*`, and `*_fields_list` params
   are internal implementation details. Anything that bookmarks or logs such a URL, or
   any external tool that starts depending on them, creates a maintenance burden.
2. **Internal data in URLs.** Old justification text (user's previous answers), automation
   explanations, and field names appear in server logs, browser history, and Referer
   headers. This is both ugly and a minor privacy concern.
3. **Substantial code complexity.** The round-trip requires six methods (builders and
   parsers for each of the three field hashes) plus the reconstruction calls in the `edit`
   action, totalling roughly 200 lines that exist solely to work around the redirect.
4. **Inconsistency.** First-edit automation renders directly (no redirect) with instance
   variables populated. The save path does the same work but then discards the state and
   reconstructs it from URL params.

---

## Options Considered

| Option | Description | Key problem |
|--------|-------------|-------------|
| **Keep as-is** | Current URL params | Accidental interface, ugly, ~200 lines of round-trip code |
| **Flash storage** | Store state in `flash[]` | Hard 4 KB CookieStore limit; flash is user-global (cross-tab contamination if editing multiple projects) |
| **Rails.cache + UUID token** | Store server-side, pass UUID | Adds infrastructure dependency; overkill |
| **Render not redirect** | Skip PRG where edit form is shown | Chosen; see below |

Flash was considered carefully: the app uses `CookieStore` (see
`config/initializers/session_store.rb`), which has a hard 4 KB limit for the entire
encrypted session cookie. Old justification text (user-written, potentially hundreds of
characters per field) could easily exceed this. URLs in practice tolerate far more data.
Flash is also user-global — two browser tabs editing different projects simultaneously
could overwrite each other's automation metadata. URL params are naturally request-scoped
and avoid both problems.

---

## Chosen Approach: Render Instead of Redirect, PATCH to the `/edit` URL

### Core idea

Instead of redirecting to a GET after a save that requires the edit form, **render `:edit`
directly** from the `update` action. Instance variables are still in scope; no
serialization or deserialization is needed.

The one remaining redirect (clean "Save and Exit" with no overrides) goes to the show page,
which is a natural GET — PRG is preserved exactly where it matters.

### The URL problem, solved

If the form submits `PATCH` to the resource URL (e.g., `/en/projects/42/passing`) and the
server renders edit HTML, the browser's address bar stays at the resource URL, not the
`/edit` URL. This is confusing.

**Fix:** add a route that also accepts `PATCH` at the `/edit` URL, and change the form
action to submit there. When the server renders the edit template in response, the URL in
the address bar is already `/edit` — exactly where the user expects it.

### PRG: when it matters and when it does not

- **Clean "Save and Exit" (no override):** Redirects to the show page — a clean GET.
  Refreshing the show page is safe. PRG is fully honoured here.
- **Save with Chief override:** Renders edit. The save has already been committed. If the
  user refreshes, the browser shows "Confirm Form Resubmission?" — honest and expected
  (they are on an edit form). Re-submitting is idempotent: Chief re-runs and produces the
  same override. This is identical behaviour to validation failures, which already render
  `:edit` from the `update` action today with no complaints.
- **Save and Continue:** Same reasoning. User is editing; re-submit is idempotent.
- **Chief failure:** Renders edit with a warning flash. Same as above.

---

## Code Changes Required

### 1. `config/routes.rb`: add PATCH route for the edit URL

After the existing `GET projects/:id/:section/edit` line (~line 174), add:

```ruby
# Edit with section (before show to avoid conflicts)
# GET (/:locale)/projects/:id/:section/edit
# Use PRIMARY_SECTION_REGEX to reject obsolete sections in edit URLs
get 'projects/:id/:section/edit' => 'projects#edit',
    constraints: CONSTRAINTS_ID_PRIMARY_SECTION,
    as: :edit_project_section

# Accept PATCH/PUT at the edit URL so forms can submit here and the
# address bar stays at /edit when the server renders edit directly.
match 'projects/:id/:section/edit' => 'projects#update',
      via: %i[put patch],
      constraints: CONSTRAINTS_ID_PRIMARY_SECTION
```

The existing `update_project` route (`match 'projects/:id(/:section)'`) stays for JSON
API clients and any other callers that use the canonical REST URL.

### 2. Views: change form action to the `/edit` URL

Four form partials currently submit to `update_project_path`:

- `app/views/projects/_form_0.html.erb` line 25
- `app/views/projects/_form_1.html.erb` line 25
- `app/views/projects/_form_2.html.erb` line 25
- `app/views/projects/_form_baseline.html.erb` line 32

In each, change:

```erb
<%# BEFORE %>
<%= bootstrap_form_for project, url: update_project_path(project, section: criteria_level) do |f| %>

<%# AFTER %>
<%= bootstrap_form_for project, url: edit_project_section_path(project, criteria_level) do |f| %>
```

`bootstrap_form_for` automatically uses `PATCH` for a persisted record, so no `method:`
override is needed.

`_form_permissions.html.erb` (line 75) uses a separate permissions update path — leave it
unchanged.

### 3. `app/controllers/projects_controller.rb`: simplify `perform_html_redirect_after_save`

Current (~lines 2625–2651): four branches, three of which redirect to the edit page with
URL params.

Replace with:

```ruby
# Render or redirect after a successful save based on automation state.
# Only the clean "save and exit" path redirects (to the show page, a clean GET).
# All paths that need to show the edit form render it directly so that
# @overridden_fields / @divergent_fields / @automated_fields are available
# without URL-param serialisation.
def perform_html_redirect_after_save(section)
  if @chief_failed
    flash.now[:warning] = t('projects.edit.automation.analysis_failed',
                            count: @chief_failed_fields&.size || 0,
                            fields: @chief_failed_fields&.join(', ') || '')
    render :edit
  elsif @overridden_fields&.any?
    flash.now[:warning] =
      t('projects.edit.automation.chief_overrode', count: @overridden_fields.size) +
      "\n" + format_override_details
    Rails.logger.info(
      "Chief override: project=#{@project.id} user=#{current_user&.id} " \
      "fields=#{@overridden_fields.keys.join(',')}"
    )
    render :edit
  elsif params[:continue]
    flash.now[:info] = t('projects.edit.successfully_updated')
    render :edit
  else
    # Clean save-and-exit: the only remaining redirect.
    redirect_to project_section_path(@project, section, locale: params[:locale]),
                success: t('projects.edit.successfully_updated')
  end
end
```

The three render branches use `flash.now` (not `flash`). The difference matters: `flash`
persists to the **next** request; `flash.now` is visible only in the **current** render.
For a rendered response, `flash` would defer the message to whatever page the user visits
next — the user would never see it on the form where it belongs.

### 4. `app/controllers/projects_controller.rb`: fix `flash` in `successful_update`

This change is required because of a subtle Rails execution order that is easy to get
wrong.

**The execution order in `respond_to`:** Rails' `respond_to` collects format blocks first
and executes the matched block only after the entire `respond_to` body has run. The actual
sequence in the `update` action is:

1. `update_additional_rights` runs
2. `@project.save` runs
3. `successful_update(format, ...)` body runs in full:
   - `format.html { perform_html_redirect_after_save(section) }` — **registered, not yet called**
   - `format.json { ... }` — registered, not yet called
   - Badge level change is computed
   - **`flash[:danger]` or `flash[:success]` is set here** (if badge level changed)
   - Emails sent
4. CDN purge jobs run
5. `respond_to` block ends — Rails now calls the matched format's block
6. **`perform_html_redirect_after_save(section)` actually executes** — render or redirect

The badge-level flash calls at step 3 fire **before** `perform_html_redirect_after_save`
at step 6. This means the render-vs-redirect decision is not yet made when those flash
calls run. However, the conditions that determine that decision
(`@chief_failed`, `@overridden_fields`, `params[:continue]`) are all fully known at step 3.

**Why this matters:** `flash[:danger]`/`flash[:success]` in `successful_update` currently
always uses plain `flash`. When the response is a redirect (the current behaviour), `flash`
persists to the redirected-to page — correct. When the response is a render (the new
behaviour for override/continue/failure cases), `flash` persists to the *next* request
after the user leaves the edit form — the badge-level message is silently deferred and
likely never seen.

**The fix:** use `flash.now` when the action will render, `flash` when it will redirect.
The render condition mirrors the first three branches of `perform_html_redirect_after_save`:

```ruby
# In successful_update, replace:
#   flash[:danger] = t('projects.edit.lost_badge')
#   flash[:success] = t('projects.edit.congrats_new', ...)
# With:

badge_flash = (@chief_failed || @overridden_fields&.any? || params[:continue]) ?
              flash.now : flash
if lost_level
  badge_flash[:danger] = t('projects.edit.lost_badge')
else
  badge_flash[:success] = t('projects.edit.congrats_new', new_badge_level: new_badge_level)
end
```

Using `flash.now` in the redirect case would silently drop the message (there is no
rendered response to a 302 redirect, so `flash.now` content is never displayed). Using
`flash` in the render case defers the message to the wrong page. Both mistakes cause
silently lost notifications; they fail in opposite directions.

### 5. `app/controllers/projects_controller.rb`: delete `handle_overridden_fields_redirect`

The method at ~lines 2587–2619 is now inlined into `perform_html_redirect_after_save`
above. Delete it entirely.

### 6. `app/controllers/projects_controller.rb`: delete six serialization/deserialization methods

All of the following exist solely to carry automation state through redirects.
Delete them:

| Method | Approx. lines | Purpose (now redundant) |
|--------|--------------|------------------------|
| `divergent_url_params` | 2150–2165 | Serialize `@divergent_fields` to URL params |
| `parse_divergent_fields_list` | 2178–2213 | Deserialize `div__*` params → `@divergent_fields` |
| `overridden_url_params` | 2230–2249 | Serialize `@overridden_fields` to URL params |
| `parse_overridden_fields_list` | 2263–2303 | Deserialize `ovr__*` params → `@overridden_fields` |
| `merge_field_lists` | 2109–2116 | Merge `automated_fields_list` param into `@automated_fields` |
| `parse_and_validate_field_list` | 2122–2139 | Parse comma-separated field name list from URL param |

Verify with `grep` that none of these are called from anywhere else before deleting.

### 7. `app/controllers/projects_controller.rb`: remove reconstruction calls from `edit`

The `edit` action currently reconstructs automation state from redirect params
(~lines 644–652):

```ruby
# REMOVE these lines and the comment block above them:
@overridden_fields =
  parse_overridden_fields_list(params[:overridden_fields_list], @overridden_fields)
@automated_fields =
  merge_field_lists(params[:automated_fields_list], @automated_fields)
@divergent_fields =
  parse_divergent_fields_list(params[:divergent_fields_list], @divergent_fields)
```

These are no longer needed: automation state comes from in-memory instance variables when
the `update` action renders `:edit` directly, and from `run_first_edit_automation_if_needed`
and `apply_query_string_automation` on a direct `edit` GET.

### 8. `app/controllers/projects_controller.rb`: remove `url_anchor` and the `first_overridden` anchor

Two auto-scroll features are lost by removing redirects; both should be deleted cleanly:

**`url_anchor`** (~lines 1591–1608): scrolls the browser to the active section on
save-and-continue. Currently appended to the redirect URL:

```ruby
redirect_to edit_project_section_path(...) + url_anchor
```

With render-not-redirect there is no redirect URL. Delete the `url_anchor` method and
its one call site in `perform_html_redirect_after_save`.

**`first_overridden` anchor** in `handle_overridden_fields_redirect` (~line 2612):
scrolls to the first overridden field after a Chief override save:

```ruby
anchor: first_overridden,
```

This was part of the redirect URL construction that is being replaced by a direct render.
The variable `first_overridden` and its use disappear with `handle_overridden_fields_redirect`.

Both are minor UX conveniences. Either can be restored later with a small `<script>` in
the edit view that calls `location.hash = '...'` when an anchor target is present.

### 9. `app/controllers/projects_controller.rb`: update the class-level comment block

The comment block at lines 55–83 explicitly documents `parse_overridden_fields_list`,
`automated_fields_list`, `overridden_fields_list`, `ovr__field`, `ovr__field_explanation`,
etc. After the methods are deleted, these references are wrong.

Replace lines 55–83 with a shorter block describing the current mechanism:

```ruby
# When editing a specific project there are two instance variables to track
# automation highlights: @automated_fields and @overridden_fields.
# These instance variables track which project fields were changed by
# automation (Chief or query-string proposals) so the edit form can
# highlight them for the user.
#
# Both are Hash{Symbol => Hash} keyed by field symbol
# (e.g. :contribution_status):
# - @automated_fields (yellow highlight): fields that were unknown/blank
#   and then got filled in by automation.
#   Values: { new_value:, explanation: }
# - @overridden_fields (orange highlight): fields that had a real user
#   value and were forcibly changed by Chief.
#   Values: { old_value:, new_value:, old_justification:, explanation: }
#
# They are populated by classify_chief_proposals (first-edit and save-time
# Chief) and apply_query_string_automation (URL proposals).
# Consumed by the edit view (via projects_helper automated_field_set /
# overridden_field_set), format_override_details, and
# build_automation_metadata (JSON API).
```

### 10. `docs/automation-proposals.md`: update Visual Highlighting section

The Visual Highlighting section (~line 398 onwards) currently ends with:

> External URL automation proposals are not re-applied on subsequent
> saves; only their visual indicators (orange/≠) are preserved across
> the redirect.

After this change there is no redirect in those paths. Update to:

> External URL automation proposals are not re-applied on subsequent
> saves. Their visual indicators (orange/≠) remain visible because
> Chief re-evaluates the same data and produces the same highlights.

Also remove the sentence "Chief automation runs on every save. With 'Save and continue',
all proposal types (yellow, orange, ≠) are tracked and displayed. With 'Save and exit',
only forced (orange) changes are applied and shown; ..." — this is accurate but
references the implementation mechanism. Update to describe the user-visible behaviour
only, without implying redirects.

---

## `flash` vs `flash.now`: Complete Reference

Every flash call touched by this change, with justification:

| Call site | Old | New | Justification |
|-----------|-----|-----|---------------|
| `perform_html_redirect_after_save` — `@chief_failed` | `flash[:warning]` | `flash.now[:warning]` | Becomes render; `flash` would defer warning to next page |
| `handle_overridden_fields_redirect` (inlined into above) | `flash[:warning]` | `flash.now[:warning]` | Becomes render; same reason |
| `perform_html_redirect_after_save` — `params[:continue]` | `flash[:info]` | `flash.now[:info]` | Becomes render; `flash` would defer "Saved" to next page |
| `perform_html_redirect_after_save` — clean exit | `success:` on `redirect_to` | unchanged | Still redirects; `flash` correct |
| `successful_update` — badge change `flash[:danger]` | `flash[:danger]` | `flash.now[:danger]` when rendering, `flash[:danger]` when redirecting | Runs before render/redirect decision; condition required (see section 4) |
| `successful_update` — badge change `flash[:success]` | `flash[:success]` | `flash.now[:success]` when rendering, `flash[:success]` when redirecting | Same reason |

---

## Test Changes Required

### Tests to delete (testing now-deleted methods)

| Test name | Approx. line |
|-----------|-------------|
| `divergent_url_params encodes proposed_status as canonical string` | ~2653 |
| `parse_divergent_fields_list decodes _status field as Integer` | ~2673 |
| `parse_divergent_fields_list merges url and existing fields` | ~2691 |
| `overridden_url_params encodes old_value as canonical string` | ~2708 |
| `overridden_url_params encodes non-status field as raw string` | ~2729 |
| `parse_overridden_fields_list decodes _status field as Integer` | ~2756 |
| `parse_overridden_fields_list returns raw string for non-status field` | ~2776 |
| `parse_overridden_fields_list merges url and existing fields` | ~2803 |
| `ovr__ params restore old_value metadata in overridden popover` | ~2822 |
| `automated_fields_list query param highlights fields with robot icon` | ~635 |
| `overridden_fields_list query param highlights overridden fields` | ~658 |

### Tests to change

**`'update with continue and criteria_level redirects correctly'` (~line 2154)**
Currently asserts `assert_response :redirect` and matches `response.location` against
`%r{/baseline-1/edit(\?[^#]*)?#Quality\z}`. After the change: assert
`assert_response :success` (render), and drop the location/anchor check entirely (the
`url_anchor` scroll feature is removed).

**Any other save-with-Chief-override tests** that currently assert a redirect to the edit
URL should instead assert `assert_response :success` and check that the response body
contains `highlight-overridden`.

**Any other save-and-continue tests** that assert `assert_response :redirect` to the edit
URL should instead assert `assert_response :success`.

### Tests to add

```ruby
test 'PATCH to edit URL is accepted and routes to update action' do
  log_in_as(@project.user)
  patch "/en/projects/#{@project.id}/passing/edit",
        params: { project: { description: 'Updated' } }
  # Not a 404 — new route is registered
  assert_not_equal 404, response.status
end

test 'save with Chief override renders edit directly with orange highlight' do
  log_in_as(@project.user)
  # Set up a criterion where Chief will force an override, e.g. by setting
  # a repo_url that Chief can analyse and contradicts a submitted value.
  patch "/en/projects/#{@project.id}/passing/edit",
        params: { project: { ... } }
  assert_response :success                          # render, not redirect
  assert_nil response.location                      # no redirect URL
  assert_includes response.body, 'highlight-overridden'
end

test 'save-and-continue renders edit directly without redirect' do
  log_in_as(@project.user)
  patch "/en/projects/#{@project.id}/passing/edit",
        params: { project: { description: 'x' }, continue: 'Save and Continue' }
  assert_response :success
end

test 'clean save-and-exit still redirects to show page' do
  log_in_as(@project.user)
  patch "/en/projects/#{@project.id}/passing/edit",
        params: { project: { description: 'x' } }
  assert_redirected_to project_section_path(@project, 'passing')
end

test 'no internal automation params appear in rendered response after save' do
  log_in_as(@project.user)
  patch "/en/projects/#{@project.id}/passing/edit",
        params: { project: { description: 'x' }, continue: 'Save and Continue' }
  assert_no_match(/ovr__/, response.body)
  assert_no_match(/div__/, response.body)
  assert_no_match(/fields_list=/, response.body)
end
```

---

## Implementation Plan

Complete steps in order; run `rubocop` after each Ruby change and `mdl` after each
Markdown change.

1. **Add route** (`config/routes.rb`): add the `match 'projects/:id/:section/edit'`
   PATCH/PUT route directly after the existing `edit` GET route. Run
   `rails routes | grep edit` to verify the new route appears with both GET and PATCH.

2. **Change form actions** (four view partials): change
   `update_project_path(project, section: criteria_level)` →
   `edit_project_section_path(project, criteria_level)` in `_form_0`, `_form_1`,
   `_form_2`, and `_form_baseline`. Verify the rendered `action=` attribute points to
   the `/edit` URL.

3. **Replace `perform_html_redirect_after_save`** with the version in section 3 above.
   This is the central change; three redirect paths become `render :edit` with
   `flash.now`.

4. **Fix `successful_update` flash calls**: apply the conditional `badge_flash`
   assignment from section 4 above. This must be done in the same commit as step 3 so
   the two changes are always consistent.

5. **Delete `handle_overridden_fields_redirect`** (now fully inlined into step 3).

6. **Remove reconstruction calls in `edit`** (~lines 644–652): the three
   `parse_overridden_fields_list` / `merge_field_lists` / `parse_divergent_fields_list`
   calls and the comment block above them.

7. **Delete the six serialization/deserialization methods** (listed in section 6 above).
   After each deletion, run `grep -n <method_name>` across the codebase to confirm no
   remaining call sites.

8. **Delete `url_anchor`** and its one call site in `perform_html_redirect_after_save`.
   The `first_overridden` variable and `anchor:` option are removed as part of deleting
   `handle_overridden_fields_redirect` in step 5.

9. **Update the class-level comment block** (lines 55–83) with the shorter version from
   section 9 above.

10. **Update `docs/automation-proposals.md`**: revise the Visual Highlighting section
    as described in section 10 above. Run `mdl docs/automation-proposals.md`.

11. **Update tests**: delete the tests listed above; update the `'update with continue
    and criteria_level redirects correctly'` test (~line 2154) and any other redirect
    assertions that now become renders; add the five new tests.

12. **Run the full lint and test suite**: `rake default`. Fix any failures.
    Confirm coverage — deleted methods should no longer show as uncovered lines.

13. **Verify in browser** (dev server): save with a Chief override and confirm the URL
    stays at `/edit`, the orange highlight and popover show the correct previous value,
    and the flash warning is visible on the form. Confirm clean save-and-exit lands on
    the show page. Confirm save-and-continue stays at `/edit` with highlights.

---

## Implementation Notes (recorded after implementation)

Steps 1–13 were completed. 100% statement coverage maintained. Net reduction: 233 lines
from the controller (2,694 → 2,424 lines, −8.7%).

### Post-implementation review findings

**Correct and verified:**

- `flash.now` is used in all three render branches of `perform_html_redirect_after_save`;
  `flash` (persistent) is used only in the clean-redirect branch. The layout
  `flash.each` includes `flash.now` entries in the current-request render. ✓
- `@overridden_fields`, `@divergent_fields`, `@automated_fields` are consumed
  **directly from instance variables** in `projects_helper.rb` (see
  `overridden_field_set`, `divergent_field_set`, `automated_field_set`). The view
  helpers do **not** depend on URL params (`ovr__*`, `div__*`). Full metadata
  (old values, explanations, proposed values) is available. ✓
- URL stays at `/edit` after any render (save-and-continue, Chief override,
  Chief failure). Clean save-and-exit still redirects to the show page. ✓
- The `will_render` condition in `successful_update` exactly mirrors the branch
  logic in `perform_html_redirect_after_save`, so `badge_flash` (flash.now vs
  flash) is chosen correctly before Rails' deferred execution invokes the html
  format block. ✓
- XSS: user-provided justification text stored in `@overridden_fields` and
  `@divergent_fields` flows through Rails' `t()` interpolation (which
  HTML-escapes values in non-`_html` keys) and then into `content_tag` (which
  treats already-html_safe strings correctly). Flash messages use
  `<%= message %>` which auto-escapes. No new XSS surface. ✓
- URL automation proposals are **not re-applied** on save-and-continue.
  The PATCH request carries no query params; `apply_query_string_automation`
  is only called from the `edit` GET action, not from `update`/`run_save_automation`.
  After save, highlights reflect only Chief's re-analysis of the current project
  state. ✓

**Remaining gap: security tests for `apply_query_string_automation`:**

The deleted `parse_and_validate_field_list` had explicit security tests for
SQL injection, XSS, path traversal, and cross-section field isolation.
The equivalent protection is now provided by `apply_query_string_automation`'s
`FIELDS_BY_SECTION` whitelist, but we lack explicit tests documenting it. Tests
to add to `apply_query_string_automation`'s test block:

```ruby
test 'apply_query_string_automation: SQL injection attempt in field name is ignored' do
  controller = setup_automation_controller
  original_status = @project.contribution_status
  run_automation(controller,
                 "'; DROP TABLE projects; --" => 'Met',
                 'contribution_status' => 'Unmet')
  # Malicious key ignored; valid key still processed
  refute_nil controller.instance_variable_get(:@divergent_fields)
  # Project contribution_status was changed by the valid key
  # (it was already set so goes divergent, not applied)
  automated = controller.instance_variable_get(:@automated_fields)
  assert_not automated.key?(:'\''; DROP TABLE projects; --'.to_sym)
end

test 'apply_query_string_automation: cross-section field is ignored' do
  # osps_ac_01_01_status is a baseline-1 criterion, not in passing
  controller = setup_automation_controller   # sets @criteria_level = 'passing'
  @project.contribution_status = CriterionStatus::UNKNOWN
  run_automation(controller,
                 'osps_ac_01_01_status' => 'Met',   # baseline-1 field, wrong section
                 'contribution_status' => 'Met')      # passing field, correct section
  automated = controller.instance_variable_get(:@automated_fields)
  assert automated.key?(:contribution_status), 'valid field must be processed'
  assert_not automated.key?(:osps_ac_01_01_status), 'cross-section field must be ignored'
end

test 'apply_query_string_automation: unknown field name is ignored' do
  controller = setup_automation_controller
  run_automation(controller, 'not_a_real_field' => 'Met',
                             'contribution_status' => 'Met')
  automated = controller.instance_variable_get(:@automated_fields)
  assert_not automated.key?(:not_a_real_field)
end
```
