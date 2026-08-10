# Automation Proposals

External automation tools can propose field changes to a project's
badge entry by encoding proposals as query parameters in a project
edit URL. When a user (or tool) visits such a URL, and the user is
authorized to make changes to the project entry, the edit form
displays the proposed values with visual highlighting so the
(authorized) user can review and accept or modify them before saving.
The user can also simply choose to *not* save them, their choice.

The *user* is always the final arbiter about data from external
automation proposals. Users can easily see
the proposals in context with other answers, and decide what to do.

This is not the *only* way an automated tool can retrieve or edit project
badge entry data:

* Tools can GET and PUT project data using REST. Just use resource
  <https://bestpractices.dev/projects/NUMBER.json>. We encourage this approach
  for *getting* data, but no longer encourage using it for changes.
  This mechanism requires authentication and authorization
  (which is an extra step) and writing with REST
  doesn't let the user use the UI to review the changes.
  That said, see [api](./api) if you want more information.
* Our automation systems examine the project repo for information.
  This includes looking for a [`.bestpractices.json`](./bestpractices-json.md)
  file which stores
  proposed answers; you can even get the JSON results from another repository
  and use that as a starting point. We also examine the
  [`security-insights.yml`](https://security-insights.openssf.org/) file,
  if present, to determine proposed answers.
  However, these approaches require that you put information into the
  project repository.

The "automation proposals" interface
described here provides a user-friendly way for applications to
propose arbitrary changes where:

1. the authorized human has a chance to review and approve those changes,
2. tools don't have to add code for authentication, and
3. information does not need to *first* be put into the project repository.

## TL;DR

You can provide proposed values using this URL format:
(line breaks added for clarity, don't include them in the real URL):

```text
https://www.bestpractices.dev/projects?as=edit&url=ENCODED_URL&
KEY=VALUE&KEY=VALUE&...
```

The URL is the project's repository or home page URL.
The KEY is the criterion (lowercased, change `.` and `-` to `_`,
append `_status` for its status and
`_justification` for its justification).
The VALUE is what its value
should be (status can be '?', 'Unmet', 'N/A', or 'Met').

Here's an example which proposes setting the status and justification
for two baseline criteria:

```text
https://www.bestpractices.dev/projects?as=edit&
url=https%3A%2F%2Fgithub.com%2Fcurl%2Fcurl&
osps_ac_01_01_status=Met&
osps_ac_01_01_justification=GitHub+org+enforces+2FA&
osps_ac_03_01_status=Met&
osps_ac_03_01_justification=Branch+protection+enabled+on+main
```

When a user clicks on this, the system will switch to the user's preferred
locale and let the user select the section (format) to use.
On selection, relevant changes are highlighted
which the user can accept, modify, or ignore.

If you know the form you want to redirect to (e.g., `baseline-1`), you
can directly express that using the key `section=`
(section defaults to `choose`).
To use a specific natural language, add a slash and its code
after the domain name (e.g., `/en` for English).

If you know the project number, you can use the form

```text
https://www.bestpractices.dev/projects/NUMBER/choose/edit?
KEY=VALUE&KEY=VALUE&...
```

Proposals normally only set answers when there is no current value
(they are "unforced").
To force proposals, add [`overrides=`](#the-overrides-parameter)
followed by a comma-separated sequence of globs to force. E.g.,
`overrides=osps_ac_*,osps_vm_02_01_status`.

There are many more options. Below are the details.
For brevity, from now on we'll omit the prefix
`https://www.bestpractices.dev`.

### Visual highlight results

The outcome for each field depends on the field's current value and
whether the new proposal *overrides* the current value
(aka is *forced*).
Proposals are unforced unless they match the comma-separated globs in the
[`overrides` parameter](#the-overrides-parameter):

| Current value | Proposed value | Result | Visual indicator |
|---------------|---------------|--------|-----------------|
| Any | Same as current | No change | None |
| Blank/Unknown (`?`) | Different | Proposal applied | 🤖 Yellow highlight |
| Real value | Different, Unforced | Not applied | ≠ Blue highlight, click to see what automation found |
| Real value | Different, Forced | Proposal applied; old value replaced | ⚠️ Orange highlight, click to see previous value |

A `_status` that is unchanged, but has a different justification,
is considered "same as current".
There are an infinite number of ways to justify a claim and to express that
justification. Generally people simply want to know if something is true;
one good justification is enough.

## URL Format when Project ID is known

```text
(/:locale)/projects/:id/:section/edit?KEY=VALUE&KEY=VALUE&...
```

Where:

- **`:locale`** is the locale code (e.g., `en`, `fr`).
  The locale is optional and defaults to the user's preferred locale
  if we support it (else English).
- **`:id`** is the numeric project ID.
- **`:section`** is the badge level being edited.
  For the Metal badge series this is `passing`, `silver`, or `gold`.
  For the Baseline badge series this is `baseline-1`, `baseline-2`,
  or `baseline-3`.
  Use `choose` to let the user choose the section (level) to edit.
- **`KEY=VALUE`** pairs are `&`-separated query parameters, where
  `KEY` is a field name and `VALUE` is the proposed new value.
  Values must be URL-encoded (spaces as `+` or `%20`, etc.).
  The field must be present in the given section, or it's ignored, to
  ensure that humans will have a chance to review the change.

### Examples

Propose a new project description for project 42 when viewing
its passing level section:

```text
/en/projects/42/passing/edit?description=A+secure+widget+library
```

Propose that the `floss_license` criterion is Met in `passing`:

```text
/en/projects/42/passing/edit?floss_license_status=Met
```

Propose multiple fields at once:

```text
/en/projects/42/passing/edit?name=MyProject&floss_license_status=Met&floss_license_justification=MIT+license+in+LICENSE+file
```

Propose a Baseline criterion status:

```text
/en/projects/42/baseline-1/edit?osps_ac_01_01_status=Met&osps_ac_01_01_justification=MFA+enforced+via+GitHub+org+settings
```

## Valid Fields

Each section has a specific set of valid field names.
Proposals for fields that do not belong to the section being edited
are silently ignored.

### Non-criteria Fields (All Sections)

These fields may be proposed in any section:

| Field | Description |
|-------|-------------|
| `name` | Human-readable project name |
| `description` | Short project description |
| `license` | Project license (e.g., `MIT`, `Apache-2.0`) |
| `implementation_languages` | Comma-separated list of languages |

### Criteria Fields

Every criterion has two automatable fields:

- **`CRITERION_status`** - the criterion's status
  (`?`, `N/A`, `Unmet`, or `Met`; see [Status Values](#status-values) below).
- **`CRITERION_justification`** - free-text justification for the status
  (in URL-encoded UTF-8 format).

The criterion name (`CRITERION`) depends on the badge series.

#### Metal Series Criterion Names

Metal series criteria (`passing`, `silver`, `gold`) use short descriptive names.
Examples from the passing level:

| Criterion Name | Description |
|----------------|-------------|
| `description_good` | Project description is clear |
| `floss_license` | Released under a FLOSS license |
| `floss_license_osi` | License is OSI-approved |
| `repo_public` | Public version-controlled repository |
| `contribution` | Contribution process explained |
| `maintained` | Project is actively maintained |
| `version_unique` | Each release has a unique version |
| `static_analysis` | At least one static analysis tool is used |
| `dynamic_analysis` | At least one dynamic analysis tool is used |

The full list of criteria for each level is defined in
`criteria/criteria.yml`.

#### Baseline (OSPS) Criterion Names

Baseline criteria follow a structured naming convention derived from
the [OpenSSF OSPS Baseline](https://baseline.openssf.org/):

```text
osps_CATEGORY_NUMBER_SECTION
```

Where:

- **`CATEGORY`** is a two-letter category code (see table below).
- **`NUMBER`** is a two-digit requirement number (e.g., `01`, `02`).
- **`SECTION`** is a two-digit sub-section number (e.g., `01`, `02`).

OSPS field names are always *lowercase* and never use
dashes or periods (both are replaced with `_`).

**OSPS category codes:**

| Code | Category |
|------|----------|
| `ac` | Access Control |
| `br` | Build and Release |
| `do` | Documentation |
| `gv` | Governance |
| `le` | Legal |
| `qa` | Quality |
| `sa` | Security Assessment |
| `vm` | Vulnerability Management |

Each OSPS criterion also has an `original_id` in the format
`OSPS-XX-NN.SS` (e.g., `OSPS-AC-01.01`).
Some readbacks and UI labels display baseline status fields using the
original OSPS ID with `_status`, for example `OSPS-AC-01.01_status`.
Proposal URLs, `.bestpractices.json` files, and internal field names use
the lowercase underscore form, for example `osps_ac_01_01_status`.

**Examples:**

| Field Name | Original ID | Description |
|------------|-------------|-------------|
| `osps_ac_01_01` | OSPS-AC-01.01 | Enforce MFA for repository access |
| `osps_ac_03_01` | OSPS-AC-03.01 | Prevent direct commits to primary branch |
| `osps_br_01_01` | OSPS-BR-01.01 | Use a build system |
| `osps_le_02_01` | OSPS-LE-02.01 | License clearly defined |
| `osps_do_01_01` | OSPS-DO-01.01 | Provide project documentation |

## Status Values

Status fields (`*_status`) accept the following string values
(case-insensitive, whitespace is stripped):

| Value | Meaning |
|-------|---------|
| `?` | Status is unknown (default) |
| `N/A` | Criterion is not applicable |
| `Unmet` | Criterion is not met |
| `Met` | Criterion is met |

Blank or invalid status values are silently rejected;
the field keeps its previous value.

**Note:** Not all criteria allow `N/A`.
The `na_allowed` attribute in the criteria YAML files controls whether
a criterion accepts `N/A` as a valid status.

### Status Value Semantics: Query Strings vs JSON

There's an important distinction between query string proposals and
JSON file automation from a project's `.bestpractices.json` file
(see [.bestpractices.json](bestpractices-json.md)):

**Query String Proposals (this mechanism):**

- `?` means **"explicitly reset this field to unknown"**
- Users can clear a previously-set status by passing `?` in the URL
- Example: `...edit?contribution_status=?` resets the status to unknown
- This is intentional - AIs and humans can use URLs to reset fields

**JSON File Automation (`.bestpractices.json`):**

- `?` or `"unknown"` means **"I don't know the answer"**
- These values are **ignored entirely** - they provide no automation information
- Example: `{"contribution_status": "?"}` is skipped, existing value unchanged
- This lets you safely reuse JSON files containing placeholder `?` values

**Why the difference?** Query string proposals represent explicit human actions
through a URL. JSON files represent automated tool outputs where `?` means
"no information available" rather than "please clear this field."

This design allows projects to copy `.bestpractices.json` files from templates
or other projects that are filled with `?` placeholders without accidentally
clearing their existing answers. Otherwise, any answer a user *did* give
would be cleared the next time the `.bestpractices.json` file was read.

## Justification Values

Justification fields (`*_justification`) accept any text string.
Blank values are accepted and result in an empty justification.
Values are stripped of leading and trailing whitespace.
In some cases *satisfying* a criteria requires that a URL be included
in the justification (this URL should point to evidence supporting the
justification).

## Security and Validation

Automation proposals are validated in several ways:

1. **Field name validation**: Only fields in the pre-computed
   `FIELDS_BY_SECTION` set for the current section are accepted.
   Unknown field names, fields from other sections, and
   non-field query parameters (e.g., `locale`, `utf8`) are silently
   ignored.

2. **Status value validation**: Status fields must contain a
   recognized status string.
   Invalid values are silently rejected.

3. **Section isolation**: Proposals for criteria belonging to a
   different section than the one being edited are ignored.
   For example, proposing `osps_ac_01_01_status=Met` while editing
   the `passing` section will have no effect.
   This is necessary because it ensures that the human user will have
   a chance to review the proposal in its proper context.

4. **No direct writes**: Automation proposal values are loaded into the
   in-memory project object for display in the edit form.
   They are **not** saved to the database until the user explicitly
   submits the form. The user always has the opportunity to review,
   modify, or reject proposals before saving.

## Authentication Flow

The user must be logged in and authorized to edit the project.
When an unauthenticated user visits an edit URL with automation
proposals:

1. The full URL (including all query parameters) is stored in the
   user's session.
2. The user is redirected to the login page.
3. After successful login (via GitHub OAuth or local account), the
   user is redirected back to the original edit URL with all
   automation proposals intact.
4. If the logged-in user is not authorized to edit the project,
   they are redirected to the project's show page with a flash
   message.

## Default Behaviour: Proposals Only Fill Blank Fields

By default, automation proposals only modify fields whose current value
is unknown (`?`). If a field already has a non-unknown value, the
proposal is **not applied**; instead the system shows a divergent
indicator (see below) so the user can see what automation found.

This is intentional: it prevents automation from silently overwriting
answers a human has already reviewed.

## The `overrides` Parameter

To allow automation to **force** changes to fields that already have
values, append an `overrides` query parameter containing
comma-separated glob patterns. For example:

```text
/en/projects/42/passing/edit?contribution_status=Met&overrides=contribution_status
```

Use `%2C` to represent the comma separator if you use more than one glob.
Glob syntax follows Ruby's `File.fnmatch` rules.
`*` matches any sequence of characters (but not `/`).
Use `*` to force all matching fields:

```text
/en/projects/42/passing/edit?contribution_status=Met&overrides=*
```

**Justification–Status Coupling rule:** Justifications and their associated
status values are linked. When a status field is
forced via `overrides`, its paired justification field is also forced
automatically (if provided). If a status field is
*divergent* (not applied) because it is not forced,
then its paired justification is also blocked, because
a justification written for the wrong status answer would mislead the user.

**Safety limits:** the `overrides` value is ignored if it is longer
than 10,000 characters or contains more than 1,000 comma-separated
patterns. We don't expect this to cause a problem for non-attackers.

## The `reanalyze` Parameter

Normally, first-edit automation (Chief analysis) only runs once per
badge level. Passing `reanalyze=1` forces it to run again even if
the level has already been saved:

```text
/en/projects/42/passing/edit?reanalyze=1
```

## Details on Visual Highlighting

When automation proposals and internal Chief automation (which
loads files from the repository) potentially modify
fields, the edit form highlights them to draw the user's attention.
We've summarized them earlier; here's more detail that also shows
how we handle internal automations:

- **Yellow highlight** (`.highlight-automated`) with 🤖 robot: A field that was
  previously unknown (`?`) and has been filled in with a proposed
  value. This is a helpful suggestion.
- **Orange highlight** (`.highlight-overridden`) with ⚠️  caution: A field that
  already had a non-unknown value and has been forcibly changed,
  either via the `overrides` URL parameter (external automation) or
  by internal Chief automation when it has high confidence (≥ 4 on
  a 1–5 scale). The previous value and justification are shown in
  an expandable disclosure so the user can compare.
  This needs attention and review.
  The user can click on ⚠️  caution to see what the old value was.
  Note: when Chief forces a field on every save, a user cannot
  persistently store a conflicting value. Chief re-applies its
  determination each time the form is saved if the criterion
  objectively cannot be met with high confidence
  (e.g., a repo with no CONTRIBUTING.md
  cannot have `contribution` marked "Met").
- **Blue highlight** with `≠` not-equal: A field that already had a
  non-unknown value and the automation proposed a *different* answer,
  but the proposal was **not applied** (no matching `overrides`
  pattern). The user can click the `≠` icon to see what the automation
  proposed. The user's existing answer remains unchanged.

When a user selects "Save and exit", internal automations
(managed by the "chief") run, but only forced (orange) changes are applied and
shown; non-forced fill-in proposals are silently skipped so unreviewed
changes never land in the database.

When a user selects "Save and continue", all internal automations are re-run.
Proposal types (yellow, orange, ≠) are tracked and displayed.
External URL automation proposals are not re-applied on subsequent
saves, because their URL query parameters go away (their job is done).

## Interaction with First-Edit Automation

When a user visits the edit page for a badge level they have not
previously saved, the system runs first-edit automation:

1. Internal "Chief" analysis proposes values for criteria it can
   determine automatically (e.g., by analyzing the project's
   repository URL).
2. URL-based automation proposals are then applied **on top of**
   the Chief analysis results.
3. All changes (from both Chief and URL proposals) are highlighted.

URL proposals take precedence over Chief proposals when both modify
the same field.

## Building Automation Proposal URLs

External tools that want to propose changes should:

1. Know the project's numeric ID (or its URL) and the section to edit.
   If you don't know the project's numeric ID, use its URL.
   Section "choose" lets users choose.
2. Construct the URL with the appropriate field names and values.
3. URL-encode all values (especially spaces, ampersands, and
   special characters).
4. Use field names exactly as they appear in the criteria YAML files,
   with `_status` or `_justification` appended.

### Example: Tool Proposing License Detection Results

```text
/en/projects/42/passing/edit?floss_license_status=Met&floss_license_justification=Detected+MIT+license+in+LICENSE+file&license=MIT
```

### Example: Tool Proposing OSPS Baseline Results

```text
/en/projects/42/baseline-1/edit?osps_ac_01_01_status=Met&osps_ac_01_01_justification=GitHub+org+enforces+2FA&osps_ac_03_01_status=Met&osps_ac_03_01_justification=Branch+protection+enabled+on+main
```

## Looking Up Projects by URL (`as=edit`)

If an external tool knows a project's repository URL or home page URL
but not its numeric ID, it can construct an automation proposal URL
without knowing the numeric ID:

```text
/en/projects?as=edit&url=ENCODED_URL&KEY=VALUE&KEY=VALUE&...
```

The application looks up the project by URL and redirects to its edit
page with the automation proposal parameters forwarded.
If the section is omitted (the common case for tools), the user lands
on a section-chooser page and picks which section to review the
proposals in.

For example:

```text
/en/projects?as=edit&floss_license_status=Met&url=https%3A%2F%2Fgithub.com%2FORG%2FPROJECT
```

See [api.md](api.md) for full details on the `as=edit` lookup,
including the `section` parameter and redirect behavior.

## Related Documentation

- `docs/api.md` - General documentation on the API, including the
  `as=edit` URL lookup for automation proposals.
- `criteria/criteria.yml` - Metal series criteria definitions.
- `criteria/baseline_criteria.yml` - Baseline (OSPS) criteria
  definitions.
