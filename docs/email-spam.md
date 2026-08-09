# Email Spam Investigation 2026-05-14

<!-- SPDX-License-Identifier: (MIT OR CC-BY-3.0+) -->

AWS reported an unusually large number of spam complaints originating
from the BadgeApp email system. This document records the investigation,
findings, and recommended mitigations.

## Background: Emails the system sends

The system sends the following emails to end users:

- **Account activation** (`UserMailer#account_activation`): sent when a
  local account is created, before the owner of the address confirms
  anything.
- **Password reset** (`UserMailer#password_reset`): sent when a password
  reset is requested for a local account.
- **User update** (`UserMailer#user_update`): sent when account details
  change; if the email address itself changes, sent to *both* the old
  and new address.
- **GitHub welcome** (`UserMailer#github_welcome`): sent when a GitHub
  OAuth account is created.
- **New project** (`ReportMailer#email_new_project_owner`): sent when a
  project entry is created.
- **Reminder** (`ReportMailer#email_reminder_owner`): sent periodically
  to owners of in-progress projects that have been inactive.
- **Badge gained/lost/warned** (`ReportMailer#email_owner_with_user`,
  `warn_owner_with_user`): sent when a project's badge status changes or
  is at risk.

## Recently fixed cause

Activation links previously worked via GET, allowing an attacker to
silently activate an account by embedding the link in an image or
similar. This was fixed by requiring POST for activation, so that
forged activations no longer work. However, this fix did not stop
the activation *email* from being sent in the first place.

## Data-driven investigation (as of 2026-05-14)

### Local account counts

The system had 37,108 local (password-based) accounts:

| Status         | Count  | Percent |
|----------------|--------|---------|
| Activated      | 2,676  |   7.2%  |
| Never activated| 34,432 |  92.8%  |

92.8% of local accounts were never activated. Each created account
sends one activation email to whatever address was provided at signup.
This means roughly 34,000 unsolicited activation emails were sent to
addresses that never requested them.

### Password resets on never-activated accounts

Of 3,250 local accounts with a pending password reset digest:

| Account state    | Count |
|------------------|-------|
| Never activated  | 3,122 |
| Activated        |   128 |

3,122 never-activated accounts also had a password reset requested.
The password reset controller does not check whether an account is
activated before sending the reset email, so victims whose addresses
were used to create fake accounts may have received *two* unsolicited
emails: an activation notice and a password reset.

### Reminder and new-project emails: ruled out

Only 1 never-activated account had any associated project. Reminder
emails and new-project emails are therefore negligible contributors to
the spam problem.

## Conclusions

The data suggests two related attack patterns:

1. **Fake registration attack (dominant cause):** A bot creates local
   accounts using real people's email addresses. Each registration fires
   an activation email at the victim. With ~34,000 such accounts, this
   is likely the overwhelming source of spam complaints.

2. **Password reset amplification (secondary cause):** The same actor
   (or another) then requests password resets on those fake accounts,
   generating a second email to each victim. The password reset flow
   does not gate on account activation status, enabling this doubling.

Causes initially considered but effectively ruled out by the data:

- Reminder emails to abandoned accounts (negligible: only 1
  never-activated account had a project)
- New-project welcome emails on fake accounts (same reason)
- User-update emails to old addresses (no data suggesting this at scale)

## Recommended mitigations

In rough priority order:

1. **Block password resets for unactivated accounts.** The password reset
   controller should check `activated?` and silently skip sending if the
   account has never been activated. This eliminates the second-email
   amplification immediately with minimal risk.

2. **Rate-limit or CAPTCHA account creation.** The current
   `RATE_SIGNUP_IP_LIMIT` (default 20 per period) is ineffective against
   distributed bots. A CAPTCHA at signup, or a stricter per-IP limit,
   would reduce fake registrations at the source.

3. **Suppress or delay activation emails for suspicious signups.**
   Consider not sending the activation email immediately, or not at all
   until some secondary signal (e.g., a confirmation that the browser
   loaded the "check your email" page) confirms the request was
   human-initiated.

4. **Purge never-activated local accounts after a timeout.**
   Accounts that were never activated after N days (e.g., 7 days) are
   almost certainly fake. Deleting them stops any further email
   (reminders, resets) from reaching those addresses, reduces the
   attack surface, and cleans up 34k+ stale records immediately.

## Implementation plans for mitigations

### Implementation plan for mitigation 1

 **File to change:**
 `app/controllers/password_resets_controller.rb`, private method
 `email_reset_password` (lines 84–95).

 The method already has two early-return guards:

 ```ruby
 return unless user.provider == 'local'
 return if reset_password_too_soon?(user.reset_sent_at)
 ```

 Add a third guard immediately after the provider check:

 ```ruby
 return unless user.activated?
 ```

 This is the right place because `email_reset_password` is the single
 choke-point through which all password reset emails flow. The `create`
 action already silently succeeds regardless of whether a user was found
 (to avoid email-enumeration attacks), so this change introduces no new
 information leakage — external behaviour is identical whether the account
 does not exist, is a GitHub account, is unactivated, or was reset too
 recently.

 **Tests to add:**

 *`test/controllers/password_resets_controller_test.rb`*

 The fixture `users(:test_user_not_active)` already exists with
 `activated: false` and a valid encrypted email address
 (`forgetful@example.com`). Add a test in the existing
 `PasswordResetsControllerTest` class that verifies:

- POSTing to `/en/password_resets` with that email sends **no** email
  (`ActionMailer::Base.deliveries.size` stays 0).
