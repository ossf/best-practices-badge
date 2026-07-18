# Improving our OpenSSF Scorecard results

This document records an analysis of why the
[OpenSSF Scorecard](https://scorecard.dev/) gives the OpenSSF Best
Practices Badge project
([`github.com/ossf/best-practices-badge`](https://scorecard.dev/viewer/?uri=github.com/ossf/best-practices-badge))
lower scores than our actual practices warrant, and what we can do about
it. Some fixes are on our end (this repository, our GitHub settings, or
our badge data); some require changes to Scorecard itself.

It is meant to be worked through incrementally over time, one check at a
time. Record decisions here as they are made so the context is not lost.

## Summary

Scorecard reports an overall score around **6.7 / 10**. Several low
scores do **not** reflect a real weakness; they reflect Scorecard being
unable to *see* something we already do, or matching us against stale
data. The table below is the state at the time of writing (re-check the
live viewer for current numbers).

| Check | Score | Real problem? | Where the fix lives |
|-------|-------|---------------|---------------------|
| CII-Best-Practices | 0 | No — stale URL | Our badge data (project #1) |
| SAST | 1 | Partly | This repo (add CodeQL) + Scorecard |
| Signed-Releases | 0 | Partly | This repo (`sbom.yml`) |
| Branch-Protection | 3 | Partly | GitHub settings + `scorecard.yml` |
| Code-Review | 0 | Partly | GitHub settings + process |
| Pinned-Dependencies | 8 | No — deliberate | Leave as-is (documented) |

## How Scorecard is run against us

Our repository already runs Scorecard on a schedule and publishes
results: see `.github/workflows/scorecard.yml`. It uses
`ossf/scorecard-action` with `publish_results: true`, which is what feeds
the public viewer and the README badge. That workflow is fine; the issues
below are about individual checks, not about how Scorecard is invoked.

## Per-check analysis

### CII-Best-Practices = 0 (stale URL — highest-value, easiest fix)

This is the most important and least intuitive finding: the Best
Practices Badge project scores **0** on the check that asks "does this
project have a Best Practices badge?", even though it is project #1 and
sits at 100% on all levels.

**Root cause.** Scorecard's CII client
(`clients/cii_http_client.go` in `ossf/scorecard`) looks the badge up by
the repository's canonical URL:

```text
https://www.bestpractices.dev/projects.json?url=https://github.com/ossf/best-practices-badge
```

It takes the **first** returned project, or reports "not found" if the
list is empty. Our own lookup is an **exact** match on `repo_url` /
`homepage_url` — see the `url_search` scope in `app/models/project.rb`:

```ruby
where('homepage_url = ? OR repo_url = ?', clean_url, clean_url)
```

Project #1 is still registered under the **old** organization URL,
`https://github.com/coreinfrastructure/best-practices-badge`, from before
the CII → OpenSSF org rename. Scorecard queries the current `ossf` URL,
which matches nothing, so it concludes we have no badge.

Confirmed empirically against staging:

- `?url=.../ossf/best-practices-badge` → **0 matches**
- `?url=.../coreinfrastructure/best-practices-badge` → **1 match**
  (project #1, 100%)

GitHub redirects the old URL to the new one, but Scorecard resolves the
canonical `ossf` URL before querying, so the redirect does not help.

**Fix (our end, not a source change).** Update project #1's `repo_url`
and `homepage_url` to `https://github.com/ossf/best-practices-badge`. This
is a single data-record edit — do it as an admin through the running
application, or from a Rails console, e.g.:

```ruby
# Rails console (production), review before running:
p = Project.find(1)
p.update!(
  repo_url: 'https://github.com/ossf/best-practices-badge',
  homepage_url: 'https://github.com/ossf/best-practices-badge'
)
```

Once the badge data is corrected, Scorecard will pick it up on its next
refresh (production Scorecard reads a periodically-refreshed data
snapshot, not the live site, so allow time for propagation). Expected
result: CII-Best-Practices 0 → 10.

Note the wider lesson: any project that moved orgs and did not update its
badge `repo_url` will hit this same false negative.

### SAST = 1 (Scorecard does not recognize Brakeman)

We run Brakeman as our authoritative static security analyzer on every
pull request and every push to `main` (see `.github/workflows/brakeman.yml`),
and it gates merges. Scorecard still reports SAST ≈ 1 ("N commits out of
30 are checked with a SAST tool").

**Root cause.** Scorecard's SAST check only credits a fixed allowlist of
tools (CodeQL, SonarCloud, Snyk, Qodana, and a few others), detected via
pull-request check-run names and by scanning workflow files for known
actions. **Brakeman is not on that list.** Worse, our `brakeman.yml`
deliberately publishes its SARIF/HTML as a workflow *artifact* rather than
uploading to GitHub code scanning, so there is nothing for Scorecard to
recognize even indirectly. The partial score reflects CodeQL default-setup
runs on some commits, not Brakeman.

**Fixes.**

- *Our end (planned first).* Add an explicit CodeQL workflow
  (`.github/workflows/codeql.yml`) running on push and pull_request to
  `main`. Scorecard rewards a detected CodeQL workflow. This runs
  alongside — does not replace — Brakeman, which remains our authoritative
  gate. All analyzed languages here are interpreted, so the workflow uses
  CodeQL `build-mode: none` (no autobuild step needed).

  *Implemented* (`.github/workflows/codeql.yml`): languages `ruby`,
  `javascript-typescript`, and `actions` (the last scans our own workflow
  files, complementing our workflow hardening); triggers are push + PR to
  `main` only plus a weekly schedule — scoped to `main` for the same
  reason as `brakeman.yml` (a static analyzer only needs to gate `main`,
  since staging/production are only ever advanced from it); actions are
  SHA-pinned (reusing the `github/codeql-action` release already pinned in
  `scorecard.yml`) with harden-runner, `persist-credentials: false`, and
  branch-name validation, matching the other workflows; permissions are the
  least-privilege `security-events: write` + `contents: read`. The default
  query suite is used initially, with `security-extended` noted inline as a
  future opt-in once the baseline is clean.
- *Scorecard side.* Propose adding Brakeman to Scorecard's recognized
  SAST-tool list so the many Rails projects using Brakeman are not
  penalized. (See the Scorecard-improvement list below.)

**CodeQL is free here — no payment.** CodeQL code scanning is free for
**public** repositories on GitHub.com, and this repo is public and
MIT-licensed (CodeQL's terms require an OSI-approved license, which MIT
satisfies). Payment (GitHub Advanced Security, per active committer) only
applies to *private* repositories or analyzing closed-source code. Actions
minutes are also free for public repos, so there is no compute cost.

**Before adding a workflow — resolve the default-setup conflict and check
org policy.** The "N of 30" partial score strongly implies CodeQL
**default setup** is already enabled on this repo (Settings → Code
security → Code scanning). Two consequences:

- *You cannot run default setup and an advanced-setup workflow at the same
  time.* Adding `codeql.yml` while default setup is on makes the workflow
  error. Switching to advanced setup means first turning default setup off.
- *The setting may be enforced by the `ossf` organization.* GitHub orgs
  can apply an enforced **code security configuration** to their public
  repos that turns on default setup org-wide. If so, the repo-level toggle
  may be locked, and detaching/switching to advanced setup may require an
  **org owner or security manager**, not just a repo admin. Do not flip
  this unilaterally — it is an outward-facing org policy. Check Settings →
  Code security (it names any applied configuration and whether it is
  enforced) and coordinate with an `ossf` org owner before changing it.

**Finding (2026-07-18): default setup is enabled but stale, and it is NOT
org-enforced.** Inspection of Settings → Code security → Code scanning
shows CodeQL **default setup** with **last scan on Jun 17** (JavaScript
5/5 files, Ruby 350/366 files), and **no grayed-out / org-managed
indicators** — so the `ossf` organization is not enforcing it; the repo
admin controls it fully.

The stale date is the key problem: **26 commits have merged to `main`
since Jun 17** (including Ruby security changes — input-validation
hardening, OmniAuth login handling, session-cookie logic, gem updates),
yet CodeQL has not scanned since. Default setup is therefore *not* covering
current activity and the SAST score will **not** self-correct. The Jun 17
last-scan date coincides exactly with the `coreinfrastructure` → `ossf`
**org move** (commit `2cd1603f`, "GitHub org move (#2842)"); renaming or
transferring a repository at the org level is a known way for CodeQL
default setup to silently stop working. In short: the org rename broke
default setup and it has been dead for a month.

**Decision: replace default setup with an advanced `codeql.yml`
workflow** (rather than reviving the same mechanism that just silently
died). Rationale, consistent with this project's practices:

- Deterministic — runs on every push and PR to `main`; if it ever breaks,
  the missing check is visible on the PR instead of failing silently.
- Survives org moves — a committed workflow is not tied to the settings
  association that the rename broke.
- In-repo and reviewable, like our other workflows (Brakeman, scorecard,
  sbom); reproducible and the form Scorecard reads most reliably.

Two manual, out-of-repo steps (both permitted, since not org-enforced):
turn **off** default setup (Settings → Code security → Code scanning →
CodeQL → disable default setup), then merge the workflow. Default setup and
an advanced workflow cannot coexist — leaving default setup on makes the
workflow error.

### Signed-Releases = 0 (releases exist but are unsigned)

`.github/workflows/sbom.yml` already creates GitHub Releases on every push
to `staging` and `production` (the `sbom-<branch>-<date>-<sha>` tags),
each carrying an SPDX SBOM asset — but no signature or provenance, hence
the 0.

Scorecard recognizes a release as *signed* if any asset name ends in one
of `.asc`, `.minisig`, `.sig`, `.sign`, `.sigstore`, or `.sigstore.json`
(probe `releasesAreSigned`), and awards **8** per signed release, or **10**
if the release also has SLSA provenance (an `*.intoto.jsonl` asset,
probe `releasesHaveProvenance`); the check averages this over the last five
releases.

**Implemented** (`sbom.yml`). We extend the existing SBOM job to sign the
SBOM with **cosign keyless (Sigstore)** signing, fully automatically in CI:

- Add `id-token: write` to the job so cosign can mint a short-lived GitHub
  OIDC token; no private key is stored and no human acts.
- Install cosign via the pinned first-party `sigstore/cosign-installer`
  action, then `cosign sign-blob --yes` the SBOM. cosign exchanges the OIDC
  token at Fulcio for an ephemeral certificate bound to this workflow's
  identity, signs, and logs the signature in the public Rekor transparency
  log.
- Upload `<sbom>.sig` (detached signature — the suffix Scorecard matches)
  and `<sbom>.pem` (the Fulcio signing certificate) as release assets,
  alongside the SBOM, via the existing `gh release create` step. (`gh` is
  preinstalled on the runner; no new dependency, and none needed locally.)

This moves Signed-Releases from 0 to **8** once the last five releases
carry signatures. Reaching **10** additionally requires SLSA provenance
(`*.intoto.jsonl`), e.g. via the SLSA GitHub generator — deferred as a
follow-up.

**Verifying a released signature** (any consumer, no secrets needed):

```sh
cosign verify-blob \
  --signature <sbom>.sig \
  --certificate <sbom>.pem \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp \
    '^https://github.com/ossf/best-practices-badge/\.github/workflows/sbom\.yml@' \
  <sbom>
```

**Caveat (recorded).** These releases are SBOM-archival snapshots, not
distributed product artifacts — the app is deployed to Heroku, not shipped
as a package. Signing the SBOM is still worthwhile: it proves the SBOM's
provenance and satisfies the check. We accept the SBOM as the artifact we
sign.

### Branch-Protection = 3 and Code-Review = 0

These are the two checks most tied to **GitHub repository settings and
process**, not repository files, so they cannot be fixed by editing code
in this branch alone.

**Branch-Protection.** Configure protection on `main`: require a pull
request before merging, require at least one approving review, require
code-owner review (we already have `.github/CODEOWNERS`), dismiss stale
approvals on new commits, require status checks to pass (Brakeman, CI),
and require branches to be up to date.

Separately, `scorecard.yml` has `repo_token` commented out
(around line 55). Without a token, Scorecard cannot **read** the full
branch-protection configuration and scores from limited public data. Add a
fine-grained `SCORECARD_TOKEN` PAT as a repository secret and uncomment
that line so Scorecard sees the real settings. (Creating the secret is a
manual, out-of-repo step.)

**Code-Review = 0** ("0 of N approved changesets") reflects that recent
merges — maintainer self-merges and Dependabot auto-merges — carry no
recorded approving review. Raising this is largely a **process** change
(get changes reviewed and approved through PRs) that follows naturally
once branch protection requires approvals.

### Pinned-Dependencies = 8 (already a deliberate decision — leave as-is)

The only unpinned image is `test/fuzz/Dockerfile`
(`gcr.io/oss-fuzz-base/base-builder-ruby`). It is **intentionally** left
unpinned, with a documented rationale in that file: OSS-Fuzz controls that
registry and expects projects to track the latest tag, so a stale digest
pin can silently break the fuzz build, and the supply-chain risk is low.
Our other Dockerfiles are hash-pinned.

Pinning this image would reach 10, but at the cost of fuzzing
reliability. Recommendation: **leave it unpinned**; this is working as
intended, and the 2-point deduction is an accepted trade-off. Revisit only
if OSS-Fuzz offers a stable, versioned base-image URI we can pin safely.

## Recommended order of work

1. **CII-Best-Practices** — update project #1's badge URL (biggest win,
   lowest effort, no code).
2. **SAST** — add the CodeQL workflow (planned next).
3. **Signed-Releases** — add cosign signing to `sbom.yml`.
4. **Branch-Protection / Code-Review** — enable branch protection, add
   `SCORECARD_TOKEN`, and adopt review-before-merge.
5. **Pinned-Dependencies** — no action (documented decision).

## Ways it would be good to improve Scorecard itself

These are changes to `ossf/scorecard` (not to this project) that would
make Scorecard reflect reality better — for us and for other projects.
Record them here now; they may be pursued later as upstream issues/PRs.

- **Recognize Brakeman as a SAST tool.** Brakeman is a widely-used static
  security analyzer for Rails. Adding it to Scorecard's SAST allowlist
  (by workflow detection and/or check-run name) would stop penalizing the
  large population of Rails projects that gate merges on Brakeman.
- **Handle repositories that changed organization/URL.** When a badge (or
  other external) lookup misses, Scorecard could follow the same
  GitHub redirect it already resolves, or query known former URLs, so a
  project that moved orgs is not reported as having "no badge." Our own
  CII-Best-Practices = 0 is entirely an artifact of this.
- **Let the CII/badge lookup match on more than the canonical repo URL.**
  Matching on homepage URL or a project-declared identifier (in addition
  to `repo_url`) would tolerate org renames and mirror/alias URLs.
- **Allow inline suppression / accepted-finding annotations for
  Pinned-Dependencies in Dockerfiles.** There is currently no way to mark
  a deliberately-unpinned `FROM` line (e.g. an OSS-Fuzz base image that is
  meant to track latest) as an accepted decision, forcing a choice between
  an unwanted pin and an unexplained deduction.
- **Recognize SARIF uploaded to GitHub code scanning as SAST evidence.**
  Crediting any tool that publishes results to the code-scanning API —
  not just a hard-coded tool allowlist — would reward projects using
  analyzers Scorecard does not specifically know about.
- **Acknowledge first-party GitHub Release creation in Token-Permissions
  scoring.** Creating a GitHub Release inherently needs `contents: write`,
  which caps the Token-Permissions score at 9/10 even when the release is
  made with GitHub's own `gh` CLI. Scorecard's "recognized packaging
  action" waiver does not cover release creation, so there is no way to
  reach 10 for a legitimate, first-party release step (see the rationale
  comment in `sbom.yml`).
