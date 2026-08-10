# Security Review: hackerbot-claw Attack Campaign

**Date:** 2026-03-02
**Reviewer:** Claude Code (automated analysis)
**Scope:** `.circleci/`, `.github/workflows/`, `.github/dependabot.yml`, Heroku deployment config
**Reference warning:** CRob / OpenSSF, March 1, 2026 (TLP:CLEAR)
  "Severity: High – Active exploitation in the wild"

David A. Wheeler asked Claude Code for this report with the
following instructions:

> CRob has sent out a warning about an ongoing attack.
> Please review our configuration and setup to ensure that we aren't
> vulnerable (to the extent you can). If we *are* vulnerable, please provide
> recommendations on how to fix iot.
>
> Please review our CircleCI configuration (especially in .circleci),
> GitHub configuration (especially in .github), and Heroku configuration.
> If you need additional information, tell me how to get it.
> Our assurance case may have helpful information (docs/assurance-case.md).

---

## Executive Summary

The "hackerbot-claw" campaign targets GitHub Actions workflows that use
privileged triggers, execute untrusted fork code, or reference unpinned
third-party actions. This project is **substantially hardened** against
this class of attack — no `pull_request_target` triggers, no fork code
execution in privileged contexts, and most actions pinned to SHA hashes.

**Two specific gaps** directly match the attack patterns being exploited:
both are in `.github/workflows/codespell.yml`. Additionally, there are
several lower-priority hardening improvements worth addressing.

---

## Priority 1 (HIGH): Unpinned actions in `codespell.yml`

### Risk

`.github/workflows/codespell.yml` references two third-party GitHub
Actions using mutable tag names instead of immutable commit SHAs:

```yaml
uses: actions/checkout@v5
uses: codespell-project/actions-codespell@v2
```

A tag like `@v5` or `@v2` can be silently moved to point to a different
commit at any time — by the repo owner, or by an attacker who has
compromised the repo or account. When your workflow runs, GitHub fetches
whatever commit the tag currently points to. If an attacker has moved
the tag to malicious code, that code runs inside your CI environment with
access to `GITHUB_TOKEN` and any secrets available to the job.

This is precisely the supply chain attack vector that "hackerbot-claw"
exploits. Your other two workflows (`main.yml`, `scorecard.yml`) already
pin all their actions correctly — `codespell.yml` was missed.

### Fix

**File:** `.github/workflows/codespell.yml`

The correct commit SHAs were verified via the GitHub API on 2026-03-02:

- `actions/checkout` v5.0.0 → `08c6903cd8c0fde910a37f88322edcfb5dd907a8`
  (this is the same SHA already used in `main.yml` and `scorecard.yml`)
- `codespell-project/actions-codespell` v2 → `406322ec52dd7b488e48c1c4b82e2a8b3a1bf630`

**Change 1** (line 17 — checkout action):

```diff
-        uses: actions/checkout@v5
+        uses: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.0
```

**Change 2** (line 24 — codespell action):

```diff
-        uses: codespell-project/actions-codespell@v2
+        uses: codespell-project/actions-codespell@406322ec52dd7b488e48c1c4b82e2a8b3a1bf630 # v2
```

**Note on SHA verification:** Before applying these SHAs, you may wish
to independently verify them:

```bash
# Verify actions/checkout v5.0.0
curl -s https://api.github.com/repos/actions/checkout/git/ref/tags/v5.0.0 \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['object']['sha'])"
# Expected: 08c6903cd8c0fde910a37f88322edcfb5dd907a8

# Verify codespell-project/actions-codespell v2
curl -s https://api.github.com/repos/codespell-project/actions-codespell/git/ref/tags/v2 \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['object']['sha'])"
# Expected: 406322ec52dd7b488e48c1c4b82e2a8b3a1bf630
```

---

## Priority 2 (MEDIUM): No `permissions` block in `codespell.yml`

### Risk

`codespell.yml` has no `permissions:` declaration. The other two
workflows explicitly restrict permissions:

- `main.yml`: `permissions: contents: read` / `checks: write`
- `scorecard.yml`: `permissions: read-all` at workflow level

Without an explicit declaration, the job uses GitHub's repository default
permissions. Depending on repository settings, this could include
`contents: write` or `pull-requests: write`. If the unpinned actions
(Priority 1 above) were to deliver malicious code, broader permissions
magnify the damage.

Even after fixing the pinning issue, defense-in-depth requires explicit
minimal permissions on every workflow.

### Fix

**File:** `.github/workflows/codespell.yml`

Add a `permissions` block at the workflow level, after the `on:` block:

