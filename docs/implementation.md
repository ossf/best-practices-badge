# Implementation

<!-- SPDX-License-Identifier: (MIT OR CC-BY-3.0+) -->

We have implemented a simple web application called "BadgeApp" that
quickly captures self-assertion data, evaluates criteria automatically
when it can, and provides badge information.
Our emphasis is on keeping the program relatively *simple*.

This file provides information on how it's implemented, in the hopes that
it will help people make improvements.
Many of these sections are notes on how to repeat some task in the future,
or notes that may help future changes.
This document is named "implementation", but it also covers verification
issues (including testing).

See also [requirements.md](../requirements.md) and [design.md](../design.md).
See [CONTRIBUTING.md](../CONTRIBUTING.md) for information on how to
contribute to this project, and [INSTALL.md](INSTALL.md) for information
on both how to install this software (e.g., for development) and a
"quick start" guide to getting something to happen.

If you have the privilege to access the production database directly,
or any copy of it, be especially careful about protecting it.
We want to ensure we comply with various laws about user privacy,
including the EU General Data Protection Regulation (GDPR).

In this document we'll use the term "open source software" (OSS),
and treat Free/Libre and Open Source Software (FLOSS) as a synonym.

## Running locally

Once your development environment is ready, you can run the application with:

~~~~
rails s
~~~~

This will automatically set up what it needs to, and then run the
web application.
You can press control-C at any time to stop it.

Then point your web browser at "localhost:3000".

## Environment variables

The application is configured by various environment variables:

* SYSTEM_ANNOUNCEMENT and SYSTEM_ANNOUNCEMENT_locale : Show these
  system-wide announcements (e.g., to announce a soon-to-occur shutdown)
* PUBLIC_HOSTNAME (default 'localhost')
* RACK_TIMEOUT_SERVICE_TIMEOUT : Seconds before timeout. Default 15,
  30 recommended. See gem "rack-timeout" documentation.
* BADGEAPP_MAX_REMINDERS (default 2): Number of email reminders to send
  to inactive projects when running "rake reminders".
  This rate limit is best set low to start,
  and relatively low afterwards, to limit impact if there's an error.
* BADGEAPP_MAX_BADGE_LOSS_NOTIFICATIONS (default 10): Maximum number of
  badge-loss notification emails to send per "rake reminders" run.
  These notify owners whose badge was lost due to a criteria change.
  Set higher to drain the queue faster after a criteria update.
* BADGEAPP_MAX_BADGE_WARNING_NOTIFICATIONS (default 10): Maximum number of
  advance-warning emails to send per "rake reminders" run.
  These warn owners that their badge will be lost when updated criteria
  take effect. See docs/baseline_update.md for the full workflow.
* LOST_PASSING_REMINDER (default 30): Minimum number of days since
  last lost a badge before sending reminder
* LAST_UPDATED_REMINDER (default 30): Minimum number of days
  since project last updated before sending reminder
* LAST_SENT_REMINDER (default 60): Minimum number of days since
  project was last sent a reminder
* RAILS_ENV (default 'development'): Rails environment, one of
  'test', 'development', 'fake_production', and 'production'.
  The main/master, staging, and production systems set this to 'production',
  because we want our final test systems to be as
  "most like the real production system as practical".
  See the discussion below about fake_production.
* BADGEAPP_REAL_PRODUCTION: Has a non-empty value (conventionally "true") if
  this is the *true* production system. If not present, we show the user a
  warning that this isn't the production system.
* BADGEAPP_DAY_FOR_MONTHLY: Day of the month to monthly activities, e.g.,
  send out monthly reminders.  Default 5.  Set to 0 to disable monthly acts.
* BADGEAPP_FROM: Email address to send email from.
* FASTLY_CLIENT_IP_REQUIRED: If present, download the Fastly list of
  client IPs, and only let those IPs make requests.  Enabling this
  counters cloud piercing.  This isn't on by default, but the environment
  variables are set on our tiers.
* DB_POOL: Set the number of connections the app can hold to the database.
  This is important for performance on Heroku; see:
  <https://devcenter.heroku.com/articles/concurrency-and-database-connections>.
  If unset, defaults to RAILS_MAX_THREADS + 1 for this app,
  because in addition to every web thread we occasionally fire a task to
  process occasional requests (such as the daily task).
  If RAILS_MAX_THREADS is not set, presume it is 5.
* RAILS_LOG_LEVEL: Rails log level used when RAILS_ENV is either
  "production" or "fake_production". Plausible values are
  "debug", "info", and "warn". Default is "info". See:
  <http://guides.rubyonrails.org/debugging_rails_applications.html>
* EMAIL_ENCRYPTION_KEY: Key to decrypt the stored user email addresses.
  Hexadecimal string, must be 64 hex digits (==32 bytes==256 bits).
  Used by aes-256-gcm (256-bit AES in GCM mode).
* EMAIL_BLIND_INDEX_KEY: Key for blind index created for user email addresses
  (used by PBKDF2-HMAC-SHA256).  Must be 64 hex digits (==32 bytes==256 bits).
* BADGEAPP_BADPWKEY: Key used for additional protection for passwords
  when checking the bad password database. The list of bad passwords
  is converted by HMAC (using SHA-512 and this key) before being stored in
  the database, and the same happens to passwords before the database is
  asked to compare them. We recommend setting this to a cryptographically
  random 512-bit value; you can get that with `openssl rand -hex 128` or
  similar. Then run `rake update_bad_password_db` to load the database
  with the bad password list (it will take a few minutes to load them all).
