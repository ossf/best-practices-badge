# Secrets and Credentials Management Policy and Processes

This document defines the policy for managing secrets and credentials
used by the OpenSSF Best Practices Badge project (BadgeApp)
for the entire application.
It addresses storing, accessing, and rotating secrets, and confirms
that no sensitive credentials are hard-coded in source code or
stored in version control.
This document also describes the secret rotation processes.

See also: `docs/implementation.md` (environment variable reference),
`docs/assurance-case.md` (cryptographic design rationale),
and `config/initializers/session_store.rb` (session store configuration).

The procedures below assume `$APP` is set to the Heroku app name, e.g.:

~~~sh
export APP=production-bestpractices
~~~

## Scope

This policy covers all secrets and credentials used by the BadgeApp
production system, including encryption keys, OAuth credentials,
API keys, and service passwords.

This policy does *not* discuss individual user secrets.
Local accounts have passwords which are stored using bcrypt, and
*may* have a remember-me token set as well.
See the assurance case for more information on individual account
secrets are protected and changed.

## Storage

Production secrets are **never** hard-coded in source
code or committed to version control.

Most production secrets are stored as **environment variables** on
Heroku (the application tier).
The one exception is `HEROKU_API_KEY`, which is stored in the CircleCI
`bestpractices-heroku-deploy` context and is used only by the CI/CD
pipeline to deploy the app automatically when staging or production
testing passes.

Development-only throwaway keys may be placed in `.env.local`, which
is excluded from version control via `.gitignore`.
The `.env` file committed to the repository contains only
test-application OAuth credentials (a GitHub OAuth app whose callback
is `http://127.0.0.1:31337/auth/github`, usable only during local
testing); it does not contain any real production secrets.
See `docs/testing.md` for details on why those credentials are safe.

Sensitive request parameters (passwords, tokens, keys, and email
addresses) are automatically filtered from Rails logs via
`config/initializers/filter_parameter_logging.rb`
to reduce the risk of their exposure.

## Access Control

Access to production secrets is limited to personnel with system-level
access to the hosting platforms:

- **Heroku**: application environment variables (most secrets below)
- **CircleCI**: `HEROKU_API_KEY`, stored in the
  `bestpractices-heroku-deploy` context
- **Fastly dashboard**: required to generate a replacement `FASTLY_API_KEY`
  (the key itself is stored as a Heroku environment variable)

No application-level role grants access to these secrets.
Even a web admin does not have the privileges to see these.

## Secrets Inventory

The following table lists all secrets used in production, their
purpose, and where rotation is documented.

