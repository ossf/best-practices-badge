# Upgrading Pagy 9 to Pagy 43

<!-- SPDX-License-Identifier: (MIT OR CC-BY-3.0+) -->

This document explains the planned upgrade of the `pagy` pagination
gem from version 9.4.0 to version 43.x, why it is a large change, the
risks we investigated, the counting strategy we chose, and a detailed
step-by-step plan.

## Background: why this is a big change

We currently depend on `pagy` `~> 9.0` (locked at 9.4.0, the tip of
the 9.x line, released August 2025). No newer 9.x release exists, so
there are no pending 9.x security or bug fixes to pick up; the only
way forward is the rewrite.

Pagy made a deliberately dramatic "leap": it jumped straight from 9.x
to **43.0.0** (November 2025), skipping versions 10 through 42 as a
signal that this is a *complete redesign* of the API, usage, and
internals ("more with less"). The latest release is **43.5.6**
(June 2026), so the 43.x line is now mature and at a healthy patch
level.

Despite the size of the rewrite, our usage footprint is small, so the
change is contained. We also take the opportunity to add one small,
high-value optimization: caching the projects-index total count (see
"Counting strategy" below).

The primary driver is **crawler load**. Crawlers repeatedly and rapidly
walk the index ("next page, next page, ..."), and database queries,
computations, and responses are all relatively expensive. Every one of
those requests otherwise runs a `COUNT(*)` that returns the *same*
number for the entire walk. Now that we also cache project *show* data,
relatively more load lands on the `/projects` query path, so collapsing
those repeated identical counts into one cached value is worthwhile.
(This optimization removes the repeated *count*; the per-page rows
query and response rendering still run, bounded by the page limit of 20
and the empty-page-on-overflow behavior for deep pages.)

### Our current usage footprint

| Location | Current (pagy 9) | Becomes (pagy 43) |
| --- | --- | --- |
| `application_controller.rb` | `include Pagy::Backend` | `include Pagy::Method` |
| `application_helper.rb` | `include Pagy::Frontend` | (removed; folded into `@pagy`) |
| 3 controller calls | `pagy(scope)` | `pagy(:offset, scope)` |
| 3 views | `pagy_bootstrap_nav(@pagy)` | `@pagy.series_nav(:bootstrap)` |
| `projects_controller.rb` | `@count = @pagy.count` | unchanged (`.count` survives) |
| views | `@pagy.pages > 1` | unchanged (`alias pages last`) |
| `config/initializers/pagy.rb` | ~190 lines | a handful of lines |

The three controllers also set `@pagy_locale = I18n.locale.to_s`. That
variable is **dead code**: it is referenced nowhere in any view or
helper. In pagy 43 the per-request locale is set differently (see
I18n below), so these three lines are removed rather than ported.

## Decision summary

* Upgrade to `pagy '~> 43.5'`.
* Use the plain **`:offset`** paginator.
* **Cache the unfiltered projects-index count** with a short TTL to
  avoid a redundant `COUNT(*)` on every index/pagination request — most
  importantly on rapid crawler "next page" walks. The TTL defaults to
  60 seconds and is overridable (in seconds) via the
  `BADGEAPP_PROJECTS_COUNT_TTL` environment variable. See "Counting
  strategy" for why this beats the alternatives we considered
  (pagy `:countish`, URL count params, and keyset pagination).
* **Invalidate the cached count on project create/destroy** (a model
  `after_commit`) so the most-visible total stays accurate after a
  write, with the TTL as a backstop. This is best-effort *per process*
  (see the caveat under "Counting strategy").
* Add efficient **first-page / last-page** navigation links using
  `@pagy.page_url(:first)` and `@pagy.page_url(:last)`.
* Add a `rel="canonical"` link on the paginated index pages to replace
  the discontinued `trim` extra and improve SEO.
* Collapse the large custom I18n block in the initializer to a single
  `before_action`, since pagy 43 now ships dictionaries for all nine
  of our locales and auto-loads them.

