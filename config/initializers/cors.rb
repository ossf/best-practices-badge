# frozen_string_literal: true

# Copyright the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Enable CORS to allow client-side JavaScript of other systems to
# make GET requests, but *only* get requests, from us.
# This is especially useful when requesting JSON.
# We do *not* share credentials using CORS.
# This configuration file also disables considering the "Accept:" HTTP header
# (the URL itself must be used to choose a format).

# Both are done in this same configuration file because
# Rails requires setting these configuration options in a particular order.
# I suspect the reason is that both affect the HTTP header attribute "Vary".

# Do *NOT* use the HTTP Accept header to decide what to send as output,
# because that interferes with using the CDN. Without this setting,
# Rails will produce different values (in some cases) depending on the
# HTTP "Accept" value, and thus will generate "Vary: Accept" (correctly).
# However, since different browsers will have
# different Accept header values, this Vary: Accept will mean that
# different browsers will not share a CDN cached value.
# By setting ignore_accept_user, users *must* use the URL to request a
# non-default format. In compensation, this setting
# speeds average response time & reduces server load by better using the CDN.
# See:
# https://www.smashingmagazine.com/2017/11/understanding-vary-header/
# https://www.fastly.com/blog/getting-most-out-vary-fastly
# https://developer.mozilla.org/en-US/docs/Web/HTTP/
# Content_negotiation/List_of_default_Accept_values

Rails.application.config.action_dispatch.ignore_accept_header = true

# Typically CORS users will request the JSON files, e.g., by using
# using the suffix ".json" on the resource. We do allow requests to
# some non-JSON resources, in case it's useful.

# There are some complications in the interaction of CORS and the
# HTTP Heading 'Vary'.  For more information, see:
# https://www.fastly.com/blog/best-practices-using-vary-header
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept

# It should be fine to allow "GET" and "OPTIONS" on any request,
# since we require credentials for anything non-public.  However,
# we only allow CORS access for specific resources, out of an abundance
# of caution.  We allow "/" just to make testing easy.
# It's really "GET" that we want to allow, but we allow OPTIONS
# in case a web browser decides to make a pre-flight request.

CORS_ALLOWED_METHODS = %i[get options].freeze

# Many resources we allow CORS requests for *might* differ depending on
# who is asking. In these cases we use the default CORS value for
# the HTTP Header 'Vary', which is 'Accept-Encoding, Origin':
# * 'Accept-Encoding' is necessary because different browsers accept
# different compression algorithms. Fastly normalizes this when we pass
# it through Fastly, so this doesn't have a negative impact.
# * 'Origin' is often necessary for security. In some cases we vary the output
# depending on rights of the requestor. The browser would cache that.
# If JavaScript from another origin then requested the same data, and
# the 'Origin' was not included, the browser might return the cached
# result (even though the origin might not have the same rights).
#
# This does mean different origins cannot share any caches.
#
# We do not include 'Accept' in the default Vary setting in CORS.
# We instead want people to use different URLs for different
# output formats. This behaves *much* better with various caching systems
# in the web ecosystem. If we wanted to seriously support using 'Accept'
# for "ambiguous" URLs (which could return more than one format) then in
# those cases the controllers would need to add this:
# response.set_header('Vary', 'Accept')
# this would let browser caches know to check the 'Accept' HTTP value.

# We use regular expressions to define the patterns;
# the library also supports string matching, but it's not very precise
# and there's no way to express priority.
# With regular expressions we can express the patterns unambiguously.

# Build criteria level pattern from canonical lists defined in
# config/initializers/01_section_names.rb
# This ensures CORS patterns stay in sync with routing constraints
# Sections::VALID_NAMES includes all canonical and obsolete section names
CRITERIA_LEVEL_PATTERN = Sections::VALID_NAMES.join('|')

CORS_DIFFERENTIATED_RESOURCE_PATTERNS = [
  # Match projects with optional ID and optional criteria level (numeric or named)
  # Pattern auto-updates when new levels are added to routes.rb canonical lists
  %r{\A/([a-z]{2}(-[A-Z]{2})?/)?projects(/[1-9][0-9]*(/(#{CRITERIA_LEVEL_PATTERN})(/edit)?)?)?\z},
  %r{\A/([a-z]{2}(-[A-Z]{2})?/)?project_stats\z},
  %r{\A/([a-z]{2}(-[A-Z]{2})?/)?users/[1-9][0-9]*\.json\z}
].freeze

# For some resources we are absolutely *certain* that their results
# are undifferentiated, no matter who requests it or what its origin is.
# This is, in particular, true for /projects/:id/badges(.json).
# In this case Vary only includes Accept-Encoding, and *not* an Origin.
# Out of an abundance of caution we only include resources if we are
# *certain* about this. It's true for badges (SVG/JSON), and that's the
# important case because we want to ensure that the CDN can share them
# across all users. By omitting "Origin" for these, we significantly
# optimize use because any Origin will share the same CDN cache entry.
#
# Note: we do not include 'Accept' in the HTTP Header 'Vary' for
# /projects/:id/badge(.:format) resource because we *always* ignored
# the HTTP 'Accept' heading for selecting its data format (due to
# the way it gets routed). This is the most important case
# (because the CDN cache is shared globally); the fewer things we can
# put in 'Vary' for this important (highly optimized) case, the better.
#
# Note: This cannot be exploited to be misinterpreted as something else.
# The "*" does not match an embedded "/". Even if an attacker used "..",
# that would just produce useless "/badge" and "/badge.json" and so on.

CORS_UNDIFFERENTIATED_RESOURCE_PATTERNS = [
  %r{\A/([a-z]{2}(-[A-Z]{2})?/)?projects/[1-9][0-9]*/badge(\.json)?\z},
  %r{\A/([a-z]{2}(-[A-Z]{2})?/)?projects(/[1-9][0-9]*)?\.json\z},
  %r{\A/([a-z]{2}(-[A-Z]{2})?/)?project_stats(/[a-z0-9_]+)?\.json\z},
  %r{\A/assets/([A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)*)\z}
].freeze
CORS_UNDIFFERENTIATED_VARY = ['Accept-Encoding'].freeze

# NOTE: "Vary: Accept-Encoding" will still happen, but Fastly CDN
# normalizes this to one of a few values per:
# https://docs.fastly.com/en/guides/enabling-automatic-gzipping
# As a result, "Vary: Accept-Encoding" does *not* significantly impede
# CDN caching.

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'
    # "credentials" is false (not sent) by default.

    # 'Vary' does NOT include the Origin in undifferentiated resources.
    # In these cases the same result must always occur.
    # These undifferentiated rules must be first so they have higher priority.
    CORS_UNDIFFERENTIATED_RESOURCE_PATTERNS.each do |resource_pattern|
      resource resource_pattern, headers: :any, methods: CORS_ALLOWED_METHODS,
               vary: CORS_UNDIFFERENTIATED_VARY
    end

    # 'Vary' is the default, includes Origin.
    CORS_DIFFERENTIATED_RESOURCE_PATTERNS.each do |resource_pattern|
      resource resource_pattern, headers: :any, methods: CORS_ALLOWED_METHODS
    end
  end
end