| Environment Variable | Purpose | Rotation procedure |
|---|---|---|
| `SECRET_KEY_BASE` | Rails session and cookie signing/encryption | See [Rotating SECRET_KEY_BASE](#rotating-secret_key_base) below |
| `EMAIL_ENCRYPTION_KEY` | AES-256-GCM encryption of stored user email addresses | See [Rotating email keys](#rotating-email-encryption-keys) below |
| `EMAIL_BLIND_INDEX_KEY` | Key-derivation salt for Active Record Encryption of user email addresses (formerly the blind index key) | See [Rotating email keys](#rotating-email-encryption-keys) below |
| `SESSION_ID_HMAC_KEY` | HMAC-SHA256 key for `LoginSession`'s session id digest (`docs/login-session.md`) | See [Rotating SESSION_ID_HMAC_KEY](#rotating-session_id_hmac_key) below |
| `PENDING_RESUBMISSION_HMAC_KEY` | HMAC-SHA256 key for `PendingResubmission`'s random-token digest (`docs/login-session-18.md` step 18) | See [Rotating PENDING_RESUBMISSION_HMAC_KEY](#rotating-pending_resubmission_hmac_key) below |
| `BADGEAPP_BADPWKEY` | HMAC-SHA512 key protecting the bad-password database | See [Rotating BADGEAPP_BADPWKEY](#rotating-badgeapp_badpwkey) below |
| `GITHUB_KEY` | GitHub OAuth application client ID | Rotate via GitHub OAuth app settings; redeploy |
| `GITHUB_SECRET` | GitHub OAuth application client secret | Rotate via GitHub OAuth app settings; redeploy |
| `FASTLY_API_KEY` | Fastly CDN cache purge API key | See [Rotating Fastly credentials](#rotating-fastly-credentials) below |
| `FASTLY_SERVICE_ID` | Identifies the Fastly service to purge | Changes only if the CDN service is recreated |
| `BADGEAPP_SEND_EMAIL_ADDRESS` | Sender email address (the From: address) | Update when changing email provider |
| `BADGEAPP_SEND_EMAIL_USERNAME` | SMTP relay authentication username | Rotate via email provider dashboard; update Heroku config var |
| `BADGEAPP_SEND_EMAIL_PASSWORD` | SMTP relay authentication password | Rotate via email provider dashboard; update Heroku config var |
| `HEROKU_API_KEY` | Heroku API token used by CircleCI to deploy and manage the app | See [Rotating the CircleCI deploy token](#rotating-the-circleci-deploy-token) below |
| `DATABASE_URL` | PostgreSQL connection string (set by Heroku automatically) | See [Rotating DATABASE_URL](#rotating-database_url) below |

For full descriptions of each variable, see `docs/implementation.md`.

## Rotation Procedures

Rotate secrets whenever personnel with access depart, or upon any
suspected or confirmed exposure.

### Rotating `SECRET_KEY_BASE`

Changing `SECRET_KEY_BASE` immediately invalidates **all active
sessions and remember-me tokens**, logging out every user.
Use this as the preferred approach for a forced global logout.

~~~sh
# Generate a fresh secret and deploy it.
# Heroku restarts the app automatically;
# all sessions are invalidated immediately.
VAL=$(openssl rand -hex 64)
heroku config:set SECRET_KEY_BASE=$VAL --app $APP
~~~

If you want to invalidate sessions without changing the secret
(e.g., for a clean break after a deploy), change the cookie key name
in `config/initializers/session_store.rb` from `_BadgeApp_session`
to a new name (e.g., `_BadgeApp_session_v2`) and deploy.

The `login_sessions` table (`docs/login-session.md`) gives a second,
narrower global-logout mechanism that needs no redeploy: deleting its
rows. See [Rotating SESSION_ID_HMAC_KEY](#rotating-session_id_hmac_key)
below for how, and for the important caveat that it does not, by
itself, invalidate remember-me tokens the way rotating
`SECRET_KEY_BASE` does.

### Rotating Email Encryption Keys

`EMAIL_ENCRYPTION_KEY` and `EMAIL_BLIND_INDEX_KEY` protect stored user
email addresses. Rotating them requires re-encrypting every user's
email address in the database.
The rake task `rekey` (defined in `lib/tasks/default.rake`) performs this
migration; it is safe to re-run if interrupted.

~~~sh
# Take the site offline while rekeying (prevents writes during migration).
heroku maintenance:on --app $APP

# Generate new keys.
NEW_ENC_KEY=$(openssl rand -hex 32)
NEW_IDX_KEY=$(openssl rand -hex 32)

# Capture the current encryption and salt keys before replacing them.
OLD_ENC_KEY=$(heroku config:get EMAIL_ENCRYPTION_KEY --app $APP)
OLD_IDX_KEY=$(heroku config:get EMAIL_BLIND_INDEX_KEY --app $APP)

# Install the new keys, keeping the old ones available for the rekey task.
heroku config:set \
  EMAIL_ENCRYPTION_KEY_OLD=$OLD_ENC_KEY \
  EMAIL_BLIND_INDEX_KEY_OLD=$OLD_IDX_KEY \
  EMAIL_ENCRYPTION_KEY=$NEW_ENC_KEY \
  EMAIL_BLIND_INDEX_KEY=$NEW_IDX_KEY \
  --app $APP

# Re-encrypt all user email addresses (takes a few minutes; safe to re-run).
# This processes every email address in turn, decrypting the email addresses
# using the old keys EMAIL_ENCRYPTION_KEY_OLD and EMAIL_BLIND_INDEX_KEY_OLD,
# then encrypting using the new keys EMAIL_ENCRYPTION_KEY and
# EMAIL_BLIND_INDEX_KEY. It exits with an error listing any users whose
# addresses could not be decrypted; investigate those before continuing.
script/heroku_run $APP rake rekey

# Remove the old keys only once rekey completes without an error.
heroku config:unset EMAIL_ENCRYPTION_KEY_OLD EMAIL_BLIND_INDEX_KEY_OLD --app $APP

# Bring the site back online.
heroku maintenance:off --app $APP
~~~

### Rotating `SESSION_ID_HMAC_KEY`

`SESSION_ID_HMAC_KEY` computes `login_sessions.session_id_digest` from
the raw session id in each user's cookie (`docs/login-session.md`); the
raw id itself is never stored anywhere. Rotating the key makes every
existing `login_sessions` row permanently unmatchable, so every
logged-in user is treated as logged out on their next request: the
same *kind* of effect as rotating `SECRET_KEY_BASE` above, but it
leaves `SECRET_KEY_BASE`-signed cookies, including remember-me tokens,
intact. That distinction matters: a user with an active "Keep me
logged in" token is silently logged back in on their very next request
(`ApplicationController#try_remember_token_login`), creating a fresh
row under the new key. For a logout that also covers those users,
rotate `SECRET_KEY_BASE` instead, or additionally clear every stored
remember-me token.

~~~sh
# Generate a fresh key and deploy it. Heroku restarts the app
# automatically; every existing login_sessions row becomes unmatchable
# immediately.
VAL=$(openssl rand -hex 32)
heroku config:set SESSION_ID_HMAC_KEY=$VAL --app $APP

# The now-unmatchable rows can never be looked up again under any key;
# delete them rather than waiting up to 30 days for the daily purge
# task's absolute-age cleanup (docs/login-session.md) to catch them.
script/heroku_run $APP rails runner "LoginSession.delete_all"
~~~

#### Forcing re-authentication without rotating the key

The delete above is, by itself, also a quick global-logout tool that
needs no key change or redeploy: useful when a specific session
(not the key) is believed compromised, or you simply want everyone to
re-authenticate right now:

~~~sh
script/heroku_run $APP rails runner "LoginSession.delete_all"
~~~

The same remember-me caveat above applies: additionally run
`script/heroku_run $APP rails runner "User.update_all(remember_digest: nil)"`
if remember-me tokens must be invalidated too.

### Rotating `PENDING_RESUBMISSION_HMAC_KEY`

`PENDING_RESUBMISSION_HMAC_KEY` computes
`pending_resubmissions.hashed_random_id` from the raw token in a
logged-out submitter's cookie (`docs/login-session-18.md` step 18); the
raw token itself is never stored anywhere. Rotating the key makes
every existing `pending_resubmissions` row permanently unmatchable.
Unlike `SESSION_ID_HMAC_KEY`, there's no remember-me-style caveat here:
nothing auto-recreates a pending resubmission. The only user-visible
effect is that anyone with a genuinely in-flight stash (stashed a form
submission while logged out, hasn't yet logged back in to resume it)
sees "may have expired" instead of their draft on their next login,
the same experience as the stash simply aging out after three days.
Low stakes; rotate freely.

~~~sh
# Generate a fresh key and deploy it. Heroku restarts the app
# automatically; every existing pending_resubmissions row becomes
# unmatchable immediately.
VAL=$(openssl rand -hex 32)
heroku config:set PENDING_RESUBMISSION_HMAC_KEY=$VAL --app $APP

# The now-unmatchable rows can never be looked up again under any key;
# delete them rather than waiting up to three days for the daily purge
# task's age-based cleanup (docs/login-session-implementation.md
# section 15) to catch them.
script/heroku_run $APP rails runner "PendingResubmission.delete_all"
~~~

### Rotating `BADGEAPP_BADPWKEY`

This key protects the bad-password database. Changing it requires
rebuilding the database from the raw password list (takes a few minutes).

The bad-password database itself is public information. We encrypt it
so that when we query to determine if a password is in it, we always
query using an *encrypted* password. Thus, we want to rotate this
database when the key is exposed, *not* to protect the encrypted database,
but to protect future passwords when they are compared to the database.

~~~sh
# Generate a new key and rebuild the bad-password database.
VAL=$(openssl rand -hex 128)
heroku config:set BADGEAPP_BADPWKEY=$VAL --app $APP
script/heroku_run $APP rake update_bad_password_db
~~~

### Rotating GitHub OAuth Credentials

First generate a new client secret in the GitHub OAuth application settings
for the BadgeApp app (keep the same client ID unless recreating the app).
Then deploy the new credentials:

~~~sh
# Set NEW_GITHUB_KEY and NEW_GITHUB_SECRET from the GitHub OAuth app settings page.
NEW_GITHUB_KEY=...
NEW_GITHUB_SECRET=...
heroku config:set GITHUB_KEY=$NEW_GITHUB_KEY GITHUB_SECRET=$NEW_GITHUB_SECRET --app $APP
# heroku config:set triggers an automatic restart; no separate restart needed.
~~~

### Rotating the CircleCI Deploy Token

CircleCI authenticates to Heroku using `HEROKU_API_KEY`, stored in the
CircleCI `bestpractices-heroku-deploy` context.
It is used both by the Heroku CLI (maintenance mode, migrations) and by
`git push heroku` (via `~/.netrc`) during every deployment.
If this key is exposed it needs to be rotated *immediately*; someone
with this token could deploy their own app to our site instead.

To rotate it:

1. Generate a new scoped Heroku API token (do not use the account-wide
   "Regenerate API Key" in the Heroku dashboard; that invalidates all
   tools using that Heroku account's key):

   ~~~sh
   heroku authorizations:create --description "CircleCI deploy token"
   # Note the token value printed; you will need it in the next step.
   ~~~

2. Update the CircleCI `bestpractices-heroku-deploy` context with the
   new token value:
   - Open **CircleCI → Organization Settings → Contexts →
     bestpractices-heroku-deploy**.
   - Delete the existing `HEROKU_API_KEY` environment variable and add it
     again with the new token value.

3. Revoke the old token so it can no longer be used:

   ~~~sh
   # List authorizations to find the old token's ID, then revoke it.
   heroku authorizations
   OLD_AUTH_ID=...  # paste the ID of the old CircleCI token from above
   heroku authorizations:revoke $OLD_AUTH_ID
   ~~~

4. Trigger a test deployment (e.g., push to the staging branch) and confirm
   it succeeds end-to-end.

### Rotating Fastly Credentials

First generate a new API token in the Fastly dashboard with the minimum
necessary scope (purge access to the relevant service).
Then deploy and verify:

~~~sh
# Set NEW_FASTLY_API_KEY from the Fastly dashboard.
NEW_FASTLY_API_KEY=...
heroku config:set FASTLY_API_KEY=$NEW_FASTLY_API_KEY --app $APP
# Verify CDN purges still work.
script/heroku_run $APP rake fastly:purge_all
~~~

### Rotating `DATABASE_URL`

`DATABASE_URL` grants direct database read and write access by itself,
no other secret needed: on a leak, it's the most severe credential in
this whole table (`docs/login-session-18.md` step 20's "Honest limits"
section works through why nothing else here changes that). Two direct
mitigations were considered and set aside as impractical for this
app's current Heroku plans: restricting database network access to
known IPs, and a least-privilege database role for the app separate
from a migration/admin role. What's in place instead is automated
daily rotation, so a stale leaked copy (an old log line, a forgotten
backup, a stale secrets-manager snapshot) stays valid for at most a
day rather than indefinitely. This does not help against an attacker
who steals the live credential and uses it immediately; rotation
bounds exposure *time*, it doesn't prevent exposure.

The rotation itself runs from CircleCI's `bestpractices-heroku-deploy`
context (`.circleci/config.yml`, jobs `rotate-db-credentials`,
workflows `rotate-staging-db`/`rotate-production-db`), not from inside
the app: rotating `DATABASE_URL` from the app's own dyno would need a
Heroku credential capable of modifying config vars living in the exact
environment this is trying to protect. Two CircleCI Scheduled Triggers,
configured under the project's Triggers settings, named
`rotate-staging-db` and `rotate-production-db` to match the workflow
names, each daily, targeting `main`, drive this; they're configuration,
not something in this repository.

#### One-time setup: creating the CircleCI Scheduled Triggers

Do this once, after this branch merges and deploys (the `when:`
conditions in `.circleci/config.yml` need to already exist on `main`
for a trigger to find them):

1. In the CircleCI web app, open the project, then **Project
   Settings → Triggers**.
2. Add a trigger named `rotate-staging-db`: cron schedule once daily,
   config source branch `main`, no pipeline parameters needed (the
   workflow selects itself by trigger name via the `when:` condition
   in `.circleci/config.yml`).
3. Repeat for `rotate-production-db`.
4. After creating both, trigger each manually once from the CircleCI
   UI ("Trigger Pipeline" on the trigger's page) to confirm it runs
   the `rotate-production-db`/`rotate-staging-db` workflow and only
   that workflow, not `build-deploy` too.

#### Choosing a rotation time

Pick a time in each trigger's cron schedule with the lowest concurrent
traffic you can find: `heroku pg:credentials:rotate` changes the
`DATABASE_URL` config var, which Heroku treats like any other config
change and restarts dynos for, so requests in flight at that moment
can see a brief connection blip. Check Heroku Metrics (or whatever
traffic data this project already has) for this app's actual
low-traffic window rather than guessing; a plausible starting point,
worth confirming against that data rather than trusting on its own,
is somewhere in the 06:00 to 09:00 UTC range, since that's overnight
for the Americas and early morning for Europe. Stagger the staging
and production triggers a few minutes apart so a rotation problem
shows up on staging first.

#### If a rotation fails

`heroku pg:credentials:rotate` rotates the existing credential's
password in place; it doesn't create a second, separately-named
credential (confirmed against Heroku's own Postgres Credentials
documentation, since this is exactly the kind of assumption worth
checking rather than guessing). If it errors before Heroku starts
changing the password at all (an expired `HEROKU_API_KEY`, a network
problem, a Heroku API outage), nothing changes, and the app keeps
running on its current, still valid credential exactly as if the
scheduled run had never fired.

The one state that can actually get stuck: if a connection stays open
through the full 30-minute drain window (a leaked connection-pool
member that's never cycled, say), the credential is left in Heroku's
`rotating` state rather than completing on its own. The
`rotate-db-credentials` CircleCI job (`.circleci/config.yml`) checks
for exactly this before every rotation attempt and, if found,
force-completes it (`--force`, dropping the lingering connection)
before proceeding, so a rotation stuck this way clears itself on the
next scheduled run with no one needing to intervene. Heroku's docs
don't say what a plain (non-forced) rotate call does against a
credential already `rotating`, so that's deliberately not guessed at;
detecting the state first and forcing only that specific, known-stuck
case is safer than forcing every run.

No automatic retry beyond that single self-heal step is built into
the CircleCI job: a rotation that fails for some other reason just
means tomorrow's scheduled run tries again, and the app is unaffected
in the meantime. The remaining thing that actually needs building is
visibility, so a rotation that keeps failing doesn't go unnoticed for
weeks. This app's CircleCI config deliberately uses no orbs (see the
comment at the top of `.circleci/config.yml`), so the fit here is one
of CircleCI's own native, non-orb options rather than the community
`circleci/slack` orb: personal email notifications (each CircleCI
user can turn these on for themselves under their own account
settings, no project config needed), or a project-level webhook
(**Project Settings → Webhooks**) posting to wherever this team
already watches for alerts, if anywhere does today. Which of those
fits depends on what alerting this team already has, so that choice
is left to whoever sets up the triggers above rather than fixed here.

#### Manual rotation (incident response)

For a suspected exposure that can't wait for the next scheduled run,
rotate manually:

~~~sh
heroku pg:credentials:rotate --app $APP
~~~

## Incident Response

If a secret is believed to be exposed,
**immediately** rotate the affected credential(s)
using the procedure(s) above:

* For `SECRET_KEY_BASE` exposure: rotate it to invalidate all sessions
  and remember-me tokens.
* For `EMAIL_ENCRYPTION_KEY` exposure: rotate using the rekey procedure;
  consider notifying affected users per the security policy in `SECURITY.md`.
* For `HEROKU_API_KEY` exposure: revoke the old authorization via
  `heroku authorizations:revoke` before issuing a replacement.
* For OAuth credentials: revoke the old secret in the GitHub app settings
  before deploying the new one.

Once done, document the incident and review access logs.

For reporting security vulnerabilities in the BadgeApp itself,
see `SECURITY.md`.

For more about how we maintain security in general,
see the assurance case.

## Development and Test Environments

Development uses throwaway keys in `.env.local` (gitignored).
The test environment uses hardcoded test keys defined in
`app/models/user.rb` (`TEST_EMAIL_ENCRYPTION_KEY`,
`TEST_EMAIL_BLIND_INDEX_KEY`) and never reads production environment
variables.

The `.env` file in the repository contains credentials for a
GitHub OAuth test application only; those credentials are safe to
commit because the application is restricted to local test callbacks
and the accounts have no access to real data.
See `docs/testing.md` for details.
