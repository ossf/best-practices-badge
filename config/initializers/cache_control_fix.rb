# frozen_string_literal: true

# Middleware to ensure proper cache control headers for CDN protection.
#
# Rails CSRF protection sets 'Cache-Control: no-cache', which incorrectly
# allows CDN caching. I've searched but found no way to control what it sets.
#
# This middleware fixes this by determining
# when the Cache-Control value is exactly 'no-cache'. When it is,
# the Cache-Control value is changed to 'private, no-cache', which means
# no CDN caching (private) and web browsers must verify before use (no-cache).
#
# To enable CDN caching, simply set Cache-Control to 'public, no-cache'.
# Since that is NOT exactly equal to 'no-cache', this shim will
# have no effect.
#
# Note: This is rack middleware, so it won't execute in test cases
# that don't go through rack middleware.
#
class CacheControlFixMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    result = @app.call(env)
    _status, headers, _body = result

    cache_control = headers['Cache-Control'] || headers['cache-control']
    headers['Cache-Control'] = 'private, no-cache' if cache_control == 'no-cache'

    # Always return original result array to avoid unnecessary object creation
    result
  end
end

# Insert this middleware into the stack. Since middleware wraps the entire
# request/response cycle, this will process the response after Rails
# controllers have set their cache control headers.
Rails.application.config.middleware.use CacheControlFixMiddleware