## The Bootstrap 3 question (explicitly investigated)

We deliberately use **Bootstrap 3.4.1** (`bootstrap-sass ~> 3.4`,
pinned, with explicit "do not update" notes alongside `bootstrap_form`
and `bootstrap-social-rails`). Pagy's bootstrap navigation markup has
historically tracked newer Bootstrap versions, so this was the first
thing we checked.

**Conclusion: not a problem.** Pagy 9.4.0 *already* emits Bootstrap
4/5-style markup, and pagy 43's markup is materially identical:

```html
<!-- pagy 9 AND pagy 43 emit essentially this -->
<ul class="pagination">
  <li class="page-item previous">...</li>
  <li class="page-item"><a class="page-link" href="...">2</a></li>
  <li class="page-item active"><a class="page-link"
      aria-current="page">3</a></li>
  <li class="page-item gap disabled"><a class="page-link">&hellip;</a></li>
  ...
</ul>
```

We render this correctly today on Bootstrap 3 with **zero custom
pagination CSS**, because:

* Bootstrap 3 styles pagination by element position
  (`.pagination > li > a`), so the extra `.page-item` / `.page-link`
  classes are harmless no-ops that BS3 simply ignores.
* The `.active` and `.disabled` state classes sit on the `<li>`, which
  is exactly where Bootstrap 3's `.pagination > .active > a` and
  `.pagination > .disabled > a` rules expect them.

The only differences between pagy 9 and pagy 43 bootstrap output are
cosmetic class names on wrappers that our CSS does not target:

* outer nav class `pagy-bootstrap nav` becomes `pagy-bootstrap series-nav`
* the previous/next item class `prev` becomes `previous`

Since the change does not regress anything that works today, the
Bootstrap upgrade pressure is unchanged by this work. We will still
**visually verify** the rendered nav after the change (see Testing).

## Other upgrade risks investigated

Besides Bootstrap, we checked the two upgrade mechanics most likely to
bite. Both are fine.

### Risk: `Pagy::I18n.locale` thread-safety under multi-threaded Puma

Pagy 43 changes how the nav's locale is selected: instead of passing a
locale per call, you set `Pagy::I18n.locale` per request. Our Puma runs
with 5 threads per process (`threads 5, 5`), so a naive global setting
would be a race condition between concurrent requests.

**Conclusion: safe.** In pagy 43, `Pagy::I18n.locale=` stores the value
in `Thread.current[:pagy_locale]`, and `Pagy::I18n.locale` reads it back
from the same thread-local, defaulting to `'en'`. Each request thread
therefore has its own locale. The setter also validates the string
against an RFC-4647 locale pattern, rejecting malformed input. A simple
`before_action { Pagy::I18n.locale = I18n.locale.to_s }` is correct and
safe under our threaded server.

This also explains the now-removed `@pagy_locale`: it was the old
mechanism for getting the locale to the nav helper. In pagy 43 the
`before_action` replaces it entirely.

### Risk: instance API and overflow behavior

Our controllers and views rely on `@pagy.count`, `@pagy.pages`, and on
out-of-range pages degrading gracefully (we currently require the
`overflow` extra with `:empty_page`).

**Conclusion: preserved.** In pagy 43's `Pagy::Offset`:

* `attr_reader ... :count` keeps `@pagy.count` working, so
  `@count = @pagy.count` is unchanged.
* `alias pages last` keeps `@pagy.pages` working, so the
  `@pagy.pages > 1` guards in the three views are unchanged.
* The constructor checks `in_range?` and, for an out-of-range page,
  assigns empty-page variables and returns a valid instance instead of
  raising. Serving an empty page on overflow is now the **default**, so
  our explicit `overflow: :empty_page` configuration is no longer
  needed and is simply dropped.

## Counting strategy: how we get the total

