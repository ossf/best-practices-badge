# Internal cache analysis

This application has an internal cache, in particular
its fragment cache system. When often-reused items are
cached and reused, that can *greatly* reduce the load on the system.

However, every cache check must create and use a cache key
(which itself does memory allocations and takes time), and
every cached value must be retrieved often enough to be worth it
(else it will use up memory until evicted and take up space
better used elsewhere.

We have a system for measuring cache hits to see which
requests for a cache are actually useful. Basically, you enable
cache profiling (which stores data in tmp/) in the application,
and run a stress test like this:

~~~~sh
CACHE_PROFILE=1 rails s
script/memory_stress_test.rb --crawler --duration 2h^C
~~~~

It's important that the stress test be representative of real data.
When we originally set up our cache system, we presumed that we would
only occasionlly undergo a web spider, and that most requests would be
from users editing their pages (which would focus on specific projects in
a specific locale). Today, the site undergoes relentless spidering.
This massive change in our typical input profile means that the
correct caching strategy has to change too.

## Initial results

Here are the initial results as of 2026-01-29.

~~~~
CACHE REMOVAL CANDIDATES BY SOURCE (least effective first)
================================================================================

1. views/layouts/application.html.erb:40
   Code: <% cache_frozen request.original_fullpath do -%>
   Score: 40.7/100 | Hit rate: 0.0%
   Hits: 0 (0.0 allocs/hit = overhead cost)
   Misses: 11254 (533.3 allocs/miss = render cost)
   Problems: hit rate 0.0%
   Unique keys: 11254

2. views/projects/_table.html.erb:23
   Code: <% cache_frozen [project, locale], expires_in: 12.hours do %>
   Score: 46.6/100 | Hit rate: 52.1%
   Hits: 13173 (49.3 allocs/hit = overhead cost)
   Misses: 12102 (264.0 allocs/miss = render cost)
   Problems: hit rate 52.1%, 49 allocs/hit (overhead)
   Unique keys: 19243

3. views/layouts/_header.html.erb:36
   Code: <% cache_frozen [I18n.locale, request.original_fullpath] do %>
   Score: 49.0/100 | Hit rate: 0.0%
   Hits: 0 (0.0 allocs/hit = overhead cost)
   Misses: 11263 (951.5 allocs/miss = render cost)
   Problems: hit rate 0.0%
   Unique keys: 11263

4. views/criteria/show.html.erb:1
   Code: <% cache_frozen [locale, @criteria_level, @details, @rationale, @autofill] do -%>
   Score: 50.0/100 | Hit rate: 0.0%
   Hits: 0 (0.0 allocs/hit = overhead cost)
   Misses: 13 (4524.9 allocs/miss = render cost)
   Problems: hit rate 0.0%, low samples (13)
   Unique keys: 13

5. views/criteria/index.html.erb:1
   Code: <% cache_frozen [locale, @details, @rationale, @autofill] do -%>
   Score: 76.8/100 | Hit rate: 99.4%
   Hits: 269784 (35.0 allocs/hit = overhead cost)
   Misses: 1557 (376.9 allocs/miss = render cost)
   Unique keys: 1557

6. views/layouts/_footer.html.erb:1
   Code: <% cache_frozen locale do -%>
   Score: 91.2/100 | Hit rate: 99.7%
   Hits: 22491 (29.0 allocs/hit = overhead cost)
   Misses: 63 (7686.5 allocs/miss = render cost)
   Unique keys: 9

--------------------------------------------------------------------------------
Total source locations: 20, Analyzed: 43339 keys

Score interpretation:
  - Low score + high allocs/hit: expensive overhead, consider removing
  - Low score + low hit rate: cache not being reused, consider removing
  - High allocs/miss: rendering is expensive, cache may still be valuable
~~~~
