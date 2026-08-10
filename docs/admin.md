# Instructions for Web Application Administrators

<!-- SPDX-License-Identifier: (MIT OR CC-BY-3.0+) -->

This document provides basic information for web application administrators
for the best practices badge site.

## Expectations

See [governance - Web application admin](governance.md#web_application_admin)
for information on the general expectations for
web application administrators.

Being an admin is a position of high trust. Admins must not
abuse their access, which includes the ability to edit or delete
arbitrary project badge entries and user profiles.
In particular, admins can see the email addresses of every user.

You *must* keep user email addresses private. Many email addresses are
publicly known, but not all.

## Becoming an admin

To become an admin, you must first create a user account on
<https://www.bestpractices.dev/> by using "Log in" (for a GitHub account)
or "Sign up" (for a local email + password account).

A system admin will then give your account admin privileges
following the instructions in [implementation.md](./implementation.md).

Optional: If you want, you can go here to create a gravatar image:
<https://gravatar.com/>.
If you set up a gravatar image, it will show on many sites
(including this one) when describing you.
You'll need to tell Gravatar the email address that you use for login
and/or for GitHub.
Note that Gravatar lets sites look up an avatar image of a user based on the
[*cryptographic hash*](https://docs.gravatar.com/rest/hash/) of their email
address. We *never* send unencrypted email addresses to Gravatar!

## GDPR requests

We, the Linux Foundation, occasionally receive GDPR requests on user
accounts, e.g., to delete their own accounts.
We're only *legally* obligated to do this for
individuals located in the EU/EEA. However, by policy, we honor such
requests from anyone. Typically we receive a collection of requests;
we then search for each user name and email address.

To search for an individual's name and email address, go to
<https://www.bestpractices.dev/en/users> (log in if necessary).
Scroll to the bottom to see "New Search".
Enter the name and email address. As noted on the page,
name search is case-insensitive and supports wildcards (use `%` for
zero or more characters and `_` for exactly one character).
Email search is case-insensitive, but don't include extraneous information
such as a trailing `.` at its end.

In nearly all cases, you won't find a match. You record that as no
match and move on.

If there are matches, review the matches to see if they are the actual user.
If they are, and they own no project badge entries, delete the account
if that's what they requested.

If they are present, but they own one or more
project badge entries, we have a problem.
The database data consistency criteria require
every project badge entry to have an owner.
The admin interface *can't* delete a user who owns a project badge entry.
Sadly, users rarely tell us what they want us to do about this.
If that's the case, send an email like this:

<blockquote>
Hi! Can you help me understand what specifically you want done with your
request to delete your accounts?

We at the Linux Foundation received a GDPR request (DR234) from you to
"Delete account and all data". We're sad to see you go, but it's
your right to make that request and we'll honor it.
In fact, we honor such requests even when we aren't
legally obligated to comply with them.

However, you have an account on the
OpenSSF Best Practices badge site here:
`https://www.bestpractices.dev/en/users/XYZ`
This account currently owns one or more project badge entries.

Here's our problem. We can't delete user accounts that own 1+ badge entries,
because all badge entries must have an owner.
It's a database data consistency requirement.
So that leaves us uncertain about what you want us to do.

So: What would you like us to do? Here are the options:

1. Retain your OpenSSF Best Practices badge user account as an exception,
   and basically leave everything unchanged on that site.
2. Transfer your project badge entries to someone else,
   then delete your user account. If that is your preference,
   please provide the user# to us who is willing to receive the badge entry.
3. Delete your project badge entries and then delete your user account.
   Once the project badge entries are deleted, your user account can
   be deleted.

You can, at any time, perform option 2 or 3 yourself. Simply log in
and perform the actions you wish to take. You don't need to wait for us
to do it. However, if you'd prefer that we take these steps on your behalf,
please let us know what you want us to do.

Thank you.
</blockquote>

## Badge entry ownership transfer

The badge system has built-in system to transfer ownership, so the *easy*
thing to do is to ask the current badge-owner to log in and
edit the project badge entry.
The information is near the bottom of the first tab of the passing badge
(currently).
They must know the user number of the new owner, and enter it twice
(to counter mistyping).

If someone who is *not* the current badge owner asks us to transfer
ownership, try to get the *current* badge owner to do it or agree to the
transfer. The new owner must have an account ("Log in" on the site to create
it).

We can't just transfer ownership to anyone who asks (that's a security
problem), but we *do* need to transfer it if it should. "If it should"
can be tricky for us to determine.

If you're communicating by email, and sending email to both parties,
use "bcc" to ensure neither party can see the other's email address.
You might write something like this:

<blockquote>
We've received a request to change the owner of the project badge entry
`https://www.bestpractices.dev/en/projects/XYZ`
that is currently owned by user
`https://www.bestpractices.dev/en/users/XY`
to user
`https://www.bestpractices.dev/en/users/YZ`

Please confirm if this is approved, or reject if it is not.
</blockquote>

Typically the current owner approves, or the current owner's email
address no longer works because they're no longer an employee (and the
employer is trying to switch to another employee).
So while it *can* be a challenge to determine "who should own this",
in practice it generally is not.

We don't transfer ownership until we're sure it should be owned by another.
That way, attackers can't simply "take over" a badge entry by asking for it.

## Deleting bad data

Some users don't understand the site, and may make mistakes.
Help them do the right thing.

However, some users are actors who act in bad faith.
They'll try to create bogus project badge entries, typically to increase
search engine optimization (SEO). Our site marks project badge entry data
so that badge entries never improve SEO, but bad faith actors may not care.
Some are happy to scam their customers *and* hurt the public, as long
as they receive money for their malicious activities.
Others simply like to put malicious data online.

Our site doesn't host images, limits what you can post, and (again)
postings on it do not improve SEO. So we're
not an interesting target for most people who like to create false data.
Still, please help us remove anything that is false.

If you've determined someone is acting in bad faith (not just
confused or making an honest mistake),
*immediately* delete their malicious data and their account.
Don't bother contacting them. That is a waste of everyone's time and
delays fixing the problem.

## Security and logging

We've tried to make this a secure application.
See our [assurance case](./assurance-case.md) if you have any questions
on why we think this is adequately secure. If you think you found a weakness,
file a private GitHub report immediately, or contact the TSC.

Web application data changes (including of web application administrators)
are logged. So if necessary, we can review exactly what changed
and even revert it. However, that's a pain to do. We'd prefer that
fixes be right the first time.