Offset pagination needs two pieces of data per page view: the page of
records (`SELECT ... LIMIT 20 OFFSET N`) and the total count
(`SELECT COUNT(*)`), which drives the "1234 projects" header and the
numbered nav. The count is therefore a **second database hit on every
index and pagination request**. With project *show* data now cached,
the `/projects` query path carries relatively more of our load, so it
is worth removing that redundant hit where we safely can.

We evaluated several strategies and chose a server-side cached count.

### Options considered

1. **Plain `:offset`, recount every page.** Simplest and always
   correct, but runs `COUNT(*)` on every index/pagination request.
2. **Pagy `:countish`.** Memoizes the count by packing it into the
   page parameter, e.g. `?page=5+1234[+epoch]`. Rejected for this app:
   * It **collides with our existing page validation.** The index
     validates `page` with `POSITIVE_INTEGER_REGEX`
     (`/\A[1-9][0-9]{0,15}\z/`) and strips anything that fails
     (`allowed_query?` / `set_valid_query_url`). Pagy's `5+1234`
     decodes to `"5 1234"`, which fails that regex and would be
     stripped, breaking the mechanism.
   * The count rides in the URL, so it is **client-spoofable**
     (cosmetic and bounded, but still untrusted) and is recomputed for
     **every new visitor's first hit** (the param starts absent), so it
     saves nothing for fresh/crawler traffic.
3. **A separate URL count param (e.g. `tc`, plus a `tcx` expiry).**
   Workable and would keep `page` clean, but it adds one or two
   client-supplied params to validate and propagate (via pagy's
   `:querify` lambda), is still spoofable, and still recomputes per new
   visitor. More surface for little gain.
4. **Keyset / "start from id#" (cursor) pagination.** Pagy 43 supports
   `:keyset` and the JS-backed `:keynav_js`. This is the fastest
   technique for deep pages and is immune to insert/delete drift, but
   it is the wrong fit for *this* UI:
   * The index offers ~11 sort columns plus direction, full-text
     search ranking, and status/range filters. Keyset needs a unique
     index matching each exact sort order, and relevance-ranked
     full-text search is especially hostile to keyset.
   * Our ordering is not strictly unique today
     (`reorder(field).order(created_at)` with no final `id`
     tiebreaker); keyset would require adding one everywhere.
   * The UI relies on **random page jumps** and a **visible total**;
     pure keyset gives up both, and `:keynav_js` only restores the nav
     by adding pagy's JavaScript pipeline (we use static navs today and
     even block the JS pseudo-pages in `robots.txt`).
   * The pain keyset solves (deep `OFFSET`) is not ours: the table is
     moderate (tens of thousands of rows), deep pages already serve an
     empty page on overflow, and at a few project additions per day the
     offset "drift" is negligible.

   Keyset-by-`id` *would* be a good fit for a future high-throughput
   "give me everything since id X" feed or sync endpoint — an additive
   feature, not a replacement for the index UI.
5. **Server-side cached count with a TTL (chosen).** Cache the count in
   `Rails.cache` with an expiry; the cache TTL *is* the "recompute
   after some point" mechanism.

### Why the cached count wins

* **Clean URLs.** Pages stay `?page=N`; nothing extra to validate, and
  existing scripts are unaffected.
* **Not spoofable.** The count never comes from the client.
* **Counts less, not more.** A URL-carried count (countish or `tc`) is
  recomputed on every new visitor's first request. A cached count is
  computed **once per TTL for everyone** on that process, which is the
  bigger win on a busy, crawler-heavy site. In particular, a crawler
  that walks 50 "next page" requests reuses one cached count instead of
  triggering 50 identical `COUNT(*)` queries.
* **Bounded memory.** We cache only the **unfiltered** count under a
  single key, so there is no per-query key growth. (Production uses a
  bounded 128 MB `:memory_store` with eviction; it is per-process, so
  the count is computed at most once per TTL per process.)