* BADGEAPP_DENY_LOGIN: If a non-blank value is set ("true" is recommended),
  then no on can log in, no one can create a new account (sign up),
  and no one can do anything that requires being logged (users are always
  treated as if they are not logged in).
  This essentially prevents ANY changes by users (daily statistics
  creates are unaffected).
  From a security POV this is enforced by SessionsController#create (login),
  UsersController#create (create new user/sign up), and
  SessionsHelper#current_user (determine who current logged-in user is).
  Some views disable the login and sign-in display, so that it's more
  obvious to user what is going on.
  This may be a useful mode to enable if there is a serious exploitable
  security vulnerability, that can only be exploited by users who are
  logged in or can appear to log in.  Unlike *completely* disabling the
  site, this mode allows people to see current information
  (such as badge status, project data, and public user data).
  Note that application admins cannot log in, or use their privileges,
  when this mode is enabled.  Only hosting site admins can turn this mode
  on or off (since they're the only ones who can set environment variables).
* RATE_details - a rate limit setting.  Rate limits provide an automated
  partial countermeasure against denial-of-service and
  password-guessing attacks.
  These are implemented by Rack::Attack and have two parts, a
  "LIMIT" (maximum count) and a "PERIOD" (length of period of time,
  in seconds, where that limit is not to be exceeded).
  If unspecified they have the default values specified in
  config/initializers/rack_attack.rb.  These settings are
  (where "IP" or "ip" means "client IP address", and "req" means "requests"):

    - req/ip: RATE_REQ_IP_LIMIT, RATE_REQ_IP_PERIOD
    - logins/ip: RATE_LOGINS_IP_LIMIT, RATE_LOGINS_IP_PERIOD
    - logins/email: RATE_LOGINS_EMAIL_LIMIT, RATE_LOGINS_EMAIL_PERIOD
    - signup/ip: RATE_SIGNUP_IP_LIMIT, RATE_SIGNUP_IP_PERIOD
* FAIL2BAN_details - fail2ban settings (where repeated failures can lead
  to a temporary ban).  This blocks an IP address that is
  repeatedly making suspicious requests.
  After FAIL2BAN_MAXRETRY blocked requests in FAIL2BAN_FINDTIME seconds,
  we block all requests from that client IP for FAIL2BAN_BANTIME seconds.
  A request is blocked if req.path matches the regex FAIL2BAN_PATH.
  The source code includes some plausible defaults in
  "config/initializers/rack_attack.rb"; the production settings
  are not public.  This isn't the same thing as having a *real*
  web application firewall, but it's simple and counters some
  trivial attacks.  This should be coordinated with robots.txt so that
  robots won't be fooled into following a link to a banned page.
* `LOCAL_LOGIN_COOLOFF_TIME` : Time (in seconds) after creating a local
  account before login is permitted. This is an anti-spam measure.
* `BADGE_CACHE_MAX_AGE` : Time (in seconds) badges are cached by the CDN.
  Default 864000 (10 days). Browsers will check the CDN every time it
  wants to serve a badge image. We purge badges every time their
  corresponding project entries are changed.
  NOTE: If a user *directly* views the BadgeApp project entry on our website
  (instead of just requesting the badge image) AND the project entry has
  recently changed, we DO NOT display the "normal" badge image. Instead,
  when showing a project entry that's recently changed, we embed
  a static image that corresponds to the project's *current* status. That way
  we always show the current project status, even if it just changed.
  This eliminates the race conditions caused because it takes time for
  the CDN to distribute updated badge data to all its servers.
* `BADGE_CACHE_STALE_AGE` : Time (in seconds) badges are served by the CDN
  if it can't get a new value from us.
  Default 8640000 (100 days), is forced to be at least 2x`BADGE_CACHE_MAX_AGE`
* `BADGEAPP_SEND_EMAIL_*`: Various environment variables that configure how the
  BadgeApp sends email to an email server (a kind of Mail Transfer Agent (MTA))
  that will then be sent on to others. See `config/environments/production.rb`.
* `BADGEAPP_SEND_EMAIL_ADDRESS`: The domain of the MTA to send email to, e.g.,
   `smtp.sendgrid.net`. Note that this is NOT the email address of the
   *sender* but the domain of the remote mail server (the MTA) that will be
   *receiving* the email and then send it on.
* `BADGEAPP_SEND_EMAIL_PORT`: Port of the MTA. Use one that forces TLS or
   or modify the config file.
* `BADGEAPP_SEND_EMAIL_USERNAME`: Username for logging into the MTA
* `BADGEAPP_SEND_EMAIL_PASSWORD`: Password for logging into the MTA
* `BADGEAPP_SEND_EMAIL_DOMAIN`: Domain to report to the MTA (for HELO)
* `SENDGRID_USERNAME` and `SENDGRID_PASSWORD`: These were once used for sending email,
  but these are *not* used any more.
* `SOLID_QUEUE_IN_PUMA`: If set (recommended value is `true`), the ActiveJob
  backend `solid_queue` is used. Should be set in staging and in production.

You can make cryptographically random values (such as keys)
using "rails secret".  E.g., to create 64 random hexadecimal digits, use:

> rails secret &#124; head -c64 ; echo

This can be set on Heroku.  For example, to change the maximum number
of email reminders to inactive projects on production-bestpractices:

~~~~
heroku config:set --app production-bestpractices BADGEAPP_MAX_REMINDERS=5
~~~~

On Heroku, using config:set to set a value will automatically restart the
application (causing it to take effect).

The TZ (timezone) environment variable is set to ":/usr/share/zoneinfo/UTC"
on all tiers.  We want all logging to be done in UTC (because then moving
the servers has no affect on logs).  Using leading-colon helps performance
on many systems, especially many Rails systems (because it skips
many system calls), and it's easy enough to do.  More information is at
[How setting the TZ environment variable avoids thousands of system calls](https://blog.packagecloud.io/eng/2017/02/21/set-environment-variable-save-thousands-of-system-calls/).
This was implemented with:

~~~~
heroku config:set --app production-bestpractices TZ=:/usr/share/zoneinfo/UTC
~~~~

## Searching user names and emails (for GDPR Requests)

We have a simple ability for system admins to search for user names
and user emails, primarily to support GDPR Requests.
Use as follows:

~~~~
    heroku run --app production-bestpractices rake search_user -- 'NAME' 'EMAIL'
    heroku run --app production-bestpractices rake search_name -- 'NAME'
    heroku run --app production-bestpractices rake search_email -- 'EMAIL'
~~~~

Note that `search_user` is a shorthand to search for `NAME` and then for
`EMAIL`; this is a common case, so it makes sense to do it at once.
Both the name and email searches are case-insensitive.

The name search is LIKE search, so it will list all database names that
contain the searched name. That is, a search for `David` will list all
records that include `David` in the name field. Thus, a name match might
*not* be the person being searched for. Our goal is to minimize the chance
of not detecting someone, but double-check before deleting any matches.

## Security

See the separate
[security](security.md) document for more about security.

## Adding a logo on the home page

It's not hard to add a logo to the home page.
Put the image in "app/assets/images/project-logos-originals",
copy it to "app/assets/images/project-logos" and rescale to 48 pixels high,
and modify the home page text "app/views/static_pages/home.html.erb".

Here's an example of how we got the ZAP logo into the originals
directory:

~~~sh
    cd app/assets/images/project-logos-originals
    wget https://www.owasp.org/images/1/11/Zap128x128.png
    mv Zap128x128.png ZAP.png
    git add ZAP.png
    cp ZAP.png ../project-logos
~~~

Here's how we resized it to the standard height:

~~~sh
    cd ../project-logos
    mogrify -geometry x48 ZAP.png # Rescale to 48 pixel height
    optipng ZAP.png # Minimize number of bytes in file
    git add ZAP.png
    identify ZAP.png # Report width x height
~~~

Modify the home page text "app/views/static_pages/home.html.erb".
Be sure to specify both the width and height (as reported by identify),
otherwise the browser will delay page display until the image loads.

## Changing criteria

Remember: Changing criteria is special, see
[governance](governance.md) for more.

To modify the text of the criteria, edit these files:

- config/locales/en.yml - YAML file that includes criteria and details text
- criteria/criteria.yml - YAML file that includes other criteria information

Note that the file "docs/criteria.md" (which reports the "passing" criteria)
is a *generated* file, generated from those files, and is
automatically regenerated when "rake" is run.
This generated file is checked into git so that it's accessible via GitHub.
The file "docs/other.md" is currently hand-edited; we intend for it to be
automatically generated in the same way, but that isn't true at the
time of this writing.

If you're adding/removing fields (including criteria), be sure to also edit
app/views/projects/\_form.html.erb
(to determine where to display it).
You may also want to edit the README.md file, which includes a summary
of the criteria.

When adding or removing fields, or when renaming
a criterion name, you may need to edit the test creator db/seeds.rb file,
and you will certainly need to create a database migration.
The "status" (met/unmet) is the criterion name + "\_status" stored as a string;
each criterion also has a name + "\_justification" stored as text.
So every add, remove, or rename of a criterion involves changing
*two* fields in the database schema.
Here are the commands, assuming your current directory is at the top level,
EDIT is the name of your favorite text editor, and MIGRATION_NAME is the
logical name you're giving to the migration (e.g., "add_discussion").
By convention, begin a migration name with 'add' to add a column and
'rename' to rename a column:

~~~~sh
    rails generate migration MIGRATION_NAME
    git add db/migrate/*MIGRATION_NAME.rb
    $EDITOR db/migrate/*MIGRATION_NAME.rb
~~~~

Your migration file should look something like this if it adds columns
(where `add_column` takes the name of the table, the name of the column,
the type of the column, and then various options):

~~~~ruby
    # frozen_string_literal: true
    class MIGRATION_NAME < ActiveRecord::Migration
      def change
        add_column :projects, :crypto_alternatives_status, :string,
                   null: false, default: '?'
        add_column :projects, :crypto_alternatives_justification, :text
      end
    end
~~~~

Similarly, your migration file should look something like this
if it renames columns:

~~~~ruby
    # frozen_string_literal: true
    class Rename < ActiveRecord::Migration
      def change
        rename_column :projects,
                      :description_sufficient_status,
                      :description_good_status
        rename_column :projects,
                      :description_sufficient_justification,
                      :description_good_justification
      end
    end
~~~~

In some cases it may be useful to insert SQL commands or do
other special operations in a migration.
See the migrations in the db/migrate/ directory for examples.

**If your migration will change some percentage calculations**,
your `change` operation should `touch` the file `.recalculate`, like this:

~~~~ruby
    def change
        # ....
        touch('.recalculate')
    end
~~~~

This `touch` will cause the CI pipeline deployments to automatically run
`rake update_all_badge_percentages` after the migration, and thus
recalculate projects' percentages.
(We use `touch` to communicate these changes because it's the easiest
way to implement the communication. It's more complicated to invoke
the recalculation directly from the migration, and it's also more flexible
to make sure that migrations by *themselves* don't directly execute
the time-consuming process of recalculating all projects.)

**If your migration will change some percentage calculations**,
make *sure* you run `rake production_to_main` before merging into `main`,
to prevent spurious warnings to projects about them losing badges.

Once you've created the migration file, check it first by running
"rake rubocop".  This will warn you of some potential issues, and
it's much better to fix them early.
(You can't run just "rake", because that invokes "rake test", and
the dynamic tests in "rake test" won't work until you execute
the migration).

You can migrate by running:

~~~~sh
    rake db:migrate
~~~~

If it fails, you *may* need to use "rake db:rollback" to roll it back.

You may also need to modify tests in the tests/ subdirectory, or
modify the autofill code in the app/lib/ directory.

Be sure to "git add" all new files, including any migration files,
and then use "git commit" and "git push".

*Deploying* the update will take some extra steps.
First of all, if your migration adds a new default value, the migration
may take a few minutes, so you may want to warn users ahead-of-time.

Once the migration has completed, if the percentage calculations
may have changed and you forgot to touch `.recalculate` in the migration,
you can manually force the recalculations by doing:

~~~~sh
    heroku run --app APP -- rake update_all_badge_percentages
~~~~

After the site is up and running, if percentagies have been recalculated,
purge the CDN cache:

~~~~sh
    heroku run --app APP -- rake fastly:purge_all
~~~~

## Internationalization (i18n) and localization (l10n)

This application is "internationalized", that is, it allows
users to select their locale, and then presents information
(such as human-readable text) in the selected locale.
If no locale is indicated, 'en' (English) is used.

To learn more about Rails and internationalization, please read the
[Rails Internationalization guide](http://guides.rubyonrails.org/i18n.html).

We can *always* use help in localizing (that is, in providing translations
of text to various locales) - please help!

The directory config/locales/ contains the text for various locales
in YAML format.
The en.yml (English) file is the source file, the rest of the locales
are translations.

Don't store comments in the en.yml file. The YAML format supports comments,
but the reformatter we sometimes use removes comments.

Pluralization is tricky in some languages.
Rails specially handles pluralization when the special field
"count" is used.  It then looks for keys which
in the general case can be {zero, one, two, few, many, other}.
The key "one" isn't necessarily used for just 1 in a language.
For more information, see the Unicode plural rules:
<http://cldr.unicode.org/index/cldr-spec/plural-rules>
<http://www.unicode.org/cldr/charts/latest/supplemental/language_plural_rules.html>
We include keys for the forms we don't use in some languages so that
translation.io will generate the keys in the translation files.
If the required keys are missing, an exception may be raised depending
on the count (this would lead to the inability to display a page).
Sadly, translation.io ignores empty keys. Thus, we can't add empty keys
and leave them untranslated, because then the locales that need the keys
(like Russian) don't have the keys they need for translation.

Here is an example, where "few" and "many" are needed for Russian:

~~~~yml
  projects_count:
    zero: Zero Projects
    one: "%{count} Project"
    few: "%{count} Projects"
    many: "%{count} Projects"
    other: "%{count} Projects"
~~~~

The key "misc.in_javascript.show_met_title" includes "&amp;".
The "&amp;" is escaped by Rails since it's not marked as HTML safe.

We include some entries for testing.
The key "hello" is used in some tests to ensure that we get correct values
for at least some specific keys.
The last entry in en.yml is "last_entry", there for
test purposes so that we can detect
some problems in YAML formatting of this file.
The test suite includes tests that check the value of every string segment
for every locale, including checking for common errors and ensuring that
only acceptable HTML tags and attributes are used.
See [security.md](./security.md) for more information.

### Requesting the locale at run-time

Users indicate the locale via the URL.
The recommended form is at the beginning of that path, e.g.,
<https://www.bestpractices.dev/fr/projects/>
selects the locale "fr" (French) when displaying "/projects".
This even works at the top page, e.g.,
<https://www.bestpractices.dev/fr/>.
It also supports the locale as a query parameter, e.g.,
<https://www.bestpractices.dev/projects?locale=fr>

### Fixing locale data

Almost all locale-specific data is stored in the "config/locales"
directory (one file for each locale, named LOCALE.yml). This data is
automatically loaded by Rails.  A few of the static files are served
directly, with a separate file for each locale;
see the "app/views/static_pages" directory.
If you need to fix a translation, that's where the data is.

### Adding a new locale

We use the translation.io to help us translate text; those results
are later stored in our git repo (so if we stopped using translation.io
we would not lose our completed translations).

To add a new locale so translation can begin:

* Modify file `config/initializers/translation.rb`
  and edit the assignment of `config.target_locales` to add
  the new locale. Be sure to use `-` (dash) and not `_` (underscore)
  if there's a territory, e.g., `zh-CN` and `pr-BR`.
* Modify file "config/locales/en.yml" and look for `locale_name:`;
  add the new locale as a key. Its text should be
  "English name of language / Language's name for itself (LOCALE)".
* Run "rake translation:sync".
  The system will now permit translators to request it.
  You probably need to log into translation.io to add invite the
  translators.

Run "rake translation:sync" occasionally to sync the keys
and get the new translations.  Spotcheck the new translation work.

It's best if translators prioritize the translations for the front
page first.  On the left-hand side of the screen, to the right of
the word "Filters", is a text box.  Use that to search for the keys
“static_pages.home.”, “layouts.” and "locale_name." - and
translate those.  Once those are done, the front page would be
(essentially) translated.

To make it possible to *select* a new language (after non-trivial
translation has gone on):

* Modify the file `config/initializers/i18n.rb`
  and edit the assignment of `I18n.available_locales` to add
  the new locale.  The system will now permit users to request it.
* Update app/assets/javascripts/criteria.js.erb
  to depend on the new locale's yml file, this allows the precompiler to be
  to be notified if the contents of criteria.js should have changed.
  (note the hyphen vs. dash difference here).
  Simply add the following line to the top of criteria.js.erb:

~~~~
    depend_on NEW_LOCALE.yml
~~~~

Note that the robots.txt automatically prevents crawling of
user accounts in every locale, per `app/views/static_pages/robots.text.erb`.

### Old approaches for handling locales directly (not used)

Here are notes if you change the system to stop using
current support mechanisms, and switch back to older approaches.
The text in this section does not currently apply.

We use the translation.io service.  You don't have to.
You could instead create a stub locale file in the
"config/locales" directory named LOCALE.yml.  A decent way to start is:

~~~~
cd config/locales
cp en.yml NEW_LOCALE.yml
~~~~

Edit the top of the file to change "en:" to your locale name.

Now the hard part: actually translating.
Edit the '.yml' (YAML) file to create the translations.
As always, you need to conform to YAML syntax.
For example,
strings that end in a colon (":") *must* be escaped (e.g., by
surrounding them with double-quotes).
Keys are *only* in lower case and never use dash (they use underscore).

However, we find using a translation service to be easier.

At one time we suggested going to this page to get locale information
for Rails built-ins, and including that:
<https://github.com/svenfuchs/rails-i18n/blob/master/rails/locale/>
However, we now include the gem 'rails-i18n', and that provides
the same kind of functionality while being easier to maintain.

At one time we had to create new static pages in
"app/views/static_pages/" for new locales, but that is no longer needed.

### Programmatically accessing a locale

To learn more about Rails and internationalization, please read the
[Rails Internationalization guide](http://guides.rubyonrails.org/i18n.html).

Inside views you can use the 't' helper, e.g.,

~~~~
    <%= t('hello') %>
    <%= t('.current_scope') %>
~~~~

Inside other code (e.g., in a flash message), use `I18n.t`:

~~~~
    I18n.t 'hello'
~~~~

You can access 'I18n.locale' to see the current locale's value
(this is a thread-local query, so this works fine when multiple
threads are active).

### Canonical URLs

We try to always refer to canonical URL forms.
In some cases that can help search engine rankings, and in any case
it's easier to understand.
Rails' built-in "path" and "url" helpers add a trailing slash
if it is at the root without locale (e.g., "https://x.com/"),
but otherwise they do not add a trailing slash.
We accept a locale setting in the query string, but we prefer to generate
locales in the path (e.g., "https://x.com/en", not "https://x.com?locale=en").

## App authentication via GitHub

The BadgeApp needs to authenticate itself through OAuth2 on
GitHub if users are logging in with their GitHub accounts.
It also needs to authenticate itself to get repo details from GitHub if a
project is being hosted there.
The app needs to be registered with GitHub[1] and its OAuth2 credentials
stored as environment variables.
The variable names of Oauth2 credentials are "GITHUB_KEY" and "GITHUB_SECRET".
If running on heroku, set config variables by following instructions on [2].

If you need to set this up for your own instance, go to
<https://github.com/settings/applications/new>
to "Register a new OAuth application" and create a corresponding new token.
Here's how we created the "staging" token for staging.bestpractices.dev:

* Application Name: Best Practices Badge (Staging)
* Homepage URL: https://staging.bestpractices.dev
* Authorization callback URL: https://staging.bestpractices.dev/auth/github/callback
* We enabled "device flow" because it might be useful someday.

Similarly, here are the settings for the
"production" token for www.bestpractices.dev:

* Application Name: Best Practices Badge
* Homepage URL: https://www.bestpractices.dev
* Authorization callback URL: https://www.bestpractices.dev/auth/github/callback
* We enabled "device flow" because it might be useful someday.

You can see the status of these tokens on GitHub here:
<https://github.com/settings/developers>
under "OAuth applications".

If running locally, these variables need to be set up.
We have set up a file '.env' at the top level which has stub values,
formatted like this, so that it automatically starts up
(note that these keys are *not* what we used for the deployed systems,
for obvious reasons):

~~~~sh
export GITHUB_KEY = '..VALUE..'
export GITHUB_SECRET = '..VALUE..'
~~~~

You can instead provide the information this way if you want to
temporarily override these:

~~~~sh
GITHUB_KEY='client id' GITHUB_SECRET='client secret' rails s
~~~~

where *client id* and *client secret* are registered OAuth2 credentials
of the app.

The authorization callback URL in GitHub for this dummy application is:
<http://localhost:3000/auth/github>

[1] <https://github.com/settings/applications/new>
[2] <https://devcenter.heroku.com/articles/config-vars>

## Changing the owner of a project entry

We have a rake task to simplify changing the owner of a project.
Given project number PROJECT and new owner user id OWNER,
you can do this remotely with:

~~~~
heroku run --app production-bestpractices rake change_owner -- PROJECT OWNER
~~~~

You can also do this with a SQL command but an error in the SQL command
(such as forgetting the WHERE clause) can cause a big problem.
The rake task `change_owner` is more convenient, e.g., it prints
the project name, prints old and new owner names, prevent some errors,
and so on. Neverthess it is fundamentally the same as this SQL command:

~~~~
echo "UPDATE projects SET user_id = {OWNER_NUM} WHERE id = {PROJECT_NUM}" | \
  heroku pg:psql DATABASE_URL --app production-bestpractices
~~~~

## Database content viewing and editing

In some cases you may need to view or edit the database contents directly.
For example, we don't currently have code to set a user to have the
'admin' role,
to backup the database, or restore the database.
Instead, we simply interact with the database software, which
already has the functions to do this.

As always, this require special administrative privileges.
Be careful with the databases, since the include information on users.
We want to ensure we comply with various laws about users, including
EU General Data Protection Regulation (GDPR).

You can directly connect to the database engine and run commands.
On the local development system, run "rails db" as always.
To change the database contents of a production system,
log into that system and use the SQL language to make changes.
E.G., on Heroku, presuming that you have installed the heroku command,
and configured it for the system you are controlling
(including the necessary keys),
you can pipe SQL commands to 'heroku pg:psql'.
This only works if you've been given keys to control this.
On Heroku we use PostgreSQL.
Here are a few examples (replace the "heroku pg:psql..." with "rails db"
to do it locally):

~~~~sh
# Who is user 1?
echo "SELECT * FROM users WHERE users.id = 1" | \
  heroku pg:psql DATABASE_URL --app production-bestpractices
# Find user by name
echo "SELECT * FROM users WHERE name = 'David A. Wheeler'" | \
  heroku pg:psql DATABASE_URL --app production-bestpractices
# List all current web application admins
echo "SELECT id,name FROM users WHERE role = 'admin'" | \
  heroku pg:psql DATABASE_URL -a production-bestpractices
# Give the specified user admin privileges
echo "UPDATE users SET role = 'admin' where id = 25" | \
  heroku pg:psql DATABASE_URL --app production-bestpractices
# Change owner of project, forcibly
echo "UPDATE projects SET user_id = 25 WHERE id = 1" | \
  heroku pg:psql DATABASE_URL --app production-bestpractices
~~~~

You can force-create new users and make them admins
(again, if you have the rights to do so).
To create new github user, first get their github uid from their
github username (nickname) by looking at
<https://api.github.com/users/USERNAME>
and getting the "id" value.
Then run this, replacing all-caps stubs with the values in single quotes
(this will create a local id automatically):

~~~~sh
echo "INSERT INTO users (provider,uid,name,nickname,email,role,activated,
  created_at,updated_at)
  VALUES ('github',GITHUB_UID,FULL_USER_NAME,
  GITHUB_USERNAME,EMAIL,'admin',t,now(),now());" | \
  heroku pg:psql DATABASE_URL --app production-bestpractices
~~~~

You can
[import or export databases on Heroku](https://devcenter.heroku.com/articles/heroku-postgres-import-export)
Those with enough authoritizations can run
"rake pull_production" to copy the current production database
into their development environment for testing;
this will erase the current copy.

For example, here's how to quickly back up the database
(presuming that it's set up for the Heroku site and that you have
the authorization keys to do this):

~~~~sh
heroku pg:backups capture
curl -o latest.dump $(heroku pg:backups public-url)
~~~~

You can use this SQL command to see what projects have
duplicate homepage_url values:

~~~~sql
SELECT id,LEFT(name,20) as name, user_id, homepage_url
FROM projects
WHERE homepage_url <> '' AND homepage_url IN
  (SELECT homepage_url FROM projects GROUP BY homepage_url
   HAVING COUNT(homepage_url) > 1);
~~~~

## Deleting fraudulent project entries

We try to work with people who are trying to do the right thing
but misunderstand something.

However, badge entries can be clearly fraudulent.
For example, they can claim their code does many things without having code,
that their documents cover things yet have no documentation, and so on.
If we are confronted with clear fraud then we simply fix the database,
typically by deleting all the user's project entries and blocking their
user accounts. If it's clearly fraudulent then they're attackers and
we don't give the attackers any warning, there's no need for that.

To block an account we'd do something like this (after backing up the database);
in the `blocked_rationale` include the YYYY-MM-DD date when the block
was created as part of the rationale.

~~~~sh
echo "UPDATE users SET blocked=true, blocked_rationale='...' WHERE id = 13323;"|
  heroku pg:psql DATABASE_URL --app production-bestpractices
echo "DELETE FROM projects WHERE user_id = 13323;" | \
  heroku pg:psql DATABASE_URL --app production-bestpractices
~~~~

## Recovering a deleted or mangled project entry

If you want to restore a deleted project, or reset its values,
we have some tools to help.

Put the project data in JSON form in the file "project.json"
(at the top of the tree, typically in "~/best-practices-badge").
If this was a recent deletion, then you can simply copy the JSON-formatted
data from the email documenting the deletion.

Then run:

~~~~
    rake create_project_insertion_command
~~~~

This will create a file "project.sql" that has SQL insertion command.

You'll next need to delete the project if it already exists, because
it's an insertion command.

Now you need to execute the SQL command on the correct database.
Locally you can do this (you may want to set RAILS_ENV to
"production"):

~~~~
    rails db < project.sql
~~~~

If you want the data to be on the true production site, you'll need
privileges to execute database commands, then run this:

~~~~
    heroku pg:psql DATABASE_URL --app production-bestpractices < project.sql
~~~~

## Server-side data cache store

[Caching with Rails](http://guides.rubyonrails.org/caching_with_rails.html)
discusses the various options for the server-side data cache store.
This can be configured by setting "config.cache_store".

The main options are:

* ActiveSupport::Cache::MemoryStore (:memory_store),
* ActiveSupport::Cache::FileStore (:file_store)
* ActiveSupport::Cache::MemCacheStore (:mem_cache_store)
* ActiveSupport::Cache::RedisCacheStore (:redis_cache_store)

We intentionally use MemoryStore (:memory_store)
with a larger-than-default memory size.
This may seem to be a surprising choice; here's why we do that.

As noted in the Rails documentation for MemoryStore,
"This cache store keeps entries in memory in the same Ruby process...
If you're running multiple Ruby on Rails server processes (which is the
case if you're using Phusion Passenger or puma clustered mode), then your
Rails server process instances won't be able to share cache data with
each other. This cache store is not appropriate for large application
deployments. However, it can work well for small, low traffic sites
with only a couple of server processes..."

The
[MemoryStore documentation](http://api.rubyonrails.org/classes/ActiveSupport/Cache/MemoryStore.html) further explains that it is
"A cache store implementation which stores everything into memory in the
same process. If you're running multiple Ruby on Rails server processes
(which is the case if you're using Phusion Passenger or puma clustered
mode), then this means that Rails server process instances won't be
able to share cache data with each other and this may not be the most
appropriate cache in that scenario. ...
MemoryStore is thread-safe."

In practice, we run as a single process with multiple threads.
MemoryStore is thread-safe, so the threads *can* share the cache store.
MemoryStore is obviously fast, and we can easily configure it to 64MB
with no problems.  This seems to be more than adequate for our
current situation.

We can use alternatives, but must consider how
[Heroku impacts caching strategies](https://devcenter.heroku.com/articles/caching-strategies).

Heroku has an
[ephemeral filesystem](https://devcenter.heroku.com/articles/dynos#ephemeral-filesystem),
so any files written are temporary.
That said, it's no worse than a memory-only cache, and it would be a
valid alternative.

Heroku offers memcached, but the free tiers (when they existed) were
only 25M-30M (smaller
than easily available from memory), and they quickly get expensive
(the next tier up is only 100M).
Redis also gets expensive.

We can always pay for different caching systems.
However, up to this point we haven't needed more than we have
currently configured for.
If we need to increase our server-side cache store
capability, it's a relatively quick purchase and reconfiguration,
with no other code changes.

## Scaling up

This software is designed to scale up as needed.

Up to this point we've only needed a single dyno to run the system.
That may seem surprising, however:

* The main main stress on the system is badge requests,
  and we offload practically all of that work to our CDN.
* We run multiple threads (so we can handle a number of simultaneous requests).
* We aggressively use fragment caching stored in our
  server-side data cache store.
* We ensure that JavaScript and such are set to cache
  on the client side, so are normally sent only once to a given client.

If more is needed, we can just pay for additional dynos, and they
will just work.
The system knows to work with the RDMBS database, PostgreSQL, and PostgreSQL
already scales well.

That said, if we switch to multiple dynos, the configuration of the
ActiveSupport::Cache should probably be changed, e.g., to
MemCached or Redis.
Otherwise the caches won't be shared between the instances.

## Purging Fastly CDN cache

If a change in the application causes any badge level(s) to change or
changes the output of a projects json file,
you need to purge the Fastly CDN cache after pushing.
Otherwise, the Fastly CDN cache will continue to serve the old badge
images as well as project json files (until they time out).

You can purge the Fastly CDN cache this way (assuming you're
allowed to log in to the relevant Heroku app):

~~~~sh
heroku run --app HEROKU_APP_HERE rake fastly:purge
~~~~

This command will use the value of the FASTLY_API_KEY
configured for that Heroku application (Fastly requires authorization
for purging the entire cache)... so you don't have to provide it yourself.

It's safe to purge the cache if you're not sure if you need to do it.
After a cache purge, the next request for each badge will go
to the website, so for a brief time the site will
be busy serving badge files.

## Resetting Heroku plug-ins

Here's how to reset the heroku-local plugin:

~~~~sh
heroku plugins:uninstall heroku-local --app production-bestpractices
heroku plugins --app production-bestpractices
~~~~

The latter automatically reinstalls heroku-local.
This information is from: <https://github.com/heroku/heroku/issues/1690>.

Normally you should just push changes to "master" first, so that
CircleCI will test it.  If you want to push directly to Heroku staging
(and have the necessary rights):

~~~~
git remote add heroku-staging https://git.heroku.com/staging-bestpractices.git
~~~~

Now you can directly deploy to Heroku:

~~~~
git checkout staging
git push heroku-staging staging
~~~~

## Auditing

The intent is to eventually have an "audit" function that
runs auto-fill without actually editing the results, and then
show the differences between the automatic results and the form values.
This will let external users compare things.

## Autofill

The process of automatically filling in the form is called
"autofill".

Earlier discussions presumed that the human would always be right, and
that the automation would only fill in unknowns ("?").
However, we've since abandoned this; instead, in some cases we want
to override (either because we're confident or because we want to require
projects to provide data in a way that we can be confident in it).

Autofill must use some sort of pluggable interface, so that people
can add them.  We will focus on getting data from GitHub, e.g.,
api.gihub.com/repos has a lot of information.
The pluggable interface could be implemented using Service Objects;
it's not clear that's the best way.
We do want to create directories where people can just add new files to
add new plug-ins.

We name each separate module that detects something a "Detective".
A Detective needs to be called, be able to get data, and eventually
return a set of findings.
The findings are a hash with
attributes and findings about them:
(proposed new) value, confidence, and justification (string).

The "Chief" module calls the Detectives in the right order and
merges the results.
Confidence values range from 0..5; confidence values of 4 or higher
override the user input.

## Authentication

Currently we allow people to log in using their GitHub account
or a local account (so people who don't want to use GitHub don't need to).
We trust GitHub's answers about whether or not a user is who they say they
are, and about which GitHub projects they can edit.

Note: In the user interface we use the term "custom account"
instead of "local account" or "local user account" or "local user";
they are all the same thing.  These are accounts
where the user directly logs into the system with a password.

We currently can't be sure if a local user is actually allowed to
edit a given project, but admins can override any claims if necessary.
If this becomes a problem, we could make it possible for a
a project URL page to include the
token (typically in an HTML comment) to prove that a given user is
allowed to represent that particular project.
That would enable projects to identify users who can represent them
without requiring a GitHub account.

Future versions might support sites other than GitHub; the design should
make it easy to add other sites in the future.

We make public the *username* of who last
entered data for each project (generally that would be the GitHub username),
along with the edit time.

## Plans: Who can edit project P?

(This is a summary of the previous section.)

A user can edit project P if one of the following is true:

1. If the user is an "admin" then the user can edit the
  badge information about any project.
  This will let the Linux Foundation fix problems.
2. If project P is on GitHub AND the user is authorized via GitHub
  to edit project P, then that user can edit the badge information about
  project P.  In the future we might add repos other than GitHub, with
  the same kind of rule.
3. If the user created this badge entry, the user can edit it.

## GitHub-related badges

Pages related to GitHub-related badges include:

* <http://shields.io/> - serves files that display a badge
  (as good-looking scalable SVG files)
* <https://github.com/badges/shields> -  Shields badge specification,
  website and default API server (connected to shields.io)
* <http://nicbell.net/blog/github-flair> - a blog post that identifies
  and discusses popular GitHub flair (badges)

We want GitHub users to think of this
as &#8220;just another badge to get.&#8221;

We intend to sign up for a few badges so we can
evaluate their onboarding process,
e.g., Travis (CI automation), Code Climate (code quality checker including
BrakeMan), Coveralls (code coverage), Hound (code style),
Gymnasium (checks dependencies), HCI (looks at your documentation).
For example, they provide the markdown necessary to embed the badge.
See ActiveAdmin for an example, take a few screenshots.
Many of these badges try to represent real-time status.
We might not include these badges in our system, but they
provide useful examples.

## Other badging systems

Mozilla's Open Badges project at <http://openbadges.org/>
is interesting, however, it is focused on giving badges to
individuals not projects.

## CircleCI

The CircleCI build execution is configured to use Ubuntu 14.04 (Trusty);
it was Ubuntu 12.04 (Precise).

## License detection

Some information on how to detect licenses in projects
(so we can perhaps autofill them) can be found in
[&#8220;Open Source Licensing by the Numbers&#8221; by Ben Balter](https://speakerdeck.com/benbalter/open-source-licensing-by-the-numbers).

For the moment, we just use GitHub's mechanism.
It's easy to invoke and resolves it in a number of cases.

## Implementation of Detectives.

The detective classes are located in the directory often located in the directory ./workspace/best-practices-badge/app/lib.  This directory contains all of the detectives and has a very specific naming convention.  All new detectives must be named name1_detective.rb.  This name is important as it will be called by the primary code chief.rb which calls and collects the results of all of the detective classes.

To integrate a new class chief.rb must be edited in the following line.

ALL_DETECTIVES =
  [
    NameFromUrlDetective, ProjectSitesHttpsDetective,
    GithubBasicDetective, HowAccessRepoFilesDetective,
    RepoFilesExamineDetective, FlossLicenseDetective,
    HardenedSitesDetective (Name1Detective)
  ].freeze

  where Name1Detective corresponds to the new class created in name1_detective.  Without following the naming convention chief will not run the new detective.

  A template detective called blank_detective.rb is supplied with the project with internal documentation as to how to use it.

  Remember, in addition to the detective you must right a test in order for it
  to be accepted into the repository.  The tests are located at ./test/unit/lib/
  with an example test of blank_detective included.

## Analysis

We use the ZAP web application scanner to find potential
vulnerabilities.
This lets us fulfill the "dynamic analysis" criterion.

## Setup for deployment

If you want to deploy this yourself, you need to set some things up.
Here we'll presume Heroku.

You need to have email set up.
See the Action mailer basics guide at
<http://guides.rubyonrails.org/action_mailer_basics.html>
and Hartl's Rails tutorial, e.g.:
<https://www.railstutorial.org/book/account_activation_password_reset#sec-email_in_production>

We used to use SendGrid. You *can* just use SendGrid directly.
You can also install sendgrid on Heroku to provide some extra functions doing this:

~~~~sh
heroku addons:create sendgrid:starter
~~~~

If you plan to handle a lot of queries, you probably want to use a CDN.
It's currently set up to use Fastly.

## Badge SVG

The SVG files for badges are:

- <https://img.shields.io/badge/openssf_best_practices-passing-green.svg>
- <https://img.shields.io/badge/openssf_best_practices-in_progress-yellow.svg>
- <https://img.shields.io/badge/openssf_best_practices-failing-red.svg>

## Licenses of the software used by BadgeApp

See CONTRIBUTING.md for the license rules;
fundamentally we require software to be released as OSS
before we can depend on it.

The following components don't declare a license in their Gemfile,
and were researched separately:

* gitlab: URL <https://github.com/NARKOZ/gitlab/blob/master/LICENSE.txt> reveals this to be license BSD-2-Clause.
* colored: URL <https://github.com/defunkt/colored/blob/master/LICENSE> reveals this to be license MIT.

For more on license decisions see docs/dependency_decisions.yml.
You can also run 'rake' and see the generated report
license_finder_report.html.

## HTML link checking

GitHub has relatively recently changed its robots.txt file so
that only certain agents are allowed to retrieve files.
This means that typical link-checking services don't work, since common
services like the W3C's link checker are rejected.

This can be worked around by downloading the W3C link checker,
disabling robots.txt, and running it directly.  You need to be very
careful when doing this.  We'll install the "Linkchecker" package from CPAN
(command name is 'checklink') to do this.  Here's how.

~~~~
cpan /W3C-LinkChecker-4.81/
cpan LWP::Protocol::https # Needed for HTTPS
su
cd /usr/local/bin
cp checklink checklink-norobots

patch -p0 <<END
--- checklink   2016-02-24 10:37:05.000000000 -0500
+++ checklink-norobots  2016-02-24 10:48:24.856983414 -0500
@@ -48,7 +48,7 @@
 use Net::HTTP::Methods 5.833 qw();    # >= 5.833 for 4kB cookies (#6678)

 # if 0, ignore robots exclusion (useful for testing)
-use constant USE_ROBOT_UA => 1;
+use constant USE_ROBOT_UA => 0;

 if (USE_ROBOT_UA) {
     @W3C::UserAgent::ISA = qw(LWP::RobotUA);
END
~~~~

You can then run, e.g.:

~~~~
checklink-norobots -b -e \
  https://github.com/ossf/best-practices-badge | tee results
~~~~

## Spam countering: Markdown, nofollow, and ogc

Spammers may be tempted to create project entries that link to their
websites to subversively expand their incoming link counts.

To counter this, all hypertext links based on user-created data are
marked with
`rel="nofollow ugc"` ("do not follow, user-generated content").
In the markdown text this enforced by not allowing users
to use `<a ...>` as text; they can insert hypertext links, but they
must use Markdown format to do it (which inserts the nofollow relation).
Spammers can still create try to create projects entries
with spammy link references, but this eliminates the incentive to do so.

The `ugc` marking was announced in 2019.
See:
[Evolving “nofollow” - new ways to identify the nature of links (September 10, 2019](https://webmasters.googleblog.com/2019/09/evolving-nofollow-new-ways-to-identify.html).

## Accessing our analysis tools

We have various analyzers.  Here are some hints of how to access them.

If you don’t install the software, then you can use our REST interface
– create a project & then query what we’ve learned.  That only
provides *some* functionality.

If you *install* software, then there are many more options.  The software
was designed to be used as a website, so you can still use it that way,
but then you can also directly invoke the functionality you want via
Ruby and Rails.  It’s easy to integrate as a CLI that way.

We’re big on testing, for example, we have 100% statement coverage.
A side-effect of this is that a lot of functionality can be called
separately (so it can be tested).  You can also look at our tests to see
how to invoke something internally.  In particular, we have a number of
tools that try to gather data about a project – each one is called a
“Detective”, and they are managed by a “Chief” of Detectives.
Here’s a quick example that may help:

~~~~ruby
# Start up
rails console
p = Project.new
# Set values for project to evaluate.  We'll examine our own project.
p[:repo_url] = 'https://github.com/ossf/best-practices-badge'
p[:homepage_url] = 'https://github.com/ossf/best-practices-badge'
# Setup chief to analyze things:
new_chief = Chief.new(p, proc { Octokit::Client.new })
# Ask chief to find probable values:
results = new_chief.autofill

# Now "results" shows the fields found.
# For each field it has a value, confidence, and explanation.
# In addition, "p" is changed where we have high confidence.
results.keys
# => [:name, :sites_https_status, :repo_public_status, :repo_track_status,
# :repo_distributed_status, :contribution_status, :discussion_status,
# :license, :repo_files, :license_location_status, :release_notes_status,
# :floss_license_osi_status, :floss_license_status, :hardened_site_status,
# :build_status, :build_common_tools_status, :documentation_basics_status]
results[:name]
# => {:value=>"Core Infrastructure Initiative Best Practices Badge",
# :confidence=>3, :explanation=>"GitHub name"}
results[:license]
# => {:value=>"MIT", :confidence=>3,
# :explanation=>"GitHub API license analysis"}
p[:name]
# => "Core Infrastructure Initiative Best Practices Badge"
~~~~

## Forbidden Passwords

[NIST has proposed draft password rules in 2016](https://nakedsecurity.sophos.com/2016/08/18/nists-new-password-rules-what-you-need-to-know/).
They recommend having a minimum of 8 characters in passwords and
checking against a list of bad passwords.
Here we'll call them forbidden passwords - they are forbidden because
they're too easy to guess.

Here's how to recreate the bad-passwords list.
It's derived from the skyzyx "bad-passwords" list, which is dedicated
to the public domain via the CC0 license.

We create a modified version of the original source material.
We don't need to store anything less than 8 characters
(they will be forbidden anyway), and we only store lowercase versions
(we check downcased versions).
We compress it into a .gz file; it doesn't take long to read, and that greatly
reduces the space we use when storing and and transmitting the program.
Using the bad-passwords version dated "May 27 11:03:00 2016 -0700",
starting with the "mutated" list, we end up with 106,251 forbidden passwords.

~~~
(cd .. && git clone https://github.com/skyzyx/bad-passwords )
cat ../bad-passwords/raw-mutated.txt | grep -E '^.{8}' | tr A-Z a-z | \
  sort -u > raw-bad-passwords-lowercase.txt
rm -f raw-bad-passwords-lowercase.txt.gz
gzip --best raw-bad-passwords-lowercase.txt
~~~~

At one time we loaded bad passwords into memory, but because of object
overheads it consumed over 8MB of RAM *and* it fragments memory.
The list is only consulted when a local password is being (re)set,
so it made more sense to move the list to the database at runtime.
Thus, after the updated bad-passwords file is sent, you need to have
it update the database for use. Do this by running:

~~~~sh
    heroku run --app APP rake update_bad_password_db
~~~~

## Installing CircleCI / Heroku keys

We use CircleCI to push to Heroku once it passes all tests, but
CircleCI must prove it's authorized to Heroku that this is authorized.
Heroku [uses API keys to do this](https://help.heroku.com/PBGP6IDE/how-should-i-generate-an-api-key-that-allows-me-to-use-the-heroku-platform-api).
To recreate such keys, use `heroku authorizations:create` for production apps, and use `heroku auth:token` for development. Each token has a secret value and an "id" that is used to identify it.
If CircleCI is broken in to, you need to change the Heroku keys and GitHub
keys stored on CircleCI. Heroku calls this key rotation.

To replace an existing Heroku key on CircleCI, that is, the Heroku OAuth token, take the following steps.

First, find the ID of "Long-lived user authorization" using:

> heroku authorizations

Use the ID you find (a dash-separated sequence of hexadecimal numbers) and
rotate the key:

> heroku authorizations:rotate ID-GOES-HERE

After rotation it will show the secret Token value (another dash-separated
sequence of hexadecimal numbers). Log in to CircleCI,
select the best-practices-badge application, Project Settings,
Environment Variables, and change the value of
`HEROKU_API_KEY` to the secret token value (*not* the token ID).

The CircleCI interface is a little confusing on this point because there's
no obvious way to edit a value, but fear not - just select
*Add Environment Variable* with the *current* name of the environment
variable (e.g., `HEROKU_API_KEY`) and a new value, and the environment
variable's value will be replaced.

Note that `heroku authorizations --help` will provide more info on Heroku
authorization commands.

We also use RSA keys.
See [keys](https://devcenter.heroku.com/articles/keys) for details.
At the time of this writing Heroku only supports RSA keys.

Basically, create an OpenSSH keypair:

~~~~
      ssh-keygen -t rsa -f "$HOME/.ssh/id_rsa_bp" \
                 -C 'dwheeler@linuxfoundation.org'
~~~~

Per the Heroku instructions, add the public key here:

~~~~
    heroku keys:add "$HOME/.ssh/id_rsa_bp.pub"
~~~~

CircleCI needs to prove it's authorized, so we need to give it the
private key (sigh). Go to this page:
https://app.circleci.com/settings/project/github/ossf/best-practices-badge/ssh

Under "Additional SSH keys" (for keys to the builid VMs that you need to
deploy to your machines), remove any heroku.com keys, add a new key
with hostname "heroku.com", and provide the contents of the private key
`$HOME/.ssh/id_rsa_bp`.

Since these aren't used for any other purpose, it's safest to remove
these keys from anywhere else:

~~~~
    rm "$HOME/.ssh/id_rsa_bp*"
~~~~

## Project stats omission on 2017-02-28

The production site maintains a number of daily statistics and can
[display the statistics graphically](https://www.bestpractices.dev/project_stats), but it is
missing a report for 2017-02-28.
This was due to a multi-hour downtime in
Amazon’s S3 web-based storage service, part of
Amazon Web Services (AWS), which took a large number of sites
(not just ours).
For more information you can see the story in
[USA Today](https://www.usatoday.com/story/tech/news/2017/02/28/amazons-cloud-service-goes-down-sites-scramble/98530914/),
[Zero Hedge](http://www.zerohedge.com/news/2017-02-28/amazon-cloud-reporting-increased-error-rates-secgov-possibly-impacted),
and
[Tech Crunch](https://techcrunch.com/2017/02/28/amazon-aws-s3-outage-is-breaking-things-for-a-lot-of-websites-and-apps/).

## fake_production

If you want to debug a problem that only appears in a production-like
environment, try the 'fake_production' environment.
Here is how to enable it:

~~~~
RAILS_ENV=fake_production rails s
~~~~

This environment is almost exactly like production, with the
following differences:

* does not force HTTPS (TLS), so you can interact with it locally
* enables byebug so that you can insert breakpoints
* disables timeouts, so that you aren't rushed trying
  to track down a problem before the timeout ends.

Other environment variables might be usefully set in the command prefix,
such as "DATABASE_URL=development".

## Natural Language Translation

The primary text for the application is in English, and the English text
presented to users is stored in "config/locales/en.yml".

To send the English text to the translators for other languages, and
copy those translations into the "config/locales" directory, run:

~~~~sh
    rake translation:sync
~~~~

## Cleaning up development environment storage space

If you develop for a period of time within an environment,
you may start to run short of storage space.
If so, here are some steps you can take:

### Remove old logs

The file log/test.log, in particular, gets huge if you
routinely run tests locally.

~~~~sh
    rm log/*.log
~~~~

### Remove cached packages (if Debian/Ubuntu based)

Debian/Ubuntu systems archive downloaded packages; you can see
the space it takes by running:

~~~~
    du -sh /var/cache/apt/archives
~~~~

To clean the apt cache, run this:

~~~~
    sudo apt-get clean
~~~~

### Remove unused packages (if Debian/Ubuntu based)

~~~~
    sudo apt-get autoremove
~~~~

### Remove Ruby packages for Ruby versions you don't use

~~~~
    rm -fr ~/.rbenv/versions/RUBY_VERSION_YOU_DONT_USE
~~~~

### Reduce git repo size

Running git's garbage collector manually may
give you a few K, but is unlikely to help much,
because git occasionally runs it automatically.
That said, there's no harm in running it, here's how:

~~~~
    git gc
~~~~

git gc's has an "--aggressive" option, but I suggest avoiding it,
as that is almost never what you want.

If you are desperate for space you can make the repo a shallow copy
instead, but then you do not have the full git history.

## API

See [api](api.md) for the application programming interface (API),
including how to download data for analysis.

## Memory quota exceeded

You may see error messages in the executing tiers in the following form:

> heroku/web.1: Error R14 (Memory quota exceeded)

This message is further explained in
[R14 - Memory Quota Exceeded in Ruby (MRI)](https://devcenter.heroku.com/articles/ruby-memory-use).

It simply means that normal memory has been exceeded, and
that slower swap is being used instead.
Services are still operating, just at a slightly lower performance
than desired.
So there is no reason to panic over these messages, but it is
worth trying to fix.

## Reducing Rails memory use (`MALLOC_ARENA_MAX` and `jemalloc`)

Rails is notorious for memory growth over time.
Two ways to partly address this is to (1) set `MALLOC_ARENA_MAX` to 2
or (2) use `jemalloc`.

We partly compensate by setting `MALLOC_ARENA_MAX` to 2, as is
recommended by Heroku.
[See this Heroku discussion](https://devcenter.heroku.com/changelog-items/1683).
Heroku doesn't directly support using `jemalloc`, so the `jemalloc`
alternative would be more work.
It's also somewhat dubious that `jemalloc` would be much better.

Some discussions about this:

* [Taming Rails Memory Bloat](https://www.mikeperham.com/2018/04/25/taming-rails-memory-bloat/)
* [What causes Ruby Memory Bloat?](https://www.joyfulbikeshedding.com/blog/2019-03-14-what-causes-ruby-memory-bloat.html)
* [The status of Ruby memory trimming](https://www.joyfulbikeshedding.com/blog/2019-03-29-the-status-of-ruby-memory-trimming-and-how-you-can-help-with-testing.html)
* [Malloc doubles Ruby memory](https://www.speedshop.co/2017/12/04/malloc-doubles-ruby-memory.html)
* [Benchmark of memory allocators](https://medium.com/@andresakata/benchmark-of-memory-allocators-on-a-multi-threaded-ruby-program-354ec4dc2e7e)

## Known harmless warnings (Ruby 3.4 + Bundler 2.5.x)

When running Ruby 3.4+ with Bundler 2.5.x, you may see harmless warnings like:

```
warning: already initialized constant Gem::Platform::JAVA
warning: previous definition of JAVA was here
```

**Cause**: Bundler 2.5.23 was released before Ruby 3.4 and redefines platform
constants that Ruby 3.4's RubyGems already defines. This is a known
compatibility issue between Bundler 2.5.x and Ruby 3.4's RubyGems 3.7.2.

**Impact**: None. The warnings are cosmetic; the constants have identical
values and functionality is unaffected.

**Solution**: Update to Bundler 2.7.x or later, which is designed for
Ruby 3.4 compatibility:

```bash
gem install bundler --version '~> 2.7.0'
bundle update --bundler
# Update CircleCI Docker images to include Bundler 2.7.x
```

**Note**: We intentionally deferred this Bundler update to separate concerns
from the Ruby 3.4 upgrade. The warnings can be safely ignored until the
Bundler update is performed.

## See also

Project participation and interface:

* [CONTRIBUTING.md](../CONTRIBUTING.md) - How to contribute to this project
* [INSTALL.md](INSTALL.md) - How to install/quick start
* [governance.md](governance.md) - How the project is governed
* [roadmap.md](roadmap.md) - Overall direction of the project
* [background.md](background.md) - Background research
* [api](api.md) - Application Programming Interface (API), inc. data downloads

Criteria:

* [Criteria for passing badge](https://www.bestpractices.dev/criteria/0)
* [Criteria for all badge levels](https://www.bestpractices.dev/criteria)

Development processes and security:

* [requirements.md](requirements.md) - Requirements (what's it supposed to do?)
* [design.md](design.md) - Architectural design information
* [implementation.md](implementation.md) - Implementation notes
* [testing.md](testing.md) - Information on testing
* [assurance-case.md](assurance-case.md) - Why it's adequately secure (assurance case)
