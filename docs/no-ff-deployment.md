# Deploying by merge commit instead of fast-forward

Written 2026-08-09. Nothing here is decided; this is the checklist for
deciding it. Expect to pick this up in one to three weeks.

## Why this document exists

`staging` sometimes sits behind `main` longer than we would like. Several
things get merged to `main` in a row, and pushing every one of them onward
is not worth the interruption, so `staging` drifts. We want `staging` to
catch up on its own after `main` has settled and passed everything, without
a person remembering to do it.

The obvious mechanisms each have a cost:

* **A scheduled job that pushes `main` into `staging`** needs a credential
  that can write to a protected deploy branch. That was rejected on
  2026-08-08; see "Then the deploy could have been a button, and is not" in
  [build-environment-staleness.md](./build-environment-staleness.md).

* **A bot that opens a pull request from `main` to `staging`** needs no new
  authority at all: opening a pull request between two existing branches
  creates no branch and no commit, so `pull-requests: write` is enough, and
  the App already has it. The merge stays a human click, which leaves
  authorization exactly where branch protection puts it.

The second is attractive, and it is blocked by one thing: **GitHub has no
fast-forward merge.** Clicking Merge creates a merge commit even when a
fast-forward is possible, so `staging` gains a commit that is not on
`main`, and our entire deploy model assumes the opposite.

This document asks what it would take to accept that, deliberately, rather
than tripping over it.

## What the change would be

Today a deploy is a fast-forward:

~~~~sh
git fetch origin main:staging +main:refs/remotes/origin/main &&
  git push origin staging
~~~~

`staging` is always a commit that also exists on `main`. After the change,
`staging` would be `main` plus a merge commit per deploy, and the same
question would arise separately for `production`.

Note what does **not** change: the merge is trivial, because `staging` is a
strict ancestor of `main` at merge time, so **the deployed tree is
byte-identical either way**. What changes is history shape, the commands,
and several arguments that are currently phrased in terms of commits rather
than trees.

## What breaks immediately

- [ ] **`rake deploy_staging`** in `lib/tasks/default.rake`. Its
  `git fetch origin main:staging` is rejected as a non-fast-forward from
  the first merge commit onward, permanently. Decide whether the task is
  rewritten, or retired in favour of the pull request. Its long comment
  block explains that the missing `--force` is the safety; that argument
  needs rewriting, not just the code.

- [ ] **`rake deploy_production`** in the same file. If only `staging` goes
  no-fast-forward, this keeps working, because `production` stays an
  ancestor of `staging`. It breaks only if `production` gets merge commits
  too. Decide the two branches separately and write down why.