* **Self-healing staleness.** The TTL bounds how stale the displayed
  total can get — 60 seconds by default. At a few additions per day,
  that is far tighter than any drift it could realistically show.

### What we cache, and when

The count depends only on the `WHERE` clause, which is set by these
index parameters: `status`, `gteq`, `lteq`, `pq`, `url`, `q`, and
`ids` (sort and page never affect the count). The overwhelmingly hot
path is bare `/projects` with none of those present, where the count
is simply `Project.count`. So:

* **No count-affecting filter present:** serve a cached `Project.count`
  (single global key, TTL-bounded), and let pagy reuse it via `count:`.
* **Any count-affecting filter present:** pass `count: nil` so pagy
  runs a fresh `COUNT(*)`; search/filter results are lower volume and
  users expect accurate numbers there.

Sketch (illustrative; final form lives in `projects_controller.rb`):

```ruby
# Seconds to cache the unfiltered projects count. Override via env var.
PROJECTS_COUNT_TTL =
  (ENV['BADGEAPP_PROJECTS_COUNT_TTL'] || '60').to_i.seconds

# Params that change the WHERE clause, and thus the count.
COUNT_FILTER_PARAMS = %i[status gteq lteq pq url q ids].freeze

# In select_data_subset, replacing the plain pagy() call:
count =
  if COUNT_FILTER_PARAMS.any? { |k| params[k].present? }
    nil # filtered/search: let pagy run a fresh COUNT
  else
    Rails.cache.fetch('projects/index/count',
                      expires_in: PROJECTS_COUNT_TTL) { Project.count }
  end
@pagy, @projects = pagy(:offset, @projects.includes(:user), count: count)
@count = @pagy.count
```

This is the core of the optimization, and it is a few lines. The
lower-traffic users index and user-show pages keep a plain `:offset`
count for simplicity.

### Keeping the cached count fresh: invalidate on write

The cached count would otherwise refresh only when its TTL expires.
Because the unfiltered total is the single most-visible number and it
changes *only* when a project is created or destroyed, we invalidate
that one key on exactly those events, so the displayed total is correct
again right away (with the TTL as a backstop). Edits never change the
count, so we leave the cache alone on update.

The cleanest place is a model `after_commit`, which is DRY and also
covers non-controller paths (rake imports, console, jobs) in that
process:

```ruby
# app/models/project.rb
after_commit :bust_index_count_cache, on: %i[create destroy]

private

def bust_index_count_cache
  Rails.cache.delete('projects/index/count')
end
```

**Caveat — it only works in the process that ran the delete.**
Production uses `:memory_store`, which lives in each process's own heap,
so `Rails.cache.delete` clears the entry **only in the process that
executed it**. Today that is fine: production runs a single web process
per dyno (Puma `workers` are disabled) on a single dyno, so the delete
reaches everywhere it matters. But if we ever grow to multiple Puma
workers or multiple dynos, each process holds its own copy, and a
delete on one process does **not** reach the others — they refresh only
when their own TTL expires. So treat invalidation as a best-effort
freshness boost, with the **TTL as the real bound** once more than one
process is in play. (True global invalidation would require a shared
cache store, which is not worth introducing for this.)

Because invalidation keeps the count fresh on writes, the TTL mainly
bounds cross-process staleness and acts as a safety net. We default it
to **60 seconds**, overridable (in seconds) via
`BADGEAPP_PROJECTS_COUNT_TTL`.

The default is deliberately short because the TTL is *not* a
"how much do we save" knob. The first request after expiry repopulates
the entry for everyone, so the recompute rate is capped at **one
`COUNT(*)` per TTL per process regardless of request volume** — a
million requests in the window still cause at most one count. A 60-second
window already absorbs the bursts that matter (a crawler walking dozens
of "next page" requests finishes within it and shares a single count);
a longer TTL would only avoid the occasional cheap recompute during
quiet, spread-out traffic, at the cost of ~5× the staleness. A short
TTL also tightens the cross-process freshness bound that the
per-process caveat above leaves to the TTL once we run more than one
process. Lengthen it only if idle-period recomputes ever prove costly.

