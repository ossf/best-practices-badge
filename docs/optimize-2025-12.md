# Optimizations of 2025-12

This document briefly explains optimizations done in December 2025
(and extended through January 2026) for the best practices badge project.
These were done to handle the changes in the web environment
as well as prepare for baseline criteria support.

## Background

When this application was originally developed, web
crawlers tended to be gentler. Occasionally a web crawler
would be unreasonably demanding, but this would only happen sporatically,
and most crawlers had limited rates and would respect robots.txt.
We implemented rate limiters to automatically limit the worst
offenders, primarily to automatically counter temporary DDoS attacks.
We assumed that crawlers would only show up occasionally, as relatively
few organizations would run them, and
that they would go away once they were done.

However, that is not true any more.
Modern AI systems are built on machine learning (ML),
which in turn require lots of data.
Organizations want to gather that data themselves or buy it from others.
As a result, many organizations are now
maximally and repeatedly downloading the internet to get training data:

* ["AI web crawlers are destroying websites in their never-ending hunger for any and all content: But the cure may ruin the web..." by Steven J. Vaughan-Nichols, Fri 29 Aug 2025, *The Register*](https://www.theregister.com/2025/08/29/ai_web_crawlers_are_destroying/), [discussed on Hacker News](https://news.ycombinator.com/item?id=45105230)
* ["The Internet Is Being Overrun by AI Bots — And Websites Are Paying the Price" by Sharon Fisher, October 31, 2025, VKTR](https://www.vktr.com/ai-technology/the-internet-is-being-overrun-by-ai-bots-and-websites-are-paying-the-price/)

As with many websites, historically
this site gradually increases in the memory it uses as requests are made,
with a brief restart (typically daily) for some housekeeping.
The site was also written to be simple and easy-to-maintain, instead of
focusing on performance.
The only area we focused on was delivering badges at scale, which we
implement through a CDN.
Historically this approach wasn't a problem, but now it is.

The website's data is now being downloaded so often
that it occasionally automatically failed and restarted as it
exceeded its memory allocations.
The fail-over is a last-ditch effort to recover, and we want that to be
an exceedingly rare event.
It was also at long-term risk of not keeping up with the massive demands
now being placed on it.

The most popular pages, by far, are the `/(:locale/)projects/*` pages, as
almost all pages are in this hierarchy. The data for every project, in
every section, in every locale, is here. We also provide this data in HTML,
JSON, and markdown formats, as well as badges in SVG format.
Thus, for us, it's important to optimize these pages in particular,
because when a web scraper scrapes our site, most of the resources are here.

We also want to add more support for baseline criteria. However, adding
more baseline support without any *other* optimizations would
have increased the burden further, because we'd have more pages to serve.
So we really needed to solve this problem so we could support baseline.

## Underlying problem

The fundamental problem was that when this application was developed
efficiency was much less important than it is now. Originally,
on every request to the application:

* Many objects (particularly strings) were created,
  which later needed to be collected by the garbage collector.
* More computation was done than strictly necessary on each request.
  For example, sometimes objects were re-created on each request,
  which again had to be garbage collected,
  instead of creating them once on system startup and reusing them later.
  The Rails router often did a lot of extra work to determine how
  to route a request.

Some technical details are important here:

* Like many systems, we use an Object-Relational Mapping (ORM) library.
  The one we use is called ActiveRecord and is part of Rails.
  An ORM converts data from a relational database into an object that's
  easy to use in an OO language. In most languages (including Ruby, Python,
  and JavaScript), creating that ORM object will also create many
  more *other* objects to represent the
  various data fields that were loaded into it
  (e.g., it will create a string object for every string value loaded into
  the ORM object to represent some field's value).
  By default, ORMs usually copy all fields into
  an object, but if those fields aren't used, this can do a lot of unnecessary
  work and create a lot of useless objects.
* Every creation of a new empty string creates extra work, as the string
  object has to allocated and later garbage collected.
  In the usual CRuby implementation, if a
  string is "large enough" there are actually two memory regions in
  use for a string: one memory region for the string object representing itself,
  and a separate memory region for the string content.
  In some cases string objects can be shared, but in other cases they aren't.
  Strings in Ruby can be mutable aka unfrozen, and these can't be shared
  (if they were, modifying one would modify the others).
  Many libraries return unfrozen strings, and since they can't be shared,
  this can cause a lot of memory allocations.
  In Ruby and *many* other languages,
  it's far more efficient to use small integers or nil, because these
  don't trigger new allocations that use up memory. Since they don't
  trigger allocations they also don't require garbage collection.

## Solutions

To handle this new world of massive number of requests, we did the following:

1. Optimize the Rails router. When this application receives
   a request, it must first be routed to where it can be processed.
   The router had become a complicated mess that did a lot of extra
   work and was getting hard to maintain. It was a lot of work to simplify it!
   It's now much simpler and does much less work to route the work to
   the correct method. This will also make later maintenance easier.
   See the [routes consolidation plan](routes-consolidation-plan.md).
   See also PR #2560 / commit 55fac098e109b34f0b158edad908691491840317,
   PR #2561 / commit 5efc979b9d0fd7af80c39f2f1f483e531933d469, and
   PR #2563 / commit 0c69b9934c7b64be1f0b7150bc34dd5822b13548
2. When loading project data, we *only* load the fields we intend to use.
   This greatly reduces the number of objects created when we create the
   corresponding ORM object for the project - we don't create objects for
   fields we *know* we won't use.
   See commit 90e62bfd124da1db0d8354d435eb3a093e194ab7.
3. Change the edit HTML pages to *only* show specific sections.
   In particular, our URLs now forbid the general case (if you try to edit
   without naming a section, it'll redirect to a default section).
   This makes our optimization to only load certain fields more effective.
4. Convert all `XYZ_status` internal values into
   integers 0..3 instead of strings like `Met`.
   This was called "status enum as small ints" approach.
   Small integers don't require separate allocation nor deallocation,
   and since they're stored in the database as a smallint (the smallest
   portable SQL value) they take less space in the database too.
   NULL is not allowed; 0 represents `?` (Unknown). A 3 represents `Met`.
   These are converted when they enter and leave the external application,
   so this change is invisible to clients.
   We want that; integers don't have any obvious meaning, while the strings
   have a clear meaning.
   Conceptually this change was easy, but it practice it had a lot of fiddly
   bits because criteria status information is *all* over the application.
   See the [enum optimization](enum-optimization.md) information, as well as
   enum plan PR #2564 / commit 77b3a0cf75f3b3abbdf6604dc8badde0a2c7efc7 and
   PR #2566 / commit 55d696cca63c8ef258b7f8e509f1cba2b39747a1.
5. Convert all `X_justification` values
   that are empty strings into the NULL database value (which is
   represented as `nil` in Ruby). These don't require separate allocations
   like empty strings do, and since there are many empty strings, this
   is a significant improvement. See the
   [empty justification string as null](empty-justification-string-as-null.md)
   document for more information.
6. In many places, pre-compute a constant *once*, then use it, instead
   of recomputing it each time. Sometimes the ORM prefers a string and will
   convert other constructs into strings, so we do that pre-conversion
   to a string ahead-of-time and store that as a constant, to avoid
   unnecessary repeated computations. Each of these changes typically only
   helps a tiny bit, but this work is cumulative. As we pre-compute more things,
   that means there's less growth in memory use, and the garbage collector
   has less work to do (because there are fewer objects for it to examine
   to determine if they're still in use). For examples, see commit
   4815499cfeec65463557c414b9ce5a74bf6e4085 or PR #2553 /
   commit 21af8d819205aa6dfc8f953c032a69335beede44 or
   commit e87826e9d51645be3f5c981cdebb33bdd7a2477f or
   commit bd43ca53e9987a3481ca56edaa5c56b8d6fcefcc.
7. Optimize common cases. I especially focused on optimizing the /projects
   resources since that's where most pages are.
8. Don't call the markdown processor for trivial cases where it makes
   no difference. In many cases only trivial strings are provided, and
   this change avoids unnecessary work to process the strings. Now 80.6% of the
   non-empty justification texts can be processed quickly without using the
   markdown processor. (Note: In January 2026 this was improved further,
   so 83.87% of non-empty justification texts can be processed without
   the markdown processor). That process now generates fewer objects, so
   as a result processing most justification is faster than before.
   This is even more important because the markdown processor can't
   handle multi-threading, even though its documentation says it works.
   We compensate by ensuring only one thread can use it at a time, but
   if we *always* called the processor that would slow things down.
9. We improved garbage collection compaction.
   We earlier added periodic garbage collection compaction, to more quickly
   collect garbage. In December 2025 I adjusted the run-time configuration
   to be shorter than 2 hours. This meant that there
   was less time for unused objects to accumulate in memory, leading to
   less maximum memory use.
   In January 2026 I modified the garbage collection compaction code further,
   to ensure it was always called; we originally intercepted the rake
   middleware to enable scheduling later, but this turned out to be unreliable.
   By *itself* we would still have had memory use exceeded,
   and we want to limit compaction events (since they cause pauses),
   so we still needed to take other steps.
10. Provided capacity (size) information when creating some hashes when we
   know their final size. Ruby will automatically resize when needed, but
   provide final size information ahead-of-time,
   Ruby doesn't need to keep resizing them, improving performance.

Note that this optimization work continued in January 2026.
Again, it was all focused on avoiding unnecessary work.
Examples included:

1. Modifying the garbage collector to trigger compaction only when
   excessive space used, instead of a particular time, so we only run
   compaction when we must.
2. Optimize the `project_stats` controller so that showing statistics
   didn't need to create as many memory allocations. This dramatically sped
   up showing our charts. See commit
   298a4a217c3ac9bdb05c650090d44dadda1ea1be.
3. Optimize showing users (e.g., reduce memory allocations and skip
   unnecessary computations). See commit
   31b6972b9dd55458da78651b3b26520d572c89f4 and commit
   790eaf66fa1c7e8590f1e014d509106cce3ae77c.
4. Optimize memory use when generating JSON. See commit
   0417227f30b680eb57ae335f333740d7ddf77a2b.
5. Avoid calling the markdown processor when it's unnecessary, again,
   to reduce computation time and unnecessary memory allocations.
6. Refactor session authentication and logged-in-user management so we
   avoided unnecessary database queries. E.g., see commit
   2ba0a2cc03216efc0a353b2bf2ef82d814c09d66 and commit
   d4844baf435f7d398040a811cc596979dc0d84a4.
7. Skip authentication for badge and project JSON data, since it's
   not needed.

## Impact

These changes produced a massive cumulative improvement on the
best practices badge application.

We were hitting restarts a few times a day from massively exceeding
our memory limits ("memory quota vastly exceeded").
We think we won't be hitting them any more with our optimized system.
Because each request does less work, each requests complete more quickly,
so single-request performance is faster.
We may even be able to increase the number of threads, which will
increase the number of simultaneous requests a single worker
processor can handle, improving overall throughput even further.
