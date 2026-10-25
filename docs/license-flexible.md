# Flexible license file detection

This document records a mostly AI analysis behind making `license_location`
detection more flexible, and a draft plan for implementing it.

I asked an AI to develop this on a computer while traveling, but
I now am switching to my "normal" machine. It's easier for me to
commit this early draft as a commit, and then work from there.

## Goal

Accept more of the license file naming conventions that real projects
use, without weakening our ability to reject bogus badge entries, and
without loosening the OSPS Baseline criteria, which name their
acceptable filenames explicitly.

## Why: issue #3055

A maintainer of `time-rs/time` reported that we changed their
`license_location` answer from Met to Unmet, saying "No license location
file found". That repository has two top-level license files:

```text
LICENSE-Apache   10174 bytes
LICENSE-MIT       1057 bytes
```

Dual licensing under "MIT OR Apache-2.0" is standard practice in the
Rust ecosystem, and `LICENSE-<name>` is how that convention is spelled.

Our pattern in `app/lib/repo_files_examine_detective.rb` is:

```ruby
/\A([A-Za-z0-9]+-)?(license|copying)(\.md|\.txt)?\Z/i
```

Note the asymmetry: a *prefix* matches (`MIT-LICENSE`), a *suffix* does
not (`LICENSE-MIT`). Nothing matched, and because the root listing came
back non-empty the code used `unmet_confidence = 5`. Confidence 5 is at
or above `Chief::CONFIDENCE_OVERRIDE` (4), so it overrode the user's
answer instead of merely filling a blank.

### This is the second misfire of the same rule