### A correction to earlier reasoning

An earlier draft argued against `:countish` on grounds of **CDN cache
fragmentation** and a **deep-`OFFSET` denial-of-service**. On review
both were wrong for this app: the paginated `/projects` pages are
**not** cached on Fastly, so there is nothing to fragment; and a deep
`OFFSET` is bounded by the real result size whether or not the count is
spoofed (Postgres only has the real rows to scan), so a spoofed count
does not unlock a worse query than `?page=hugenumber` already could.
The real reasons we avoid URL-carried counts are the `page`-validation
collision, client spoofability, and that a cached count is simpler and
counts less.

## I18n: a large simplification

This was expected to be the riskiest part of the port and turned out to
be the biggest win.

* **All nine of our locales ship with pagy 43**: `en`, `zh-CN`, `es`,
  `fr`, `de`, `ja`, `pt-BR`, `ru`, and `sw`. In particular `sw`
  (Swahili), which the old initializer flagged as unsupported and
  worked around, is now bundled. We need no custom pagy dictionaries.
* Pagy 43 **auto-loads** its bundled dictionaries on demand, so the
  entire `PAGY_LOCALES` / `Pagy::I18n.load(*...)` block (and its
  `rubocop:disable`, `freeze`, and special-casing) is deleted.
* The per-request locale is set with one `before_action` (see the I18n
  risk above).

If we ever need to override a pagy string ourselves, the path is
`Pagy::I18n.pathnames << Rails.root.join('config/locales/pagy')` with
`<locale>.yml` files — but we do not need that today.

## Canonical URLs: replacing the discontinued `trim` extra

Today we load `pagy/extras/trim`, which strips `?page=1` from the
first-page link so it matches the canonical bare URL (`/projects`).
The `trim` extra is **discontinued** in pagy 43, and `series_nav` emits
`?page=1` on the numeric "1" link. Because the app currently has **no**
`rel="canonical"` tag and `robots.txt` does not block `?page=`,
crawlers could index `/projects?page=1` as a duplicate of `/projects`.

**Fix (better than `trim`):** add a canonical link tag on the paginated
index, driven by pagy's own URL builder. Note that `page_url(:current)`
always emits the page number (even `page=1`), whereas `page_url(:first)`
omits it — so we select the target by page:

```erb
<% target = @pagy.page == 1 ? :first : :current %>
<link rel="canonical" href="<%= @pagy.page_url(target, absolute: true) %>">
```

Page 1 then canonicalizes to the bare URL (`/projects`) while each
deeper page self-canonicalizes (`?page=N`) — collapsing the `?page=1`
duplicate and adding SEO value we do not have today. With plain
`:offset` the URL stays clean (no count to strip). Pagy builds these
URLs about 20x faster than Rails' `url_for`.

## First-page / last-page navigation (new feature)

Two senses of "first/last", both supported and efficient in pagy 43:

* **First/last page numbers in the bar.** With `:slots >= 7` (the
  default is 9), `series_nav` automatically shows the first page, the
  last page, and a `…` gap, e.g. `< prev 1 … 4 [5] 6 … 50 next >`.
  This is the pagy-43 equivalent of our current `size`/`ends` config.
* **Dedicated "First" / "Last" jump links.** Built from the count we
  already have, with no extra query:

  ```erb
  <%= link_to t('.first'), @pagy.page_url(:first) unless @pagy.page == 1 %>
  <%= link_to t('.last'),  @pagy.page_url(:last)  unless @pagy.page == @pagy.last %>
  ```

  `page_url(:first)` and `page_url(:last)` are O(1): `:last` derives
  from `@pagy.count` (which we already read, now usually from cache),
  and URL building just substitutes the page number. The only inherent
  cost is that *rendering* a very deep last page still performs a large
  `OFFSET` scan in PostgreSQL — but that is true of any page-number
  link and is not made worse by adding the button.

