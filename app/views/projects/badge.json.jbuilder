# frozen_string_literal: true

# JSON data doesn't depend on locale.
# Do NOT add fragment caching (json.cache!) here. The fragment cache key embeds
# updated_at, but update_all_badge_percentages uses save!(touch: false), so
# updated_at does not change when criteria rules are recalculated. When that
# recalculation purges this project from the CDN, the CDN would re-fetch from
# Rails, receive the stale fragment, and re-cache stale data for 10 days.
# Fastly's CDN TTL is the primary cache; rendering this small template on a
# CDN miss is cheap by comparison.
json.id @project.id
json.name @project.name
json.updated_at @project.updated_at
json.badge_level @project.badge_level
json.tiered_percentage @project.tiered_percentage
