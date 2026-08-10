# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Redirect to canonical URL as needed, using some of our Rack middleware.
# See: "Avoiding SEO Duplicate Content Issues with Ruby and
# Rack Middleware" by Brent Ertz, 7/24/2012, https://quickleft.com/
# blog/avoiding-seo-duplicate-content-issues-with-ruby-and-rack-middleware/

module Rack
  # If we get a URL with a trailing slash other than "/", redirect to
  # a page without the trailing slash so that we have a single
  # canonical URL format.
  class CanonicalizeTrailingSlash
    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new env
      if %r{^/(.*)/$}.match?(request.path_info)
        # Clean up URL and redirect a different URL (use string interpolation for memory efficiency)
        query_suffix = request.query_string.empty? ? '' : "?#{request.query_string}"
        url = "#{request.base_url}#{request.path.chomp('/')}#{query_suffix}"
        [301, { 'Location' => url, 'Content-Type' => 'text/html' }, []]
      else
        # Nothing to do, continue chain.
        @app.call env
      end
    end
  end
end

Rails.application.config.middleware.insert_before(
  0,
  Rack::CanonicalizeTrailingSlash
)
