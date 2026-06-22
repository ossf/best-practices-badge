# Application Programming Interface (API)

<!-- SPDX-License-Identifier: (MIT OR CC-BY-3.0+) -->

BadgeApp is a relatively simple web application, and its
external application programming interface (API) is simple too.
The BadgeApp API is a simple RESTful API that follows
Ruby on Rails REST conventions.

We *want* people to use our data; please do so!
However, please don't overwhelm us.

This document provides a quickstart,
legal information,
a discussion of the most common requests,
a pointer to a sample analysis program,
how to query, how to download the database,
and then various kinds of more specialized information.

All BadgeApp requests are rate-limited. At the time of this writing,
if you keep requests at 1 request/second or less for anything other than
badge images you'll be fine. Badge image rates can be much higher
(those are specially optimized).

## Quickstart

Like any RESTful API, use an HTTP verb (like GET) on a resource.

For example, you can get the JSON data for project #1 from the
real production site (<https://www.bestpractices.dev>)
by retrieving (a GET) data from this URL:

```
https://www.bestpractices.dev/projects/1.json
```

You can ask for a particular result data format (where
supported) by adding a period and its format (e.g., ".json", ".csv",
and ".svg") to the URL before the parameters (if any).
When using "." + format, the format name must be all lowercase.

If want the JSON data for a specific project (or projects) and want to
search for it by URL, you can use a URL search and request for that data
in JSON format like this (you'll get an array of matches):

```
https://www.bestpractices.dev/projects.json?url=URL
```

A GET just retrieves information, and since most information is public,
in most cases you don't need to log in for a GET.
Other operations, like POST or DELETE, require logging in first
(as is typical, cookies are used to track logged-in sessions).

We *do* support POST for changing project data,
but we generally recommend using
[automation proposals](automation-proposals.md) URLs or the
[.bestpractices.json](basepractices-json.md) file instead.

WARNING: Do *not* use the HTTP header "Accept" to select a format;
that *no longer works* (it was previously deprecated).
Instead, please use the URL itself to request
the format (e.g., use a URL with ".json" if you want JSON format).
At one time we allowed this, but that interferes with CDN caching.
Caches normally just use the URL to determine
what to cache, and caches work much less well if they have to use other
parameters to examine the cache.

From here on we'll omit the scheme (https) and hostname, and
we'll indicate variables by beginning their name with ":" (colon).
So the URL above is an example of this pattern, which retrieves
information about project :id in a given :format (an empty format
specifier returns HTML):

```
GET /projects/:id(.:format)
```

## Legal information

We *want* people to use the data we supply, so please do so!
The main requirement is that you provide attribution.

More specifically: As noted on the website front page,
all publicly-available non-code content managed by the badging application
is released under at least the
[Creative Commons Attribution License version 3.0 (CC-BY-3.0)](https://creativecommons.org/licenses/by/3.0/);
newer non-code content is released under
CC-BY version 3.0 or later (CC-BY-3.0+).
If referencing collectively or not
otherwise noted, please credit the OpenSSF Best Practices badge contributors.

If you use the data for research, we'd love to hear about your results,
so please do share the results with us if you can.
That said, you are not legally required to share any results.

## Most common requests

Here are the most common requests that an external system
might request.

*   <tt>GET /(:locale/)projects/:id(/:level)(.:format)</tt>

    Request data for project :id in :format. An empty format suffix
    returns HTML, and the ".json" format suffix returns JSON.
    External interfaces should normally request format "json".
    If "level" is given (0, 1, or 2), that level is shown
    (level is ignored if json format is requested, because we just
    provide *all* the data when JSON is requested).

*   <tt>GET /(:locale/)projects/:id/badge(.:format)</tt>

    Request the badge display for project :id in :format.  An empty format
    suffix returns SVG, and the ".json" format suffix returns JSON.
    If you just want to the badge status
    of a project, retrieve this as JSON and look at the key badge_level.

    WARNING! Do *not* use the "Accept:" HTTP header to select JSON format,
    as that does not work; use the URL ".json" suffix instead for JSON!

    The SVG and JSON badges are specially and rapidly served
    by the Content Delivery Network (CDN) that we use.
    For example, so feel free to using "img src" to embed the SVG
    badges, since they will be returned especially rapidly.

    For example, you can embed the badge status of project NNN
    in an HTML document with:

    ```
    <a href="https://www.bestpractices.dev/projects/NNN">
      <img src="https://www.bestpractices.dev/projects/NNN/badge">
    </a>
    ```

    You can also embed the badge status of project NNN in a markdown file with:
    `[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/NNN/badge)](https://www.bestpractices.dev/projects/NNN)`

*   `GET /(:locale/)projects(.:format)(?:query)`

    Perform a query on the projects to return a list
    of the matching projects, up to the maximum number allowed in a page.
    An empty format suffix returns HTML, the ".json" format suffix returns
    JSON, and the ".csv" format suffix returns CSV format.
    See below for more about the query.

*   `GET /en/projects(.:format)?as=badge&url=https%3A%2F%2Fgithub.com%2FORG%2FPROJECT`

    Perform a query for a project with the given URL (this can be
    either the repository URL or the home page URL) and redirect to the
    *single* badge display given that query. This returns status 404
    (not found) if there is no match, and status 409 (conflict) if there
    is more than one match. The URL can be any URL (it doesn't need to be
    GitHub, that is just an example to show how to do the URL encoding).
    NOTE: there is no "/" after the word `projects`!

    The `as=badge` option is intended to make it easy to create dashboards
    (at a cost of some performance). If you only know the repository or
    home page URL of a project, and want to display its badge, this API
    entry is designed for you.
    An empty format suffix returns SVG, and the ".json" format suffix
    returns JSON.

    There's a performance penalty for using this interface. This interface
    makes a query each time to the BadgeApp, which then redirects
    the requestor to the actual badge URL (the latter goes through a CDN
    and is thus much faster). You can avoid making the performance penalty
    worse if you follow these rules (if you don't, your users will endure
    additional unnecessary redirects as the system tries to fix the query):
    - Use the conventional alphabetic order, `as=badge` before `url=`
    - Use URL encoding, especially in the url. For example, use %3A for ":"
      and %2F for "/". In many situations you *must* do this.
    - Use the English locale ('/en/'), since the locale isn't relevant
      (if you omit the locale there will be a locale redirect).

    We recommend individual projects use the id-based interface listed above,
    since they already known their id. However, multi-project dashboards
    often do not know every project's id, so this interface makes it
    easy to get the relevant badge (if any).

    Dashboards using this information that want a simple display
    of the OpenSSF Badge result may want to use combine hypertext
    links and the "alt" tag like this, where `MY_URL` is the URL to be used:

    ```
    <a href="https://www.bestpractices.dev/projects?as=entry&url=MY_URL">
      <img src="https://www.bestpractices.dev/projects?as=badge&url=MY_URL" alt="OpenSSF N/A">
    </a>
    ```

    The "alt" text is shown on failure, and the hyperlink helps both
    accessibility and anyone who wants to learn more about the badge.
    The link uses as=entry; this will show the specific project entry
    if there is exactly one, and otherwise will show the project list of
    matches.

    All BadgeApp requests are rate-limited, and requests other than badge
    images have smaller rate limits. So while you can embed this query when
    describing a single project, you can't really have a page
    full of these queries (such as the img src above using a /projects query).
    If you want to show a large number of OpenSSF badges images all at once,
    it's better to use the query interface to find its corresponding
    numeric project id (e.g., at the server). Then just use the numeric
    project id reference instead, e.g., generate this instead (where you
    found NUMBER earlier):

    <img src="https://www.bestpractices.dev/projects/NUMBER/badge" alt="OpenSSF N/A">

*   `GET /en/projects?as=edit&url=MY_URL`
    `GET /en/projects?as=edit&section=SECTION&url=MY_URL`

    Perform a query for a project with the given URL (repository URL or
    home page URL) and redirect to its *edit* page.
    This is intended for external automation tools that know a project's
    URL but not its numeric ID, and want to propose changes to the
    badge entry (see
    [automation-proposals.md](automation-proposals.md) for details
    on the automation proposals mechanism).

    If a single project matches, the redirect target depends on `section`:

    - If `section` is omitted or `choose`, the user is sent to the
      section-chooser page so they can pick which section to edit.
      The redirect target is `/projects/:id/choose/edit?PROPOSAL_PARAMS`.
    - If `section` names a specific badge level (e.g., `passing`, `silver`,
      `gold`, `baseline-1`), the user is sent directly to that section.
      The redirect target is `/projects/:id/:section/edit?PROPOSAL_PARAMS`.

    Only automation-proposal query parameters are forwarded;
    the consumed parameters (`as`, `url`, `section`, `pq`, `q`) are
    stripped from the redirect URL.
    The redirect URL intentionally omits the locale prefix so the
    application selects the user's preferred locale.
    If the user is not logged in, they are prompted to log in and then
    returned to the original URL with all proposal parameters intact.

    If no project matches, or if multiple projects match, the normal
    project list is shown instead.

    Example letting the user choose which section to edit:

    ```text
    /en/projects?as=edit&floss_license_status=Met&url=https%3A%2F%2Fgithub.com%2FORG%2FPROJECT
    ```

    Example sending the user directly to a specific section (silver):

    ```text
    /en/projects?as=edit&section=silver&url=https%3A%2F%2Fgithub.com%2FORG%2FPROJECT
    ```

## Tiered percentage in OpenSSF Best Practices Badge

The `tiered_percentage` field of a project
(shown as the "tiered %" column on the projects page)
is a number that should be interpreted as a percentage.
As also explained at the bottom of the
[projects page](https://www.bestpractices.dev/en/projects),
this field is 300% (represented as 300) for gold,
200% (represented as 200) for silver, and
100% (represented as 100) for passing, plus any
progress after the highest-earned badge.

For example,
a project that has earned a passing badge (100%), has completed 40% of the
silver requirements, and has also completed 20% of the gold requirements,
will have a value of 140 (meaning 140%).
We intentionally don't give credit to much higher badge requirements
until a previous lower badge is earned,
because we are trying to encourage earning complete badges.

When there was only a single badge level this represented progress toward
earning the passing badge (earning it would show 100%).
When we added higher-level badges, it was clear that there was value in
having a single number represent broader progress, so we decided to
implement this number as a "tiered percentage".
We think it provides a useful measure of progress.

If all you want is the badge level, we recommend using
`badge_level` instead.
This provides text that represents the currently earned badge level.
Currently it is one of `in_progress`, `passing`, `silver`, or `gold`.
If we add new badge levels (such as `platinum`) then it will provide
that new value as appropriate.

## Sample programs

See the [best\_practices.py](./best_practices.py) program to see an
example of how to download and analyze data.
Notice that since we supply JSON data in pages, you need to retrieve
all the pages if you want the entire dataset.
If you retrieve the entire database, store it locally
(in a file or database system); it intentionally takes some time
to download all of it.

See the [best\_practices\_modify.py](./best_practices_modify.py)
program to see how to programmatically *modify* project data.
Note that if you want to *modify* project data, you have to
take a few extra steps to authenticate yourself
(to prove that you're authorized to do this).

## Query (Search)

The "/projects" URL supports various searches.
For example, retrieving this URL:

```
/projects.json?gteq=90&amp;lteq=99&amp;page=2
```

Will retrieve a list of project data in JSON format, but only for
projects with 90% or better passing *and* less than or equal to 99%
passing (that is, not completely passing), and will retrieve the second
page of this list (by default the first page is returned).
(Beware: If you embed the URL in an HTML document, you must as
always write `&` as `&amp;`.

We reserve the right to change the details, but we do try
to provide a reasonable interface.
Most parameters can be combined (in which case all criteria must be met).
The following search parameters are supported:

*   status: "passing", "in\_progress", "silver", or "gold"
*   gteq: Integer, % greater than or equal of passing criteria
*   lteq: Integer, % less than or equal of passing criteria.
    Can be combined with gteq
*   url: Text - matches the home page URL or the repo URL exactly.
    Be sure to use URL encoding (%3A for ":" and %2F for "/").
    This is an 'equal to' match, so `url=http:%3A%2F%2Fq.com`
    will retrieve `https://q.com` but not `https://q.com/repo7`.
    See pq= if you want to search for a prefix.
    A trailing space and trailing slash are ignored.  If we add support
    for package URLs (purls), this would retrieve those matches as well.
*   pq: Text, "prefix query" - matches against *prefix* of URL or name
*   q: Text, "normal query" - match against parsed name, description, URL
    This is implemented by PostgreSQL, so you can use "&amp;" (and),
    "|" (or), and "'text...*'" (prefix).
    Note that URLs cannot include spaces, and &amp;amp; has a special meaning,
    so you typically will need to use URL encoding in a query.
    For example, `/en/projects?q=R%20%26%20analysis`
    is a search that requires both "R" and "analysis".
    This search request system breaks URLs into parts, so you can't use "q" to
    search on a whole URL (use pq instead).
*   page: Page to display (starting at 1)

Once a project query completes, by default the result will be a paged
list of projects in the requested format. The "as" parameter changes this:

*   as=badge : Display the *single* badge for the resulting project.
    If no project matches the criteria, status 404 (not found) is returned.
    If multiple projects match the criteria, status 409 (conflict) is returned.
*   as=edit : Redirect to the *edit* page for the resulting project.
    If a single project matches, the user is redirected (302) to the
    project's edit URL. If no or multiple projects match, the normal
    project list is shown instead. See below for details.
*   as=entry : Display the project badge *entry* for the resulting project.
    If no or multiple projects match, the normal project display
    is shown instead.
    If `section=choose` is also provided, the user is redirected to the
    section-chooser page (`/projects/:id/choose`) so they can pick which
    section to view.

See
[app/controllers/projects\_controller.rb](https://github.com/ossf/best-practices-badge/blob/main/app/controllers/projects_controller.rb)
if you want to see the implementation's source code.

## Downloading the database

We encourage analysis of OSS trends.
We do provide some search capabilities, but for most analysis
you will typically need to download the database.
We can't anticipate all possible uses, and we're trying to keep the
software relatively small & focused.

You can download the project data in JSON and CSV format using typical
Rails REST conventions. Just add ".json" or ".csv" to the URL.
You can even do this on a search if we already support the search (e.g.,
by name).  Similarly, you can download user data in JSON format using
".json" at the end of the URL.

There is a current technical limitation in that you must
request project and user data page-by-page.
This isn't hard, just provide a page parameter (e.g., "page=2").
This is because Rails does not stream JSON or CSV data by default,
so if we allowed this the application would download
the entire database into memory to process it.
Rails applications *can* stream data (there are even web pages explaining
how to do it), but the call for it is rare and there are some
complications in its implementation, so we just haven't implemented it yet.

So you can download the projects by repeatedly requesting this
(changing "1" into 2, 3, etc. until all is loaded):

> https://www.bestpractices.dev/projects.json?page=1

You can similarly load the user data starting from here:

> https://www.bestpractices.dev/users.json?page=1

To directly download the user list you must be logged in, and we
intentionally restrict the information we share about users.
We only provide basic public information such as name, nickname, and such.
In particular, we only provide email addresses to
BadgeApp administrators, because we value the privacy of our users.

As we note about privacy and legal issues,
please see our <a href="https://www.linuxfoundation.org/privacy">privacy
policy</a> and <a href="https://www.linuxfoundation.org/terms">terms of
use</a>.
All publicly-available non-code content is released under at least the
<a href="https://creativecommons.org/licenses/by/3.0/">Creative Commons
Attribution License version 3.0 (CC-BY-3.0)</a>;
newer non-code content is released under
CC-BY version 3.0 or later (CC-BY-3.0+).
If referencing collectively or
not otherwise noted, please credit the
"OpenSSF Best Practices badge contributors" and note the license.
You should also note the website URL as the data source, which is
<https://www.bestpractices.dev>.

If you are doing research, we urge you do to it responsibly and reproducibly.
Please be sure to capture the date and time when you began and completed
capturing this dataset
(you need both, because the data could be changing
while you're downloading it).
Do what you can to ensure that your research can be
[replicated](https://en.wikipedia.org/wiki/Replication_crisis).
Consider the points in
[Good Enough Practices in Scientific Computing](https://arxiv.org/pdf/1609.00037v2.pdf), a "set of computing tools and techniques
that every researcher can and should adopt."
For example, "Where possible, save data as originally generated (i.e.
by an instrument or from a survey."
These aren't requirements for using this data, but they are well
worth considering.

## Full entry point list

The RESTful interface supports the following interfaces, which is enough
to programmatically create a new user, login and logout, create project
data, edit it, and delete it (subject to the authorization rules).
In particular, viewing with a web browser (which by default emits 'GET')
a URL with the absolute path "/projects/:id" (where :id is an id number)
will retrieve HTML that shows the status for project number id.
A URL with absolute path "/projects/:id.json"
will retrieve just the status data in JSON format (useful for further
programmatic processing).

The following shows the HTTP verb (e.g., GET), the URI pattern, and
the controller#action in the code (important if you need to examine
the source code itself which is in directory app/controllers/).

```
Verb   URI Pattern                        Controller#Action
GET    /projects/:id(.:format)            projects#show # .json supported.
GET    /projects/:id/badge(.:format)      projects#badge {:format=>"svg"}

GET    /projects(.:format)                projects#index
POST   /projects(.:format)                projects#create
GET    /projects/new(.:format)            projects#new
GET    /projects/:id/edit(.:format)       projects#edit
PATCH  /projects/:id(.:format)            projects#update
PUT    /projects/:id(.:format)            projects#update
DELETE /projects/:id(.:format)            projects#destroy

GET    /users/new(.:format)               users#new
GET    /signup(.:format)                  users#new
GET    /users/:id/edit(.:format)          users#edit
GET    /users/:id(.:format)               users#show

GET    /sessions/new(.:format)            sessions#new
GET    /login(.:format)                   sessions#new
POST   /login(.:format)                   sessions#create
DELETE /logout(.:format)                  sessions#destroy
GET    /signout(.:format)                 sessions#destroy
```

If you install the application you can have it report the routes
by running "rake routes".

## Rails \_method parameter in POST

As explained in the
Rails Guide [*Form Helpers*](http://guides.rubyonrails.org/form_helpers.html#how-do-forms-with-patch-put-or-delete-methods-work-questionmark):

> The Rails framework encourages RESTful design of your applications, which means you'll be making a lot of "PATCH" and "DELETE" requests (besides "GET" and "POST"). However, most browsers don't support methods other than "GET" and "POST" when it comes to submitting forms.  Rails works around this issue by emulating other methods over POST with a hidden input named "\_method", which is set to reflect the desired method.

This works in the BadgeApp application too.
However, note that most requests other than GET (and a few GET requests)
require a logged-in session, so while this is alternative way to
*make* the request, for the request to succeed
you still have to use a logged-in session
with adequate authorization.

## Cross-Origin Resource Sharing (CORS)

The BadgeApp permits some access by client-side JavaScript programs
that originate from other sites.

Client-side JavaScript programs are, by default, subject to the
"same origin" policy, which prevents them from arbitrarily accessing
sites other than where they came from.
The standard way to give a client-side JavaScript program additional
privilege is through Cross-Origin Resource Sharing (CORS) HTTP headers.

The BadgeApp provides CORS headers in certain cases when an
"Origin" is provided.
When a client-side JavaScript program
makes a request to a different origin, it provides its "origin", and
that allows the BadgeApp to decide what it wants to allow.

The CORS header expressly does *not* share credentials, and
*only* allows GET (or OPTIONS) for a few specific resources.
If someone provides a good reason to allow more accesses from
JavaScript clients, we'll gladly consider it.
For details, see the BadgeApp source code `config/initializers/cors.rb`.

## Locale

Users indicate their locale via the URL.
We use one of the standard approaches, where the locale is the first
part of the path.
For example,
<https://www.bestpractices.dev/fr/projects>
selects the locale "fr" (French) when displaying "/projects".
This even works at the top page, e.g.,
<https://www.bestpractices.dev/fr>.
The application also supports the locale as a query parameter, e.g.,
<https://www.bestpractices.dev/projects?locale=fr>,
though that is not the canonical URL format.

At one time, when a locale was not provided, English (en) was assumed.
However, that made it impossible to distinguish between
"use the browser's preferred locale" and "use English".

Now, if no locale is selected, the application will redirect requesters
to the best matching locale (as recommended by the accept-language
value provided by the browser, with English as the last resort).
The API has an important exception: if JSON format is requested, no
locale redirection occurs (because JSON isn't locale-sensitive).
The request for the badge image (with `/projects/NNN/badge`)
is also not redirectored (again, because it isn't locale-sensitive).

Locales are always exactly 2 lowercase letters, or 2 lowercase letters
followed by an dash and then more alphanumerics.
For example, "fr" is French, while "zh-CN" is Chinese (Simplified).
This convention lets you syntactically distinguish between
locales and other possible meanings of a URL's prefix;
non-locale pages never match the locale syntax.

## Canonical URLs

The canonical URL format for pathnames is a single "/" for the topmost
root (which will redirect to the best-matching locale), otherwise there
is no trailing slash.
This is the canonical format generated by the Rails router helpers.

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