```diff
 on:
   push:
     branches: [main]
   pull_request:
     branches: [main]

+# Limit permissions per OpenSSF Scorecard best practices.
+# Since we set "permissions", anything unset has access "none".
+permissions:
+  contents: read
+
 jobs:
```

`contents: read` is sufficient — the codespell job only reads files.

---

## Priority 3 (MEDIUM): No `CODEOWNERS` file

### Risk

There is no `.github/CODEOWNERS` file. Without CODEOWNERS, GitHub does
not automatically request review from specific trusted maintainers when
pull requests modify CI/CD configuration files. An attacker submitting a
PR that modifies `.github/workflows/*.yml` or `.circleci/config.yml` gets
no automatic extra scrutiny — it relies on reviewers manually noticing
that security-sensitive files changed.

The CRob warning explicitly recommends:
> "Require code review for all changes to `.github/workflows/*.`"
> "Use CODEOWNERS to enforce additional scrutiny on CI configuration
> changes."

### Fix

**Create:** `.github/CODEOWNERS`

Replace `@YOUR-GITHUB-USERNAME` and `@YOUR-TEAM` with the actual
GitHub username(s) / team(s) responsible for security review:

```
# CODEOWNERS — enforce mandatory review for security-sensitive files
# See: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners

# CI/CD pipeline configuration — require security review on all changes
/.github/workflows/   @YOUR-GITHUB-USERNAME
/.circleci/           @YOUR-GITHUB-USERNAME

# Security policy and assurance documentation
/SECURITY.md          @YOUR-GITHUB-USERNAME
/docs/assurance-case.md  @YOUR-GITHUB-USERNAME

# Dependency management
/.github/dependabot.yml  @YOUR-GITHUB-USERNAME
/Gemfile               @YOUR-GITHUB-USERNAME
/Gemfile.lock          @YOUR-GITHUB-USERNAME
```

**Note:** CODEOWNERS only enforces review if branch protection rules
require "Review from Code Owners" for the protected branch. Verify this
is enabled in GitHub → Settings → Branches → Branch protection rules
for `main`.

---

## Priority 4 (LOW): Incorrect version comment in `main.yml`

### Risk

This is documentation-only — no security impact. However, incorrect
comments mislead maintainers doing future updates, potentially causing
them to pin to the wrong version.

**File:** `.github/workflows/main.yml`, line 44

The comment says `v4.1` but the SHA `08c6903cd8c0fde910a37f88322edcfb5dd907a8`
is actually `v5.0.0` (verified via GitHub API — `actions/checkout` v5.0.0
maps to exactly this SHA, and `v4.1.0` maps to a different SHA
`8ade135a41bc03ea155e62e844d188df1ea18608`).

`scorecard.yml` correctly labels the same SHA as `v5.0.0`.

### Fix

**File:** `.github/workflows/main.yml`

```diff
-      - uses: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # pin @v4.1
+      - uses: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.0
```

---

## Priority 5 (LOW): Assurance case incorrectly describes `scorecard.yml`

### Risk

Documentation-only — no security impact. However, the assurance case is
a key document for demonstrating security posture to auditors and
certification bodies. Inaccuracies undermine its credibility.

**File:** `docs/assurance-case.md`, lines 3249–3253

The assurance case states that branch name validation is performed in
`scorecard.yml`:

> `.github/workflows/scorecard.yml`: Validates branch names in the
> scorecard security workflow