New translation keys (`first`, `last`) will be added for the index
views in our own locale files (not pagy's dictionaries).

## Detailed migration plan

Work on a feature branch; keep the change reviewable. The pagy-43
interface points used below were verified against the 43.5 gem source:
the controller method comes from `Pagy::Method` (signature
`pagy(paginator = :offset, collection, **options)`), app config lives in
`Pagy::OPTIONS`, `pagy(:offset, …)` accepts a `count:` seed consumed by
the offset paginator, and the `@pagy` instance exposes `page`, `count`,
and `limit` as readers plus `pages` (an alias of `last`).

1. **Gemfile.** Change `gem 'pagy', '~> 9.0'` to `gem 'pagy', '~> 43.5'`
   and run `bundle update pagy`. Confirm `Gemfile.lock` resolves to a
   43.5.x release.

2. **`config/initializers/pagy.rb`.** Rewrite down to the essentials:
   * Remove `require 'pagy/extras/bootstrap'` (bootstrap is built in).
   * Remove `require 'pagy/extras/overflow'` and the
     `Pagy::DEFAULT[:overflow]` comment (empty page on overflow is the
     default).
   * Remove `require 'pagy/extras/trim'` (discontinued; replaced by the
     canonical link).
   * Remove the entire `PAGY_LOCALES` / `Pagy::I18n.load(*...)` block
     and its `rubocop:disable`/`enable` pair (auto-loaded now).
   * Convert remaining settings from `Pagy::DEFAULT[...]` to
     `Pagy::OPTIONS[...]`. In pagy 43, app config lives in
     `Pagy::OPTIONS`; `Pagy::DEFAULT` is now an internal frozen base.
     * `Pagy::OPTIONS[:limit] = 20` to keep our crawler-memory tuning.
       (Pagy 43's built-in default limit is *already* 20, so this mainly
       documents intent and guards against an upstream change.)
     * Replace `:size = 4` / `:ends = true` with `:slots`. Pagy 43's
       default `:slots` is 9, which already renders the first and last
       pages with `…` gaps; set `Pagy::OPTIONS[:slots]` only to tune
       density.
   * Keep the explanatory comments about *why* the limit is 20.

3. **`app/controllers/application_controller.rb`.**
   * Change `include Pagy::Backend` to `include Pagy::Method`.
   * Add `before_action { Pagy::I18n.locale = I18n.locale.to_s }`
     (placed so it runs after the locale is set for the request).

4. **`app/helpers/application_helper.rb`.** Remove
   `include Pagy::Frontend` (frontend is now on the `@pagy` instance).

5. **`projects_controller.rb` (index pagination + count cache).**
   * Add the `PROJECTS_COUNT_TTL` and `COUNT_FILTER_PARAMS` constants
     near the other configuration constants.
   * In `select_data_subset`, compute the cached/`nil` `count` as shown
     in "Counting strategy" and call
     `pagy(:offset, @projects.includes(:user), count: count)`.
   * Keep `@count = @pagy.count`.
   * Delete the `@pagy_locale = I18n.locale.to_s` line and update the
     YARD comment that references `@pagy_locale`.

6. **`app/models/project.rb` (cache invalidation).** Add an
   `after_commit` on `:create` and `:destroy` that deletes the
   `projects/index/count` key (see "Keeping the cached count fresh").
   This keeps the displayed total accurate after writes, best-effort
   in the process that ran the delete.

7. **`users_controller.rb` (x2).**
   * Change `pagy(scope)` to `pagy(:offset, scope)`.
   * Delete the `@pagy_locale = I18n.locale.to_s` lines. (No count
     cache here; these pages are lower traffic.)

8. **Shared pagination partial + views.** Add
   `app/views/shared/_pagination.html.erb` containing
   `@pagy.series_nav(:bootstrap)` (guarded by `pagy.pages > 1`) plus the
   First/Last jump links, and render it from `projects/index.html.erb`,
   `users/index.html.erb`, and `users/show.html.erb`. A shared partial
   keeps the three call sites DRY and the First/Last UI consistent.

9. **Canonical tag.** In `projects/index.html.erb`, emit a
   `rel="canonical"` link into the layout's `:special_head_values`
   content block (rendered outside the per-locale head cache), using
   `:first` on page 1 and `:current` otherwise (see "Canonical URLs").

10. **Locales.** Add shared `pagination.first` / `pagination.last`
    translation keys to `config/locales/en.yml`; translation.io syncs
    the other locales (they fall back to English until translated).

11. **Document the env var.** Add `BADGEAPP_PROJECTS_COUNT_TTL`
    (seconds; default 60) to the deployment/environment configuration
    notes alongside the other `BADGEAPP_*` settings.

12. **Lint and CI.** Run `rake rubocop`, `rake markdownlint` (for this
    doc), `rake whitespace_check`, then `rake default`. Use only
    `rubocop -a` (never `-A`) for any autocorrection.

## Testing plan

* **Automated:**
   * Existing project/user index and pagination tests must pass
     (`rails test test/integration/project_list_test.rb` and the
     relevant feature/integration tests).
   * Add a test asserting the index `rel="canonical"` for page 1 does
     **not** contain `page=1`, locking in the behavior that the removed
     `trim` extra used to provide.
   * Add a test exercising an out-of-range page returns an empty page
     (HTTP 200, no records) rather than raising.
   * Add a test that the nav renders in a non-English locale (e.g. `fr`
     or `ru`) to confirm the `before_action` locale wiring.
   * Add tests for the cached count: the unfiltered index total is
     served from cache on a second request (no second `COUNT`), and a
     filtered/search request still reports an accurate fresh count.
   * Add a test that creating or destroying a project clears the cached
     `projects/index/count`, so the next unfiltered index request
     reflects the new total (in-process).
* **Manual / visual:**
   * Verify the bootstrap nav renders correctly under Bootstrap 3 on the
     projects index and a user's project list (prev/next, active page,
     gaps, first/last).
   * Verify First/Last links jump correctly and are hidden on the first
     and last pages respectively.

