# frozen_string_literal: true

# Copyright the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Rack middleware that marks a static file "immutable" (cacheable for a
# year by browsers and the CDN) only if its URL is fingerprinted, i.e.,
# includes a cryptographic hash derived from its content. Then any content
# change produces a new URL, so a cached copy can never be stale.
#
# Everything else in public/ (e.g., /404.html) keeps the shorter DEFAULT
# set via config.public_file_server.headers. Never put "immutable" there:
# it applies to *every* file in public/, and we once served security.txt
# and an empty /favicon.ico that way, so fixes couldn't reach caches.
# Deriving immutability from the URL means a new file can't get it by
# accident.
class FingerprintedAssetCacheMiddleware
  # Cache-Control for public/ files whose URL doesn't change with content.
  # Use as the value of config.public_file_server.headers.
  DEFAULT_HEADERS = { 'cache-control' => 'public, max-age=86400' }.freeze

  # 31536000 seconds = 365 days, the conventional "forever".
  IMMUTABLE = 'public, s-maxage=31536000, max-age=31536000, immutable'

  # Sprockets fingerprints precompiled assets as NAME-SHA256HEX.EXT,
  # e.g., /assets/favicon-f098...588f.ico (64 lowercase hex digits).
  # That SHA-256 covers the content plus pipeline settings (such as
  # config.assets.version), so it isn't the file's plain hash, but
  # any content change still changes it.
  FINGERPRINTED = %r{\A/assets/(?:[^/]+/)*[^/]+-[0-9a-f]{64}\.[^/]+\z}

  # Statuses the static file server returns for a served file.
  CACHEABLE_STATUSES = [200, 206, 304].freeze

  # @param path [String] the request path (no query string)
  # @return [Boolean] true iff the path is a fingerprinted asset URL
  def self.fingerprinted?(path)
    FINGERPRINTED.match?(path)
  end

  def initialize(app)
    @app = app
  end

  def call(env)
    # Check the path *before* calling the app: a mounted app can change
    # PATH_INFO. E.g., when assets aren't precompiled (as in CI), Sprockets'
    # server mounted at /assets serves them and strips that prefix.
    fingerprinted = self.class.fingerprinted?(env['PATH_INFO'])
    result = @app.call(env)
    status, headers, _body = result
    if fingerprinted && CACHEABLE_STATUSES.include?(status)
      headers['cache-control'] = IMMUTABLE
    end
    # Return the original array to avoid unnecessary object creation.
    result
  end
end