This is incorrect. `scorecard.yml` does **not** include a branch name
validation step. It correctly explains *why* in an inline comment
(Scorecard's `publish_results=true` mode forbids `run:` steps), but
the assurance case text implies the validation is present when it is not.

### Fix

**File:** `docs/assurance-case.md`

Find the bullet list around lines 3249–3253 and update the scorecard
entry:

```diff
-    * `.github/workflows/scorecard.yml`: Validates branch names in the
-      scorecard security workflow
-    * `.github/workflows/codespell.yml`: Validates branch names in the
-      codespell workflow
+    * `.github/workflows/codespell.yml`: Validates branch names in the
+      codespell workflow
+    * `.github/workflows/scorecard.yml`: Branch name validation is
+      intentionally omitted because Scorecard's `publish_results=true`
+      mode prohibits `run:` steps. This is acceptable because the
+      scorecard workflow does not use branch names in any shell commands.
```

---

## Priority 6 (LOW): Heroku installer integrity not verified

### Risk

The CircleCI deploy job (`.circleci/config.yml`) downloads the Heroku
CLI installer and computes its SHA256, but **does not compare it against
a known-good value** — it only prints the hash for audit logging:

```yaml
echo "** Computing SHA-256 of installer"
sha256sum install.sh          # prints hash, but never checks it
echo "** Running installer"
chmod a+x install.sh
sh install.sh
```

This means a MITM or a compromise of `cli-assets.heroku.com` could
deliver a malicious installer that gets executed. The logging helps
detect this *after the fact* but does not prevent it.

### Risk context

This risk is lower than the GitHub Actions issues because:

1. CircleCI deploy jobs already run in a trusted context (branch-restricted
   to `staging`/`production`, behind the `build` job)
2. The Heroku CLI is only a deployment tool, not part of the final
   artifact
3. The HTTPS connection to `cli-assets.heroku.com` provides some
   integrity guarantee

### Fix options (choose one)

**Option A (Recommended):** Pin the installer to a known SHA256. After
each Heroku CLI release, record the expected hash and compare:

```bash
EXPECTED_SHA="<known-good-sha256>"
ACTUAL_SHA=$(sha256sum install.sh | awk '{print $1}')
if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
  echo "ERROR: Heroku installer SHA256 mismatch!"
  echo "  Expected: $EXPECTED_SHA"
  echo "  Actual:   $ACTUAL_SHA"
  exit 1
fi
```

**Option B:** Use the Heroku CLI as a pinned OCI container image instead
of a downloaded script installer. This aligns with how you already pin
your Docker images.

**Note:** Implementing Option A requires updating the expected SHA each
time Heroku releases a new CLI version, which adds maintenance burden.
The current approach (log-but-don't-verify) is documented behavior and
the risk is limited to the deployment pipeline.

---

## What Is Already Well-Hardened

The following controls are in place and directly address the "hackerbot-claw"
attack patterns. **No changes needed.**

| Control | Where implemented | Notes |
|---|---|---|
| No `pull_request_target` trigger | All three workflows | Safe `pull_request` used instead |
| No untrusted fork code execution | All three workflows | No privileged fork checkout |
| Actions pinned to commit SHA | `main.yml`, `scorecard.yml` | Only `codespell.yml` missed (see Priority 1) |
| Explicit minimal permissions | `main.yml`, `scorecard.yml` | `codespell.yml` missing (see Priority 2) |
| `step-security/harden-runner` | `main.yml` | Egress policy in audit mode |
| `persist-credentials: false` | `scorecard.yml` | Prevents credential leakage |
| Branch name validation script | `main.yml`, both CircleCI jobs | Blocks injection via branch names |
| CircleCI Docker images SHA-pinned | `.circleci/config.yml` | Both primary and secondary images |
| Deploy restricted to allowlist | `.circleci/config.yml` | `staging` and `production` only |
| Dependabot for github-actions | `.github/dependabot.yml` | Daily scans for action updates |
| Dependabot for bundler gems | `.github/dependabot.yml` | Daily scans for gem updates |
| No inline shell injection risk | All workflows | No `${{ github.event.* }}` in `run:` steps |

---

## Recommended Action Order

1. **Fix `codespell.yml` pinning** (Priority 1) — directly addresses the
   active attack vector; small, safe change; can be done immediately.
2. **Add `permissions:` to `codespell.yml`** (Priority 2) — one-line
   addition; no risk; should be done in the same PR as Priority 1.
3. **Create `CODEOWNERS`** (Priority 3) — requires knowing the right
   GitHub username(s)/team(s); then verify branch protection rules
   require code owner review.
4. **Fix version comment in `main.yml`** (Priority 4) — trivial one-word
   fix; can be bundled with the above PR.
5. **Fix assurance case** (Priority 5) — slightly more surgical text edit;
   low urgency.
6. **Heroku installer verification** (Priority 6) — requires ongoing
   maintenance; evaluate whether the risk warrants the burden.

---

## Controls Requiring Verification via GitHub UI

The following cannot be determined from local file inspection. They
should be verified in GitHub → Settings → Branches:

- **Branch protection on `main`**: Confirm that "Require pull request
  reviews before merging" is enabled with at least 1 required reviewer.
- **Dismiss stale reviews**: Confirm that approvals are dismissed when
  new commits are pushed (prevents approval of a clean PR and then
  pushing malicious changes).
- **Require status checks**: Confirm that CI must pass before merging.
- **Restrict push to main**: Confirm that direct pushes to `main` are
  blocked (all changes must go through PRs).
- **Code owner review requirement**: Once CODEOWNERS is added
  (Priority 3), confirm "Require review from Code Owners" is enabled.

---

*Analysis performed against commit `3b4f21b0` (branch: main, 2026-03-02).
SHA hashes verified independently via the GitHub API.*