- [ ] **The two-command recipe** in
  [INSTALL.md](./INSTALL.md#deployment-instructions), which exists so that
  someone with no development environment can deploy. Whatever replaces it
  must still work for a person with nothing but `git` and push rights.

- [ ] **Anything that computes how far `staging` is behind.** Counting
  commits between the branches stops being a clean answer once merges are
  in the history; `--first-parent` may be needed. Check the reporting
  block at the end of `deploy_staging` and anything new we write.

## Documentation that becomes false

Each of these states the fast-forward model as fact. Search by the quoted
phrase rather than by line number.

- [ ] `docs/implementation.md`, the deploy section: "**The copy must be a
  fast-forward.**" and especially "**Never deploy by merging a pull
  request.**", which currently says a merge "leaves a commit on `staging`
  that is not on `main`, so the two diverge and every later deploy is
  refused as a non-fast-forward. One convenient pull request breaks
  deploying from then on, and the repair is manual." That paragraph is the
  direct contradiction of this proposal and should be rewritten or
  reversed, not quietly deleted.

- [ ] `docs/INSTALL.md`: "**Do not deploy by merging a pull request.**",
  plus the explanations of why the fetch is unforced and why `--force` must
  not be added.

- [ ] `.circleci/config.yml`, header comment: "staging and production are
  only ever advanced from main".

- [ ] `lib/tasks/default.rake`, the `STATIC_CHECKS` comment: staging and
  production "are reached only by fast-forwarding main, which has already
  run every one of them".

- [ ] `docs/improve-scorecard.md`: "since staging/production are only ever
  advanced from it".

- [ ] `docs/build-environment-staleness.md`: the rejected-button analysis,
  and the `git merge --ff-only origin/staging` snippet.

- [ ] Check `docs/design.md`, `docs/case.md` and `docs/assurance-case.md`
  for deploy claims. `assurance-case.md` is the one where a stale claim
  matters most, since it is an argument rather than a description.

## The reasoning that must be re-derived

This is the subtle part, and the reason this deserves a document rather
than a commit.

**CircleCI skips the `static` job on the deploy branches**, and says why:
those branches "are reached only by fast-forwarding main, which has already
run every check in it". See the `static` job comment and the workflow
filter comment in `.circleci/config.yml`. `rake default`'s `STATIC_CHECKS`
list makes the same argument.

That justification is phrased in terms of **commits**. What actually makes
it sound is that the **tree** is identical to one that already passed. A
trivial merge preserves the tree, so the conclusion survives, but only
under a condition nobody currently has to think about:

- [ ] **The merge must be trivial.** If anyone ever pushes to `staging`
  directly, or a hotfix lands there, the merge of `main` into `staging` is
  no longer trivial, the resulting tree is one that has passed nowhere, and
  skipping the static checks on it is unsound. Under the fast-forward model
  this cannot happen, because a divergent `staging` refuses the deploy
  outright. Under merges it happens silently and produces a green deploy.

- [ ] Decide how that is prevented or detected: branch protection that
  forbids direct pushes to `staging`, a check that the merge commit's tree
  equals `main`'s tree, or an accepted risk written down.

- [ ] Restate the CircleCI and `STATIC_CHECKS` comments in terms of the
  tree, whichever way the decision goes. They are currently true for a
  reason they do not name.

## Authorization and workflow-event traps

- [ ] **Never let the merge be performed by `GITHUB_TOKEN`.**
  `.github/workflows/sbom.yml` triggers on pushes to `staging` and
  `production`, and GitHub raises no workflow runs for events created by
  `GITHUB_TOKEN`. A pull request auto-merged with it would deploy
  correctly and silently stop generating and signing SBOMs. This is the
  second reason the button was rejected on 2026-08-08 and it applies
  unchanged here. A human clicking Merge is safe; auto-merge is the
  hazard.

- [ ] Confirm branch protection on `staging` actually permits merging a
  pull request, and by whom. The current model has people pushing
  directly, so the protection may not be configured for pull requests at
  all.

- [ ] If a bot opens the pull request, confirm what it needs. Opening one
  should require only `pull-requests: write`, which
  `.github/actions/mint-app-token/action.yml` already exposes and
  `renovate.yml` already mints. If anything asks for `contents: write`,
  stop and re-read the 2026-08-08 decision, because that is the boundary
  it drew.

## Operational questions

- [ ] **Rollback.** Under fast-forward, backing `staging` out is a matter
  of moving it to an earlier `main` commit. Write the new recipe before
  needing it.

- [ ] **Reading history.** `git log staging` gains a merge per deploy.
  Decide whether the documented incantation becomes
  `git log --first-parent`.

- [ ] **Does the pull request re-run anything?** `main.yml` triggers on
  pull requests whose base is `main`, so a `main` to `staging` pull
  request should show the checks already run on `main`'s head rather than
  starting new ones. Confirm; the value of the pull request is largely
  that it carries that report.

- [ ] **What opens it, and when.** The trigger we discussed is: `main` is
  green, `staging` is strictly behind, and `main`'s head has been sitting
  for about an hour, checked on a schedule. A rapid sequence of merges
  then batches into one deploy. That part is independent of the
  fast-forward question and could be built either way.

- [ ] **Staging restores production's database on every deploy.** See the
  "Restore production's latest backup over staging" step in
  `.circleci/config.yml`. More frequent staging deploys mean more
  restores; the hourly batching is what keeps that bounded.

## Empirical checks before deciding

Cheap to run, and each one removes a guess:

1. Open a throwaway `main` to `staging` pull request on a fork and confirm
   the Merge button produces a merge commit even though a fast-forward is
   possible. This is documented GitHub behaviour but worth seeing once.

2. Confirm the merge commit's tree is identical: `git diff main staging`
   should be empty.

3. Confirm CircleCI runs on the merge commit, and that its statuses and
   check runs land where `deploy_production`'s green-check `curl` looks
   for them. That check asks GitHub for `commits/staging/status` and
   `commits/staging/check-runs`, which are commit-shaped and should not
   care, but it is the gate on production.

4. Confirm `sbom.yml` fires on the merge push.

5. Confirm `deploy_production` still fast-forwards `production` from a
   `staging` that now contains merge commits.

## Alternatives this is weighed against

* **Pull request as signal only.** The bot opens it for visibility and the
  check report; the actual advance stays the two commands, so the
  fast-forward model is untouched. GitHub should then close the pull
  request as merged once `main`'s commits are reachable from `staging`,
  though that needs confirming. The cost is a footgun: the Merge button on
  that pull request must never be clicked, and nothing enforces it.

* **A scheduled push with a deploy credential.** Fastest to use, no model
  change, but it needs the bypass actor that was rejected on 2026-08-08,
  and bypass attaches to the App identity, so every workflow that can mint
  a `contents: write` token from that App would inherit the ability to
  push a deploy branch.

* **Do nothing.** `staging` drifts, and someone pushes it forward when
  they notice. This is the current state and it is not terrible; the
  document exists because the drift is annoying, not because it is
  dangerous.

## Prior decisions to reread first

* "Then the deploy could have been a button, and is not" in
  [build-environment-staleness.md](./build-environment-staleness.md),
  rejected 2026-08-08, for the credential and for the SBOM trap.

* The deploy section of [implementation.md](./implementation.md), which
  argues the fast-forward model in detail and is the most complete
  statement of what would be given up.