## Rollback

The change is isolated to the gem version, the pagy initializer, the
two application-wide includes (`application_controller.rb` and
`application_helper.rb`), the projects and users controllers, the
`Project` model `after_commit`, three views, the added locale keys, and
one cached count. If a problem surfaces, revert the branch (or pin back
to `pagy '~> 9.0'` and restore the previous initializer) and redeploy.
The cached count is ephemeral (it expires on its own and is cleared by a
restart); there are no database or data migrations involved.

## References

* Pagy "Upgrade to 43" guide:
  <https://ddnexus.github.io/pagy/guides/upgrade-guide/>
* Pagy changelog: <https://ddnexus.github.io/pagy/changelog/>
* `series_nav` helper: pagy source
  `gem/lib/pagy/toolbox/helpers/bootstrap/series_nav.rb`
* `page_url` helper: <https://ddnexus.github.io/pagy/toolbox/helpers/page_url/>
* I18n module (thread-local locale): pagy source
  `gem/lib/pagy/modules/i18n/i18n.rb`
* Offset paginator and count (`Countable.get_count`, `count:` seed):
  pagy source `gem/lib/pagy/toolbox/paginators/offset.rb` and
  `gem/lib/pagy/modules/abilities/countable.rb`
* `:countish` paginator (count-in-URL, rejected): pagy source
  `gem/lib/pagy/toolbox/paginators/countish.rb` and
  `gem/lib/pagy/classes/offset/countish.rb`
* Keyset / Keynav paginators (future feed/sync option):
  <https://ddnexus.github.io/pagy/toolbox/paginators/keyset/>
* Production cache store (`:memory_store`, bounded):
  `config/environments/production.rb`
