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
The one exception is `HEROKU_API_KEY`, which is stored in the
CircleCI `heroku-deploy` context and is used only by the CI/CD pipeline
to deploy the app automatically when staging or production testing passes.

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
- **CircleCI**: `HEROKU_API_KEY`, stored in the `heroku-deploy` context
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
| `EMAIL_BLIND_INDEX_KEY` | PBKDF2-HMAC-SHA256 blind index for privacy-preserving email search | See [Rotating email keys](#rotating-email-encryption-keys) below |
| `BADGEAPP_BADPWKEY` | HMAC-SHA512 key protecting the bad-password database | See [Rotating BADGEAPP_BADPWKEY](#rotating-badgeapp_badpwkey) below |
| `GITHUB_KEY` | GitHub OAuth application client ID | Rotate via GitHub OAuth app settings; redeploy |
| `GITHUB_SECRET` | GitHub OAuth application client secret | Rotate via GitHub OAuth app settings; redeploy |
| `FASTLY_API_KEY` | Fastly CDN cache purge API key | See [Rotating Fastly credentials](#rotating-fastly-credentials) below |
| `FASTLY_SERVICE_ID` | Identifies the Fastly service to purge | Changes only if the CDN service is recreated |
| `BADGEAPP_SEND_EMAIL_ADDRESS` | Sender email address (the From: address) | Update when changing email provider |
| `BADGEAPP_SEND_EMAIL_USERNAME` | SMTP relay authentication username | Rotate via email provider dashboard; update Heroku config var |
| `BADGEAPP_SEND_EMAIL_PASSWORD` | SMTP relay authentication password | Rotate via email provider dashboard; update Heroku config var |
| `HEROKU_API_KEY` | Heroku API token used by CircleCI to deploy and manage the app | See [Rotating the CircleCI deploy token](#rotating-the-circleci-deploy-token) below |
| `DATABASE_URL` | PostgreSQL connection string (set by Heroku automatically) | Managed by Heroku; rotated via `heroku pg:credentials:rotate --app $APP` |

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

# Capture the current encryption key before replacing it.
OLD_ENC_KEY=$(heroku config:get EMAIL_ENCRYPTION_KEY --app $APP)

# Install the new keys, keeping the old one available for the rekey task.
heroku config:set \
  EMAIL_ENCRYPTION_KEY_OLD=$OLD_ENC_KEY \
  EMAIL_ENCRYPTION_KEY=$NEW_ENC_KEY \
  EMAIL_BLIND_INDEX_KEY=$NEW_IDX_KEY \
  --app $APP

# Re-encrypt all user email addresses (takes a few minutes; safe to re-run).
# This processes every email address in turn, decrypting the email addresses
# using the old key EMAIL_ENCRYPTION_KEY_OLD, then
# encrypting using the new key EMAIL_ENCRYPTION_KEY. It
# noisily skips those addresses that failed to decrypt.
heroku run rake rekey --app $APP

# Remove the old key once rekey completes successfully.
heroku config:unset EMAIL_ENCRYPTION_KEY_OLD --app $APP

# Bring the site back online.
heroku maintenance:off --app $APP
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
heroku run rake update_bad_password_db --app $APP
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
CircleCI `heroku-deploy` context.
It is used both by the Heroku CLI (maintenance mode, migrations) and by
`git push heroku` (via `~/.netrc`) during every deployment.
If this key is exposed it needs to be rotated *immediately*; someone
with this token could deploy their own app to our site instead.

To rotate it:

1. Generate a new scoped Heroku API token (do not use the account-wide
   "Regenerate API Key" in the Heroku dashboard — that invalidates all
   tools using that Heroku account's key):

   ~~~sh
   heroku authorizations:create --description "CircleCI deploy token"
   # Note the token value printed; you will need it in the next step.
   ~~~

2. Update the CircleCI `heroku-deploy` context with the new token value:
   - Open **CircleCI → Organization Settings → Contexts → heroku-deploy**.
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
heroku run rake fastly:purge_all --app $APP
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