- The response is still a redirect to `root_url` with the same flash
  message as a successful reset, confirming no distinguishable
  behaviour leak.

 ```ruby
 test 'password reset silently skipped for unactivated account' do
   unactivated = users(:test_user_not_active)
   post '/en/password_resets',
        params: { password_reset: { email: unactivated.email } }
   assert_equal 0, ActionMailer::Base.deliveries.size
   assert_redirected_to root_url
   follow_redirect!
   assert_includes @response.body, 'Email sent with password reset'
 end
 ```

 *`test/integration/password_resets_test.rb`*

 The existing `'password resets'` integration test checks that an
 inactive user cannot use the *edit* (GET) path (lines 44–50), but
 does not test the *create* (POST) path for an unactivated account.
 Add a case in the POST section verifying no email is delivered:

 ```ruby
 # Unactivated account - no email should be sent
 unactivated = users(:test_user_not_active)
 post password_resets_path,
      params: { password_reset: { email: unactivated.email }, locale: :en }
 assert_equal 0, ActionMailer::Base.deliveries.size
 assert_redirected_to root_url(locale: :en)
 ```

 This test must run *before* any delivery count is incremented by the
 valid-email case later in the same test, or `deliveries` must be
 checked as a relative delta.

### Implementation plan for mitigation 4

 **Overview:** Add a `User.purge_unactivated_accounts` class method,
 wire it into the existing `daily` rake task, and add a migration for
 the supporting index. WARNING: Only purge unactivated accounts if they
 own no projects.

 **1. Migration — new file**
 `db/migrate/YYYYMMDDHHMMSS_add_index_users_local_created_at.rb`

 Add a partial index on `created_at` covering only local accounts.
 This is consistent with the existing `email_local_unique_bidx` partial
 index (`WHERE provider = 'local'`) and lets PostgreSQL satisfy the
 purge query — `WHERE provider = 'local' AND activated = false AND
 created_at < ?` — with an efficient range scan rather than a full
 table scan.

 ```ruby
 class AddIndexUsersLocalCreatedAt < ActiveRecord::Migration[8.0]
   def change
     add_index :users, :created_at,
               where: "provider = 'local'",
               name: 'index_users_on_created_at_local'
   end
 end
 ```

 **2. `app/models/user.rb` — add constant and class method**

 Near the other ENV-driven constants at the top of the class, add:

 ```ruby
 UNACTIVATED_ACCOUNT_LIFETIME = Integer(
   ENV['BADGEAPP_UNACTIVATED_USER_DAYS'] || 7, 10
 ).days
 ```

 Then add the class method (public, so the rake task can call it
 directly without `send`, consistent with `Project.send_loss_notifications`):

 NOTE: This code would even destroy accounts that own or have
 additional rights to a project.
 MODIFY this code, before inclusion, to exclude user accounts that
 own or have additional rights to a project.

 ```ruby
 # Delete local accounts that were never activated and are older than
 # UNACTIVATED_ACCOUNT_LIFETIME. Returns the count of deleted users.
 # Dependent :destroy on projects and additional_rights ensures
 # cascades are handled by Rails callbacks.
 def self.purge_unactivated_accounts
   cutoff = UNACTIVATED_ACCOUNT_LIFETIME.ago
   scope = where(provider: 'local', activated: false)
             .where('created_at < ?', cutoff)
   count = scope.count
   scope.find_each(&:destroy)
   count
 end
 ```

 `find_each` avoids loading all ~34k records into memory at once.
 Individual `destroy` calls (rather than `delete_all`) are required
 because `User has_many :projects, dependent: :destroy` and
 `has_many :additional_rights, dependent: :destroy` — Rails callbacks
 must run to maintain integrity.

 **3. `lib/tasks/default.rake` — wire into `daily` task (line ~983)**

 The `daily` task currently is:

 ```ruby
 task daily: :environment do
   ProjectStat.create!
   day_for_monthly = ...
 end
 ```

 Add the purge call after `ProjectStat.create!`:

 ```ruby
 puts 'Purging never-activated local accounts.'
 puts "Purged #{User.purge_unactivated_accounts} never-activated account(s)."
 ```

 **Tests to add — `test/models/user_test.rb`**

 Add four cases covering the key boundaries. All require creating
 records with an explicit `created_at` in the past; use
 `User::UNACTIVATED_ACCOUNT_LIFETIME` so the tests stay correct if the
 constant changes.

 ```ruby
 test 'purge_unactivated_accounts removes old unactivated local accounts' do
   old_unactivated = User.create!(
     name: 'Bot', provider: 'local', activated: false,
     # ... required fields (email, password_digest, preferred_locale) ...
     created_at: (User::UNACTIVATED_ACCOUNT_LIFETIME + 1.day).ago
   )
   User.purge_unactivated_accounts
   assert_not User.exists?(old_unactivated.id)
 end

 test 'purge_unactivated_accounts keeps recently created unactivated accounts' do
   new_unactivated = User.create!(
     name: 'New Bot', provider: 'local', activated: false,
     created_at: 1.hour.ago, ...
   )
   User.purge_unactivated_accounts
   assert User.exists?(new_unactivated.id)
 end

 test 'purge_unactivated_accounts keeps old activated local accounts' do
   old_activated = users(:test_user)  # activated: true in fixture
   User.purge_unactivated_accounts
   assert User.exists?(old_activated.id)
 end

 test 'purge_unactivated_accounts does not touch github accounts' do
   old_github = users(:github_user)  # provider: 'github' in fixture
   User.purge_unactivated_accounts
   assert User.exists?(old_github.id)
 end
 ```

 The existing fixture `test_user_not_active` (`activated: false`,
 `provider: 'local'`) has no explicit `created_at`, so it will be
 created at the time tests run and will be *newer* than the cutoff —
 it should survive the purge, which the second test above also
 implicitly verifies.

### Mitigation 2 and 3

We may implement these later, we're discussing options with IT.