`git log -S unmet_confidence` shows forced-Unmet arrived in "Phase7
automation (#2688)" and has now produced two user-visible bugs:

1. Issue #2818: a GitHub 404 was read as "no license file" and overrode
   a user's Met. Fixed in commit `febacacb` by making `@top_level` nil
   on 404 and using confidence 1 in that case.
2. Issue #3055: `LICENSE-MIT` is read as "no license file" and overrides
   a user's Met.

Both are one error: treating absence of evidence as evidence of absence.
A hand-maintained filename allow-list cannot justify confidence 5,
because an allow-list miss is indistinguishable from a real absence.
Fixing only the regex leaves the mechanism armed for a third instance,
so the forcing rule is what we change.

## Threat model

We get genuinely bogus badge entries, including submissions (possibly
automated) that claim Met on everything for a repository with nothing in
it. We want those to fail without manual review.

What this plan does **not** do, and should not be described as doing: it
is not a general lie detector. Anyone who controls a repository can
create files in it, including empty files, or a real OSS license file
with no actual project behind it. The empty-repository check counters
only the "truly bogus" case, i.e., a repository with no files at all.
That case is common enough to be worth countering cheaply, and the check
is cheap, but it stops nothing more than that.

## The three data sources

We have never examined license file *contents* in our own code, and this
plan does not start. All three signals are metadata or claims.

1. **The root file listing from the forge.** Names, types, and sizes
   from one `get_info('/')` call. This is an observation, not a claim, so
   a submitter cannot fake it by typing. It cannot tell an OSS license
   from a proprietary one, and matching is an allow-list, so it has false
   negatives.
2. **The forge's own license verdict.** GitHub runs the `licensee` gem
   over the repository's root files and reports an SPDX identifier
   (`:license` today, at confidence 3, skipping `NOASSERTION`). The
   provenance is trustworthy and it does reflect file contents, but
   `licensee` is imperfect: it returns `NOASSERTION` for licenses it
   cannot match, and for `time-rs/time` it reports only `Apache-2.0`,
   missing the MIT half of the dual license.
3. **The submitter's SPDX license expression.** The `license` column,
   which the user can edit. A cooperative submitter is often *more*
   accurate than `licensee`, e.g., they will write "MIT OR Apache-2.0"
   where GitHub reports one of the two. A hostile submitter will write
   whatever gets them a badge.

## The rule

A submitter's claim can only strengthen a conclusion the forge's listing
already supports. It can never soften a forced Unmet, and it never
substitutes for a file existing.

That asymmetry uses the right property of each source. The listing
supplies existence, which a submitter cannot fake by typing. The claim
supplies license identity, which the submitter often knows better than
`licensee` does. Neither source decides anything alone.

Two consequences worth stating separately:

* Only the forge's verdict may lower a forced Unmet to a non-forcing
  value. A claim may not.
* We force Unmet only where absence is established rather than merely
  unobserved.

## Decision table for `license_location`

`forge_oss` means the forge's verdict parses as an OSI-approved SPDX
expression. `claim_oss` means the same for the `license` column, whatever
its origin. "Alt name" means `ALT_LICENSE_NAME` matched a non-trivial
file.

| Root listing | Identity | Result | Conf | Rationale |
|---|---|---|---|---|
| empty, repo readable | ignored | Unmet | 5 | empty repo; no file can carry a license |
| empty, not readable | ignored | Unmet | 1 | nonexistent, private, or transient; we know nothing |
| conforming name found | n/a | Met | 3 | existing behavior |
| alt name found | `forge_oss` or `claim_oss` | Met | 3 | existence observed, identity claimed |
| alt name found | neither | Unmet | 2 | file exists, identity unknown; do not force |
| nothing license-shaped | `forge_oss` | Unmet | 2 | `licensee` saw a name we do not know |
| nothing license-shaped | `claim_oss` only | Unmet | 5 | claim contradicted by the listing |
| nothing license-shaped | neither | Unmet | 5 | both sources agree nothing is there |

Rows 1 and 7 are what counter bogus entries. Row 7 is the only place a
claim is actively disbelieved, and it is disbelieved by the listing, not
by us.

Confidence 2 and 3 are below `CONFIDENCE_OVERRIDE`, so those rows fill a
blank answer but never rewrite a human one.

### Baseline criteria stay strict

OSPS-LE-03.01 names its acceptable filenames: a `LICENSE` file, a
`COPYING` file, a `LICENSES/` directory, or a `LICENSE/` directory, with
an optional extension. `LICENSE-MIT` is not on that list, so an alt name
must not propose Met for `osps_le_03_01` or `osps_le_03_02`.

This works without touching any YAML. `set_baseline_license_status` runs
*before* the Met upgrade, so it sees the strict result. Its Unmet
inherits confidence 2, which beats what `MetalToBaselineDetective` would
infer from the relaxed metal answer:

* `license_location` -> `osps_le_03_01` is `confidence_met: 3`, scaled
  for an auto-detected source to `3 * 3 / 5 = 1.8`.
* `license_location` -> `osps_le_03_02` is `confidence_met: 2`, scaled
  to `3 * 2 / 5 = 1.2`.

`Chief#merge_changeset` overrides only on strictly greater confidence, so
2 holds against both.

### Lowering confidence does not make us silent

`app/controllers/projects_controller.rb` (see the comment at line 1725)
implements three states, all rendered today:

| State | Trigger | UI |
|---|---|---|
| `@automated_fields` | blank or Unknown field filled | yellow |
| `@overridden_fields` | real value replaced by a forced proposal | orange warning |
| `@divergent_fields` | real value kept, proposal not forced | not-equals icon |

`app/views/projects/_status_chooser.html.erb` renders the divergent case,
and `config/locales/en.yml` already has "Automation instead determined
%{status}." So dropping 5 to 2 converts "we rewrote your answer" into "we
disagree with your answer, here is why". No new UI or translation work.

## Verified facts

These were checked rather than assumed. Re-check before relying on them.

### The 409 comment is wrong

`app/lib/github_content_access.rb` line 51 says "empty repos return 409
Conflict, not 404". That is true of the *commits* endpoint, not the
*contents* endpoint. A confirmed empty repository:

```text
digitalxc1/sdgsdfew   size=0  /commits -> 409 "Git Repository is empty"
                              /contents/ -> 404
```

GitHub's REST documentation for "Get repository content" does not list
409 at all.

This matters because `febacacb` justified making 404 non-forcing with
that premise. Since an empty repository returns 404 from the contents
API, it currently lands in the "we know nothing" branch at confidence 1,
and nothing is forced. Bogus empty repositories therefore pass every
file-presence criterion right now. Closing that is a security fix
independent of #3055.

### Distinguishing "empty" from "inaccessible" is free

`GithubBasicDetective` has no `rescue`, and `client.repository fullname`
raises `Octokit::NotFound` for a repository we cannot read. So the
detective completes if and only if the repository is readable:

| Repo state | `/repos/{o}/{r}` | `/contents/` | `GithubBasicDetective` |
|---|---|---|---|
| normal | 200 | 200 | succeeds |
| empty | 200 | 404 | succeeds |
| nonexistent or private | 404 | 404 | raises, yields nothing |

So "the forge confirmed this repository is readable" is already
available, with no extra API call. Combined with an empty listing it
means the repository is empty.

Note that `GithubBasicDetective` sets `repo_public_status`,
`repo_track_status`, `repo_distributed_status`, `contribution_status`,
and `discussion_status` *before* that API call, so those outputs do not
imply readability and cannot be reused as the signal. An explicit
intermediate is needed.

### Octokit status mapping

```text
404 -> Octokit::NotFound       (the only class get_info rescues)
409 -> Octokit::Conflict
403 -> Octokit::Forbidden
451 -> Octokit::UnavailableForLegalReasons
500 -> Octokit::InternalServerError
```

Everything except 404 raises out of `get_info`, and
`Chief#propose_one_change` swallows it in production, discarding the
detective's entire output. In development and test `@intercept_exception`
is `NoSuchException`, so these raise loudly, which is intended.

### The SPDX expression evaluator

`floss_license_detective.rb` carries `# TODO: Handle AND, OR, WITH`, and
nothing in the application parses a compound expression. This is not just
incomplete, it is wrong today: for "MIT OR Apache-2.0", `osi_license?`
fails and the string does not start with `(`, so `analyze` proposes
`floss_license_osi_status` Unmet at confidence 1. Only parenthesized
compounds get the no-opinion `{}` treatment.

SPDX semantics: "A OR B" lets the recipient choose, so one approved term
is enough. "A AND B" imposes both, so every term must be approved.
Splitting on OR before AND gives SPDX precedence (AND binds tighter), so
paren-free compounds work without special handling. `WITH` binds
tightest and cannot contain an operator, so stripping it from a term is
safe.

Tested and passing, including the case that killed an earlier draft that
used `all?` for both operators:

```text
MIT                                      true
Proprietary                              false
MIT OR Apache-2.0                        true
GPL OR MIT               (paren-free)    true
(GPL-2.0-only OR Proprietary)            true
GPL-2.0-only AND Proprietary             false
(MIT OR Apache-2.0) AND CC0-1.0          true
(MIT OR Apache-2.0) AND Proprietary      false
Apache-2.0 WITH LLVM-exception           true
Proprietary WITH Nonsense                false
GPL-3.0-or-later+                        true
((MIT OR Nope) AND (CC0-1.0 OR Nope))    true
NOASSERTION                              false
```

### Filename patterns

Tested against the strict pattern (with `licen[sc]e` added) and the new
alt pattern:

| Name | Strict | Alt |
|---|---|---|
| `LICENSE`, `LICENSE.md`, `COPYING` | yes | no |
| `LICENCE`, `licence` | yes | no |
| `MIT-LICENSE`, `MIT-LICENSE.txt` | yes | no |
| `LICENSE-MIT`, `LICENSE-Apache` | no | yes |
| `LICENSE-Apache-2.0`, `LICENSE-GPL-3.0.txt` | no | yes |
| `LICENSE_MIT`, `COPYING-MIT` | no | yes |
| `license-manager.rb`, `copying-files.sh` | no | no |
| `LICENSE.spdx`, `LICENSE.rst`, `licenses.go` | no | no |
| `licensing-policy.md`, `README.md` | no | no |
| `UNLICENSE`, `COPYING.LESSER` | no | no |

The alt pattern allows a dot only before a digit, which is how version
numbers survive while source files are excluded.

## Code changes

Four files, about 50 added lines. Every new method is small and pure, and
no logic is duplicated across call sites.

### `app/lib/github_content_access.rb`

Fix the wrong 409 comment on `get_info`, and add `Octokit::Conflict` to
the existing rescue clause:

```ruby
-  rescue Octokit::NotFound
+  rescue Octokit::NotFound, Octokit::Conflict
```

One line, no new branch. Reason: today a 409 from any forge path raises
and discards the whole detective's output, which is the exact failure
mode that lets a bogus repository through. We already got burned once by
assuming a status code, so both codes should land in the same state.

### `app/lib/github_basic_detective.rb` (+6)

Publish two intermediate values right after `client.repository` succeeds.
They are named `_from_forge`, not `_from_github`, so a future
`GitlabBasicDetective` can satisfy the same contract.

* `:repo_accessible_from_forge`, true at confidence 5.
* `:license_spdx_from_forge`, the forge's SPDX identifier, alongside the
  existing `:license`. The separate name is what lets a consumer tell the
  forge's verdict from the submitter's claim, which is the whole basis of
  the rule above.

Both are intermediates, not project columns, so `Chief::ALLOWED_FIELDS`
keeps them out of the database. `:repo_files` already works this way, so
the `compute_current` path for non-column symbols is already exercised.

### `app/lib/floss_license_detective.rb` (+14)

* `self.normalize_license(s)`, which strips and drops a trailing `+`
  (allowing later versions is always fine). Two callers: `analyze`, which
  needs the normalized string for its I18n message, and
  `osi_expression?`, which needs it per term. Extracting it removes a
  duplication rather than adding a layer.
* `self.osi_expression?(expr)`, about 12 lines, recursive. Returns false
  for a blank argument so no caller needs a guard. Reduces the innermost
  parenthesized group to a sentinel and reparses, splits on OR then AND,
  and strips `WITH`.
* Decline to propose when the repository is confirmed empty. An empty
  repository has no file that could express a license, so the three
  forced Met proposals (`floss_license_osi_status`,
  `floss_license_status`, `osps_le_02_01_status`) are not justified.
  Needs a `:repo_empty_from_forge` input, published by
  `RepoFilesExamineDetective`. No cycle: `GithubBasicDetective` ->
  `RepoFilesExamineDetective` -> `FlossLicenseDetective`.

The new input makes `filter_needed_detectives` pull in
`RepoFilesExamineDetective` whenever a floss license criterion is needed.
That costs nothing in practice: the metal license criteria live in the
same section as `license_location`, and the baseline ones live with
`osps_le_03_01`, so that detective is already running in both cases.

Wiring `osi_expression?` into `analyze` flips those three criteria to
forced Met at confidence 5 for compound-licensed projects. That is the
correct answer and a real behavior change, so it needs its own tests.

### `app/lib/repo_files_examine_detective.rb` (+29)

Three edits to existing lines:

```ruby
-      /\A([A-Za-z0-9]+-)?(license|copying)(\.md|\.txt)?\Z/i
+      /\A([A-Za-z0-9]+-)?(licen[sc]e|copying)(\.md|\.txt)?\Z/i

-      /\ALICENSES\Z/,
+      /\ALICENSES?\Z/,          # OSPS-LE-03.01 allows LICENSE/ too

-        unmet_result(result_description, confidence: confidence.fetch(:unmet, 1))
+        unmet_result(result_description,
+                     confidence: confidence.fetch(:unmet, unmet_confidence))
```

The first adds the British spelling, which `licensee` accepts and real
projects use. The second closes a stated OSPS-LE-03.01 conformance gap.
The third is what gives the empty-repository forcing to
`contribution_status`, `release_notes_status`, and
`osps_do_02_01_status` with no edits at their call sites.

One constant:

```ruby
  # Conventional license filenames outside the OSPS-LE-03.* list, e.g.
  # the Rust ecosystem's LICENSE-MIT / LICENSE-Apache pair (issue #3055).
  # A dot is allowed only before a digit, so LICENSE-Apache-2.0 matches
  # while license-manager.rb does not.
  ALT_LICENSE_NAME =
    /\A(licen[sc]e|copying)[-_]([\w+-]|\.\d)+(\.md|\.txt)?\Z/i
```

One confidence method, which serves every criterion in the file. The long
comment currently sitting inside `check_license_files` moves here, where
it belongs, rather than being duplicated:

```ruby
  # Confidence for an UNMET result when the file we looked for is absent.
  # +floor+ is what the criterion uses when we did scan a non-empty root
  # listing and found no match: license_location has always forced at 5,
  # and the other criteria stay weak at 1.
  #
  # An empty listing is a different situation and means one of two
  # things.  If the forge confirmed the repository is readable then it
  # really is empty, so none of these files can exist: force, because an
  # empty repository must not be able to claim a badge.  Without that
  # confirmation the repository may be nonexistent, private, or the call
  # may have failed transiently, so we learned nothing and must not
  # override a human answer (issue #2818).
  def unmet_confidence(floor = 1)
    return @repo_readable ? 5 : 1 if @top_level.blank?

    floor
  end
```

`override_results_if_dir` is generalized rather than copied, because the
alt-name upgrade is the same operation on a different filesystem object:

```ruby
  # Replace +status+ with a met_result built from +fso+, but only when we
  # have not already found something.  Both callers treat their fso as a
  # fallback for when the primary name pattern matched nothing: a
  # LICENSES/ or LICENSE/ directory, and an alternately-named file.
  def override_results_if(status, fso, result_description)
    return if fso.blank? ||
              @results[status][:value] != CriterionStatus::UNMET

    @results[status] = met_result(result_description, fso['html_url'])
  end
```

Then `check_license_files` keeps its zero-argument signature, reading the
three new values from instance variables as the file already does for
`@top_level` and `@results`:

```ruby
  def check_license_files
    alt = files_named(ALT_LICENSE_NAME, NONTRIVIAL_MIN_SIZE).first
    forge_oss = FlossLicenseDetective.osi_expression?(@forge_license)
    determine_results(
      :license_location_status,
      /\A([A-Za-z0-9]+-)?(licen[sc]e|copying)(\.md|\.txt)?\Z/i,
      NONTRIVIAL_MIN_SIZE, 'license location',
      confidence: { unmet: alt || forge_oss ? 2 : unmet_confidence(5) }
    )
    override_results_if(:license_location_status,
                        directory_named(/\ALICENSES?\Z/),
                        'licenses directory')
    set_baseline_license_status
    # The filename supplies existence, which a submitter cannot fake by
    # typing; either identity source supplies the license, and a
    # submitter's expression is often more accurate than the forge's
    # scanner.  A claim alone never reaches here, so it can neither
    # invent a file nor soften the forced UNMET set above.
    return unless forge_oss ||
                  FlossLicenseDetective.osi_expression?(@claim_license)

    override_results_if(:license_location_status, alt, 'license location')
  end
```

Note which boolean goes where. The `confidence:` expression sees
`forge_oss` only, because a claim must not soften a forced Unmet. The
upgrade at the end sees both, because a claim may identify a file the
forge observed.

`analyze` gains three instance variables and publishes the intermediate
`FlossLicenseDetective` needs:

```ruby
    @repo_readable = current[:repo_accessible_from_forge]
    @forge_license = current[:license_spdx_from_forge]
    @claim_license = current[:license]
    ...
    if @top_level.blank? && @repo_readable
      @results[:repo_empty_from_forge] = { value: true, confidence: 5 }
    end
```

`INPUTS` gains the three new symbols; `OUTPUTS` gains
`:repo_empty_from_forge`.

## Tests

* Alt-named license files propose `license_location` Met and leave
  `osps_le_03_01` Unmet.
* An alt-named file with no OSS identity from either source yields Unmet
  below `CONFIDENCE_OVERRIDE`.
* A `claim_oss` with no license-shaped filename still yields forced
  Unmet (row 7; this is the lie-detection case).
* A `forge_oss` with no license-shaped filename yields Unmet at 2, not
  forced (row 6).
* A readable but empty listing forces Unmet on all four file-presence
  criteria, and publishes `:repo_empty_from_forge`.
* A nil listing with no accessibility signal does not force (issue #2818
  regression test, already present and unchanged).
* `contribution_status`, `release_notes_status`, and
  `osps_do_02_01_status` keep confidence 1 for a normal repository that
  simply lacks those files. This pins the bug described under "Review
  notes" below.
* `get_info` returns the same result for 404 and 409.
* `osi_expression?` across the table above, including
  `(GPL-2.0-only OR Proprietary)`.
* `FlossLicenseDetective` proposes nothing when `:repo_empty_from_forge`
  is set.
* `license-manager.rb` and `copying-files.sh` do not match the alt
  pattern.

## Review notes

Decisions made while reviewing this plan, recorded so a restart does not
re-litigate them.

**A bug was caught in an earlier draft.** That draft made the
`determine_results` default unmet confidence a method returning 5
whenever the listing was non-empty. That would have raised
`contribution_status`, `release_notes_status`, and
`osps_do_02_01_status` from confidence 1 to 5 for *every* normal
repository lacking those files, i.e., it would have started
force-overriding human answers on three criteria nobody asked us to
touch. The `floor` parameter exists precisely to keep those at 1 while
still forcing on a confirmed-empty repository. The test listed above
pins this.

**Dropped: adding `UNLICENSE` to the strict pattern.** Nobody reported
it, and the strict pattern feeds OSPS-LE-03.01, whose wording does not
cover a differently named file. Keeping `licen[sc]e` (the British
spelling of the same word) is defensible; adding a different word is not.
`UNLICENSE` therefore matches nothing, which is the status quo.

**Dropped: naming `LICENSE_NAME` and `LICENSE_DIR` as constants.** Each
is used once, so naming them adds lines without adding clarity. They stay
inline and the change is a few characters.

**Dropped: `oss_expression?` as a local wrapper.** Having
`osi_expression?` return false for a blank argument removes the need for
one.

**Dropped: passing the new values as method parameters.** The file
already carries `@top_level` and `@results` as instance variables, so
three more matches its style and avoids changing any method signature.

**Generalized rather than added:** `override_results_if_dir` becomes
`override_results_if`, serving both the directory case and the alt-name
case. This has one intended behavior change: when a conforming `LICENSE`
file *and* a `LICENSES/` directory both exist, the explanation now links
the file rather than the directory, because the guard stops the directory
from overwriting an existing Met. The existing REUSE-style test for
issue #2818 asserts only that the value is Met, so it still passes,
and linking the actual license file is an improvement.

## Deliberately out of scope

* **Reading license file contents ourselves.** A flat list of about 11
  distinctive phrases was prototyped and does work (it matched all 15
  license texts from GitHub's `/licenses` API and both files from #3055,
  with no false positives on a proprietary EULA, a CC-BY-NC-ND notice, a
  README, or a bare copyright line). We are not taking it: it duplicates
  `licensee` badly, adds a maintenance surface that will drift from the
  OSI list, and costs up to 6 extra GitHub API calls per autofill on a
  site that is always busy. Revisit only if trusting the forge's verdict
  proves inadequate.
* **Adding the `licensee` gem.** Accurate, but a new runtime dependency
  on a security-critical site, heavy per-call allocation against our
  "minimize new objects" rule, and transitive dependencies needing
  entries in `docs/dependency_decisions.yml`.
* **Widening accepted extensions** beyond `.md` and `.txt`. OSPS says
  "MAY have an extension" with no restriction, so this is arguably more
  conformant, but it widens the *strict* pattern, where `LICENSE.spdx`
  (machine-readable, not the license text) and `license.rb` are live
  hazards. Separate issue.
* **Treating a forge verdict with no filename match as Met.** `licensee`
  only inspects root files, so a non-`NOASSERTION` identifier is itself
  evidence that a license file sits in a standard root location. That
  would cover every name `licensee` knows and we do not, with no pattern
  list to maintain. Held back because `met_result` needs an `html_url` we
  do not have in that case, so it needs a new locale key and six
  translations, and because the root-only behavior is inferred from
  GitHub's documentation rather than verified.
* **Tightening the `MIT-LICENSE` prefix form.** It is as non-conforming
  to OSPS-LE-03.01 as `LICENSE-MIT` is, but it proposes Met for
  `osps_le_03_01` today, and removing that would regress projects that
  currently pass. Separate conversation about the baseline.
* **`COPYING.LESSER`.** Matches nothing before or after. `licensee`
  special-cases it for LGPL detection. Pre-existing gap.

## Commit sequence

Four commits, so the pieces are revertable independently.

1. Fix the 409 comment in `github_content_access.rb`, add
   `Octokit::Conflict` to the rescue, and test that 404 and 409 produce
   the same result.
2. Close the empty-repository hole: `:repo_accessible_from_forge`,
   `unmet_confidence`, and the `determine_results` default. This is the
   only commit that makes us *more* willing to override a human answer,
   so review it hardest. Everything it forces rests on a positive
   confirmation from the forge rather than on our own allow-list.
3. Fix #3055: `ALT_LICENSE_NAME`, the generalized `override_results_if`,
   `LICENSES?`, the `licen[sc]e` spelling, and confidence 2 for an
   allow-list miss. At this point an alt-named file stops the forced
   Unmet but does not yet propose Met.
4. Autofill: `normalize_license`, `osi_expression?` and its
   `FlossLicenseDetective` wiring, `:license_spdx_from_forge`,
   `:repo_empty_from_forge`, and the gated Met upgrade.

Run `rake default` before each commit. Estimated effort for all four is
about 3.5 hours plus review.
