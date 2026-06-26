# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'ipaddr'

# Base controller for the Best Practices Badge application.
# Provides common functionality including session management, security headers,
# locale handling, HTTPS enforcement, and CDN cache configuration.
# All other controllers inherit from this class.
#
# rubocop: disable Metrics/ClassLength
class ApplicationController < ActionController::Base
  include Pagy::Backend

  # Frozen HTTP header values (memory optimization - avoid creating on every request)
  PERMISSIONS_POLICY_VALUE = 'fullscreen=(), geolocation=(), midi=(), ' \
                             'notifications=(), push=(), sync-xhr=(), microphone=(), ' \
                             'camera=(), magnetometer=(), gyroscope=(), speaker=(), ' \
                             'vibrate=(), payment=()'

  FEATURE_POLICY_VALUE = "fullscreen 'none'; geolocation 'none'; midi 'none';" \
                         "notifications 'none'; push 'none'; sync-xhr 'none'; microphone 'none';" \
                         "camera 'none'; magnetometer 'none'; gyroscope 'none'; speaker 'none';" \
                         "vibrate 'none'; payment 'none'"

  # Security Configuration Constants (gathered once at startup)
  # The trusted proxies' IP addresses are *not* being used for user
  # authentication; they're being used to counter CDN piercing and to
  # ensure that our rate limits apply to the correct IP addresses.
  TRUSTED_PROXIES_DISABLED = ENV['TRUSTED_PROXIES_DISABLED'] == 'true'
  ENFORCE_ORIGIN_SHIELDING =
    ENV['ENFORCE_ORIGIN_SHIELDING'] == 'true' && !TRUSTED_PROXIES_DISABLED

  # Name of the Rails session cookie, read from config so this stays correct
  # if the key is ever renamed (see config/initializers/session_store.rb).
  SESSION_COOKIE_NAME = Rails.application.config.session_options[:key]

  # Session keys that are framework bookkeeping, not real per-user content:
  # Rack's always-present session_id and the flash.
  # Method drop_unneeded_session_cookie
  # ignores these when deciding whether the session still holds anything.
  SESSION_BOOKKEEPING_KEYS = %w[session_id flash].freeze

  # Make criteria_level conversion methods available to views
  helper_method :criteria_level_to_internal, :normalize_criteria_level

  # Validate client IP address (if only some IP addresses are allowed);
  # counters cloud piercing.
  before_action :validate_client_ip_address

  # Force http -> https
  before_action :redirect_https?

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  # If locale is not provided in the URL, redirect to best option.
  # Special URLs which do not have locales, such as "/robots.txt",
  # must "skip_before_action :redir_missing_locale".
  before_action :redir_missing_locale

  # Set the locale, based on best available information.
  # The locale in the URL always takes precedent, so normally that's
  # what is set here.
  before_action :set_locale_to_best_available

  # Extract and validate authentication state from session.
  # Sets instance variables (@session_user_id, etc.) that are guaranteed
  # valid after this completes from the point-of-view of a signed session.
  # The @session_user_id will be nil if the user isn't logged into a session.
  # The user account might have been deleted after the user logged in;
  # request method `current_user` to get the current user data.
  # This before_action handles session timeout and the remember token.
  before_action :setup_authentication_state
  after_action :update_session_timestamp
  after_action :drop_unneeded_session_cookie

  # For the PaperTrail gem. We must call this *after* the action
  # `setup_authentication_state`; this action calls
  # our method `user_for_paper_trail` which reads from @session_user_id.
  # We do things this way so we can easily record the user id without
  # always requiring a database lookup about the user.
  before_action :set_paper_trail_whodunnit

  # Use the new HTTP security header, "permissions policy", to disable things
  # we don't need.
  before_action :add_http_permissions_policy

  # Set the default cache control, which inhibits external caching.
  # If you *want* caching, you must apply:
  # skip_before_action :set_default_cache_control
  # Also, if you're disabling cache control, it's likely there's no user
  # authentication (and thus no authorization), so you might also want to:
  # skip_before_action :setup_authentication_state
  # We use before_action and override CSRF cache control
  before_action :set_default_cache_control
  before_action :verify_origin_shielding

  # Append user information to the log payload for request tracking.
  # Records the current user's ID in logs when user is logged in.
  #
  # @param payload [Hash] The log payload hash to append information to
  # @return [void]
  # https://github.com/roidrage/lograge/issues/23
  def append_info_to_payload(payload)
    super
    payload[:uid] = current_user&.id if logged_in?
  end

  # Verify that the request came through a trusted edge proxy (shielding).
  #
  # The trusted proxies' IP addresses are *not* being used for user
  # authentication; they're being used to counter CDN piercing and to
  # ensure that our rate limits apply to the correct IP addresses.
  #
  # In our infrastructure, the "Heroku Router" is the immediate connection.
  # It identifies the IP address it received the request from and appends
  # it to the "X-Forwarded-For" (XFF) header.
  #
  # If the request is properly shielded, it must have come from our CDN
  # (Fastly). In that case, the last IP in the XFF chain will be a Fastly IP.
  #
  # If an attacker hits our Heroku origin directly, the Heroku Router
  # will append the attacker's direct IP to the end of the chain.
  # Even if the attacker tries to spoof the header by providing their
  # own XFF values, the router will still append their true IP to the
  # very end.
  #
  # We check this "anchor" IP against our trusted edge proxy list.
  # @return [void]
  def verify_origin_shielding
    return unless ENFORCE_ORIGIN_SHIELDING

    # The last IP in X-Forwarded-For is the one that reached the Heroku router.
    # Using forwarded_for.last is blazingly fast and avoids private API hacks.
    last_proxy = request.forwarded_for&.last
    return if SecurityUtils.edge_proxy?(last_proxy)

    render plain: '403 Forbidden - Direct origin access not allowed',
           status: :forbidden
  end

  # Override PaperTrail's default user extraction.
  # Returns the user ID directly from @session_user_id (set by
  # setup_authentication_state), avoiding an unnecessary database query.
  # PaperTrail only needs the integer user ID to log who made changes.
  # This is called by the set_paper_trail_whodunnit before_action callback.
  # There is a weird case: it's possible that the user logged in and the
  # user account has since been deleted. In this case, papertrail will
  # correctly log the user id, even though the user record is no longer
  # available in the database. We don't reuse user ids, so this will simply
  # record correct information even in this odd circumstance.
  #
  # @return [Integer, nil] The current user's ID, or nil if not logged in
  def user_for_paper_trail
    @session_user_id
  end

  # How long (in seconds) will the badge be stored on the CDN before being
  # re-requested? This is used by set_cache_control_header.
  # A longer time reduces server load, but if we produce a wrong/obsolete
  # answer it will be wrong/obsolete for this long unless we explicitly purge.
  # 86400 = 1 day, 864000 = 10 days
  BADGE_CACHE_MAX_AGE = (ENV['BADGEAPP_BADGE_CACHE_MAX_AGE'] || '864000').to_i

  # How long (in seconds) will the badge be served by the CDN if it can't
  # get a response from us?
  # This provides a safety measure if the site goes down;
  # the CDN will keep serving *some* data for a while.
  # 864000 = 10 days, 1728000 = 20 days, 8640000 = 100 days
  # We force it to be at least twice the BADGE_CACHE_MAX_AGE.
  # Override with BADGEAPP_BADGE_CACHE_STALE_AGE env var.
  BADGE_CACHE_STALE_AGE = [
    (ENV['BADGEAPP_BADGE_CACHE_STALE_AGE'] || '8640000').to_i,
    2 * BADGE_CACHE_MAX_AGE
  ].max

  # Delay in seconds before a delayed purge
  BADGE_PURGE_DELAY = (ENV['BADGEAPP_PURGE_DELAY'] || '8').to_i

  # Combined cache control header value for CDN surrogate control
  BADGE_CACHE_SURROGATE_CONTROL =
    "max-age=#{BADGE_CACHE_MAX_AGE}, stale-if-error=#{BADGE_CACHE_STALE_AGE}".freeze

  # Kill switch: set BADGEAPP_CACHE_UNCHANGING=false to instantly stop caching
  # the "unchanging" pages (home, cookies, criteria discussion/stats, criteria
  # index/show) -- pages whose rendered output does not change while the
  # application runs (only on deploy) -- falling back to private, no-store
  # without a redeploy. Mirrors CACHE_SHOW_PROJECT.
  # See docs/cdn-cache-not-logged-in.md Section 10.
  CACHE_UNCHANGING_PAGES = ENV['BADGEAPP_CACHE_UNCHANGING'] != 'false'

  # One shared surrogate key for every "unchanging" page, so a single purge
  # refreshes all of them. Deliberately NOT per-page: these pages all change
  # together (only on deploy), and one key avoids a purge_all that would
  # needlessly evict the valuable project-show, JSON, and badge caches.
  UNCHANGING_SURROGATE_KEY = 'unchanging'

  # Fewer pages are cacheable than you might initially expect.
  # Most of the pages on this site vary depending on whether or not
  # you're logged in (because the header varies), so we can't cache most
  # of the pages. Many pages can also display a "flash" error message
  # and/or have CSRF protections that are per-user.
  # If we ever change the system so that the pages are mostly
  # the *same* regardless of the logged-in situation and whether or not
  # flashes were present, we could be more aggressive about caching.

  # Set default cache control - don't externally cache.
  # This is the safe behavior, so we make it the default.
  # This is NOT called for static images which are handled separately.
  # @return [void]
  def set_default_cache_control
    # Override Rails default behavior by setting stricter cache control
    # This will be our baseline, and if CSRF protection overrides it,
    # we'll handle that in the after_action
    response.headers['Cache-Control'] = 'private, no-store'
  end

  # *CACHE* this on the CDN, but do *NOT* cache it elsewhere.
  # Calls which use this must ALSO apply:
  # skip_before_action :set_default_cache_control
  # and should set:
  # set_surrogate_key_header VALUE
  # More info:
  # - https://docs.fastly.com/en/guides/configuring-caching
  # - https://docs.fastly.com/en/guides/serving-stale-content
  # Simulates what this did: https://github.com/fastly/fastly-rails
  # In particular:
  # https://github.com/fastly/fastly-rails/blob/master/lib/fastly-rails/
  # @return [void]
  # rubocop:disable Naming/AccessorMethodName
  def cache_on_cdn
    # Configure our CDN (Fastly) to cache data for a while, and
    # serve old data if the system has an error for some reason.
    # In deployment this heading is *only* used by the CDN, and is stripped
    # so that it does *not* go to client browsers.
    response.headers['Surrogate-Control'] = BADGE_CACHE_SURROGATE_CONTROL

    # Set the cache values control values.
    # We originally used the value 'public, no-cache'.
    # The value 'no-cache' is a standard but misleading name, it permits
    # the web browser to have a *local* cache but it requires the web
    # browser to revalidate the data before each use, and this direction
    # is ignored by the CDN (Fastly). The
    # 'public' simply means "anyone can store a copy".
    # However, this doesn't work because GitHub ignores this directive
    # when caching, and many users use GitHub:
    # https://docs.github.com/en/authentication/
    # keeping-your-account-and-data-secure/about-anonymized-urls
    # Their recommended solution is to use 'no-store', disabling their caching.
    response.headers['Cache-Control'] = 'no-store'
    omit_session_cookie
  end

  # Sets CDN surrogate key headers for cache management.
  # The keys are normally created via methods in the model.
  # Enables targeted purging of cached content by surrogate keys.
  # See: https://github.com/fastly/fastly-rails
  #
  # @param surrogate_keys [Array<String>] Keys for cache identification
  # @return [void]
  def set_surrogate_key_header(*surrogate_keys)
    # request.session_options[:skip] = true  # No Set-Cookie
    response.headers['Surrogate-Key'] = surrogate_keys.join(' ')
  end
  # rubocop:enable Naming/AccessorMethodName

  # Cache an "unchanging" page on the CDN for anonymous users -- a page whose
  # rendered output does not change while the application runs (only on deploy).
  # Mirrors the projects#show HTML guard (cache only when the response carries
  # no per-user state). cache_on_cdn also calls omit_session_cookie, so no
  # Set-Cookie is emitted.
  #
  # Used as a before_action on qualifying actions; it runs after the inherited
  # set_default_cache_control before_action, so it correctly overrides the
  # private, no-store default for anonymous, flash-free HTML. The qualifying
  # actions issue no internal redirect, so committing cache headers in a
  # before_action (before the body runs) is safe; the browser-dependent locale
  # redirect is handled earlier by redir_missing_locale, which halts the chain
  # before this runs. See docs/cdn-cache-not-logged-in.md Section 10.
  # @return [void]
  def cache_unchanging_page_on_cdn
    return unless CACHE_UNCHANGING_PAGES
    return unless request.format.symbol == :html
    return if logged_in? || !flash.empty?

    set_surrogate_key_header UNCHANGING_SURROGATE_KEY
    cache_on_cdn
  end

  # Completely disables caching for sensitive pages.
  # Uses **no-store** to prevent any caching of the response.
  # @return [void]
  def disable_cache
    # Misleadingly, "no-cache" *allows* caching. We must use 'no-store'
    # Technically the 'private' is redundant, but it doesn't hurt, and it
    # helps avoid problems if there is a system that isn't quite compliant
    # with the specs. 'private, no-store' is a common though technically
    # unnecessary way to mark "these are really sensitive, don't record it".
    # https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cache-Control
    response.headers['Cache-Control'] = 'private, no-store'
    # We could remove header 'Surrogate-Control' but I found no need to do so.
  end

  # Omit session cookie.
  # This can improve performance and privacy for anonymous users by not sending
  # unnecessary session cookies when the session hasn't changed.
  #
  # **Important:** This has limited functionality.
  # - Don't display the longer header, as that depends on whether or not
  #   users are logged in, and we need the system to not cache that.
  #   Having a cookie makes it obvious to the CDN "don't cache this".
  #   In the longer term we may modify the system so that the header
  #   is constant and user-side JavaScript can omit items that can't be used,
  #   which would make the pages's CDN cache behavior MUCH better.
  # - Do not set flash messages after calling this method,
  #   as flashes are stored in the session.
  # - Don't set Rails CSRF tokens either, as they are also in the session.
  # Inspired by https://stackoverflow.com/questions/5435494/rails-3-disabling-session-cookies
  # You can verify this directly by running commands such as:
  # curl -svo ,out --max-redirs 10 http://localhost:3000/en
  # and verifying the absence of the header Set-Cookie header,
  # which would otherwise look like this:
  # Set-Cookie: _BadgeApp_session=..data--data..; path=/; HttpOnly
  # We have to send the cookie for logged-in users, or the CSRF counter
  # token might not be sent (it's set very late in the pipeline),
  # with the result that logged-in users couldn't log out (via /logout).
  # Don't call this routine from a session management function or a
  # page that leads to database changes (an edit page); those set the CSRF
  # counter token, so calling this routine will cause those actions to fail
  # @return [void]
  def omit_session_cookie
    request.session_options[:skip] = true
  end

  # Response formats that should not trigger locale redirects.
  # JSON and CSV are locale-independent, so don't redirect to add locale.
  DO_NOT_REDIRECT_LOCALE = %w[json csv].freeze

  # Normalizes a criteria level/section string to canonical URL form.
  # Handles numeric aliases ('0'→'passing', '1'→'silver', '2'→'gold'),
  # the common mistake 'bronze' (treated as 'passing'), and baseline
  # level names. Falls back to DEFAULT_SECTION for unknown inputs.
  # Note: most routes have constraints, but some don't, so we validate here.
  # @param level [String] raw level string from URL params or form input
  # @return [String] canonical level name ('passing', 'silver', 'gold',
  #   'permissions', 'baseline-1', etc.)
  def normalize_criteria_level(level)
    # Single hash lookup with default - O(1) performance
    Sections::INPUT_TO_CANONICAL[level] || Sections::DEFAULT_SECTION
  end

  # Converts a URL-friendly criteria level to the internal numeric form
  # used to select rendered partials (_form_0, _form_1, _form_2).
  # Falls back to '0' for unknown inputs.
  # Note: most routes have constraints, but some don't, so we validate here.
  # @param level [String] canonical or raw level string
  # @return [String] internal form: '0', '1', '2', 'permissions',
  #   or a baseline level string
  def criteria_level_to_internal(level)
    # Single hash lookup with default - O(1) performance
    Sections::INPUT_TO_INTERNAL[level] || '0'
  end

  private

  # Ensures all URLs include the current locale parameter.
  # Always includes locale in URLs for consistent internationalization,
  # even when the locale matches the default.
  # If there's no locale in the URL, that means we must use heuristics
  # to figure out what it should be and redirect to that locale.
  # Once we know the locale, we want to stick to it consistently.
  # To omit the locale for "en",
  # see this: http://stackoverflow.com/questions/5261521/
  # how-to-avoid-adding-the-default-locale-in-generated-urls
  # { locale: I18n.locale == I18n.default_locale ? nil : I18n.locale }
  #
  # @param options [Hash] Additional URL options to merge
  # @return [Hash] URL options with locale included
  # rubocop: disable Style/OptionHash
  def default_url_options(options = {})
    # Memory optimization: avoid merge allocation when options is empty (common case)
    return { locale: I18n.locale } if options.empty?

    # Merge locale into options copy to avoid creating intermediate hash
    options.merge(locale: I18n.locale)
  end
  # rubocop: enable Style/OptionHash

  # Fail if the client IP is invalid.
  # raise exception if text value client_ip isn't in valid_client_ips
  # @param client_ip [String] The client IP address to validate
  # @param allowed_ips [Array] Array of allowed IP addresses
  def fail_if_invalid_client_ip(client_ip, allowed_ips)
    return if client_ip.blank?

    client_ip_data = IPAddr.new(client_ip)
    return unless client_ip_data
    return if allowed_ips.any? do |range|
      range.include?(client_ip_data)
    end

    raise ActionController::RoutingError.new('Invalid client IP'),
          'Invalid client IP'
  end

  # Redirect http: to https: in normal production use.
  # See: http://stackoverflow.com/questions/4329176/
  #   rails-how-to-redirect-from-http-example-com-to-https-www-example-com
  # @return [void]
  def redirect_https?
    if Rails.application.config.force_ssl && !request.ssl?
      redirect_to protocol: 'https://', status: :moved_permanently
    end
    true
  end

  # Find the best-matching locale,
  # because the user did not specify a locale in the URL.
  # We use the following rules:
  # 1. Use the browser's ACCEPT_LANGUAGE best-matching locale
  # in automatic_locales (if the browser gives us a matching one).
  # 2. Otherwise, fall back to the I18n.default_locale value.
  # Note that the user can *ALWAYS* express the preferred locale in the URL.
  # We do *NOT* use cookies (these aren't RESTful and thus cause problems),
  # and users can always override with a URL even if their browser's locale
  # is not configured correctly.
  # We could use geolocation in the future, but we would only do so if
  # the user hasn't specified a locale in the URL *and* the browser hasn't
  # requested a locale.  Geolocation is problematic: some user's locales
  # will not be the common one in the geolocation, and we must avoid
  # online services that would leak user IP addresses to those services.
  # Browsers often provide ACCEPT_LANGUAGE (which in turn is often provided
  # by the operating system), so we should not need geolocation anyway.
  # @return [Symbol] best-matching locale
  def find_best_locale
    LocaleUtils.find_best_locale(request)
  end

  # If locale is not provided in the URL, redirect to best option.
  # NOTE: This is intentionally skipped by some calls, e.g., session create.
  # See <http://guides.rubyonrails.org/i18n.html>.
  # @return [void]
  def redir_missing_locale
    explicit_locale = params[:locale]
    return if explicit_locale.present?

    # Don't bother redirecting some formats
    return if DO_NOT_REDIRECT_LOCALE.include?(params[:format])

    #
    # No locale, determine the best locale and redirect.
    #
    best_locale = find_best_locale
    preferred_url =
      LocaleUtils.safe_localized_internal_url(request.original_url, best_locale)

    # Where we go varies by browser, so we can't cache this redirect
    disable_cache

    # It's not clear what status code to provide on a locale-based redirect.
    # However, we must avoid 301 (Moved Permanently), because it is certainly
    # not a permanent move.
    # We previously used use 300 (Multiple Choices),
    # because that code indicates there's a redirect based on agent choices
    # (which is certainly true), by doing this:
    # redirect_to preferred_url, status: :multiple_choices # 300
    # It worked on staging, but causes problems in production when trying
    # to redirect the root path, so we're using
    # "found" (302) which is supported by everyone.
    redirect_to preferred_url, status: :found
  end

  # Set the locale, based on best available information.
  # See <http://guides.rubyonrails.org/i18n.html>.
  # @return [void]
  def set_locale_to_best_available
    best_locale = params[:locale] # Locale in URL always takes precedent
    best_locale = find_best_locale if best_locale.blank?

    # Assigning a value to I18n.locale *looks* like a
    # global variable setting, and setting a global
    # variable would be bad since we're multi-threaded.
    # However, this is *not* setting a global variable, it's setting a
    # per-Thread value (which is safe). Per the i18n guide,
    # "The locale can be either set pseudo-globally to I18n.locale
    # (which uses Thread.current like, e.g., Time.zone)...".
    I18n.locale = best_locale.to_sym
  end

  # Validate client IP address if Rails.configuration.valid_client_ips
  # and header value X-Forwarded-For.
  # This can provide a defense against cloud piercing.
  # @return [void]
  def validate_client_ip_address
    return unless Rails.configuration.valid_client_ips

    client_ip = request.remote_ip
    fail_if_invalid_client_ip(client_ip, Rails.configuration.valid_client_ips)
  end

  # Use the new HTTP security header, "Permissions policy", to disable things
  # we don't need. It was formerly named "feature policy" with a slightly
  # different syntax. See:
  # https://scotthelme.co.uk/goodbye-feature-policy-and-hello-permissions-policy
  # https://httptoolkit.tech/blog/renaming-feature-policy-to-permissions-policy
  # https://scotthelme.co.uk/a-new-security-header-feature-policy/
  # Note that this *gives up* fullscreen & sync-xhr; if we need it later,
  # change the policy.
  # @return [void]
  def add_http_permissions_policy
    response.set_header('Permissions-Policy', PERMISSIONS_POLICY_VALUE)
    # Include the older Feature-Policy header, for older browser versions.
    # We can eventually drop this, but it doesn't hurt to include it for now.
    response.set_header('Feature-Policy', FEATURE_POLICY_VALUE)
  end

  # Extracts and validates authentication state from session and cookies.
  # This is the ONLY place session authentication data is extracted.
  # The instance variables are set in the controller instance; Rails copies
  # such variables to the corresponding view instance if one is created.
  #
  # Instance variables set:
  # - @session_user_id: User ID if logged in, nil otherwise
  # - @session_timestamp: Last activity time if logged in, nil otherwise
  # - @session_user_token: GitHub OAuth token if GitHub user, nil otherwise
  # - @session_github_name: GitHub username if GitHub user, nil otherwise
  #
  # This typically does *not* check the database, so after this returns it's
  # possible that this user account was deleted after the session data was set.
  # However, this is enough information to allow the logged-in displays
  # supported by `logged_in?`, for example, the navigation header bar
  # shown in HTML or the list of users in /users.
  #
  # Some checks (e.g., `can_edit?` or `can_control?`) are pickier and want
  # to ensure that the user is *currently* valid, or want current information
  # about the user (e.g., whether or not the user is an admin).
  # These checks end up calling method `current_user`,
  # which uses as *input* the instance values that were set here,
  # retrieves this user's data from the database, and
  # memoizes *that* information in `@current_user`.
  # This way, we never query the database unless (1) a user's session claims
  # that the user is logged in, and (2) there's a need for additional info
  # or verification.
  #
  # Normally this doesn't set @current_user (that requires a database lookup).
  # However, if we use a remember_me token, we have to do a
  # database lookup, so in that case we record @current_user since
  # we *did* have to do a database lookup (so we will avoid doing it twice).
  #
  # @return [void]
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def setup_authentication_state
    return if Rails.application.config.deny_login

    # Extract session data - decrypt cookie once
    user_id = session[:user_id]
    timestamp = session[:time_last_used]

    # Check timeout BEFORE setting instance variables
    # This ensures instance variables always contain VALID auth state
    # Reject sessions with missing or expired timestamps
    if user_id && (!timestamp || timestamp < SessionsHelper::SESSION_TTL.ago.utc)
      reset_session # Session expired or missing timestamp
      user_id = nil
      timestamp = nil
    end

    # Handle remember token if no valid session
    if user_id.nil?
      user_id, timestamp = try_remember_token_login
    end

    # Set instance variables from the encrypted session cookie.
    @session_user_id = user_id
    @session_timestamp = timestamp
    @session_user_token = session[:user_token]
    @session_github_name = session[:github_name]
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  # Updates session timestamp if user is logged in and timestamp is old.
  # This is called as after_action, so it runs after the controller action.
  # Only updates if timestamp is older than RESET_SESSION_TIMER (1 hour).
  #
  # @return [void]
  def update_session_timestamp
    return unless @session_user_id

    old = !@session_timestamp ||
          @session_timestamp < SessionsHelper::RESET_SESSION_TIMER.ago.utc

    return unless old

    session[:time_last_used] = Time.now.utc
    @session_timestamp = session[:time_last_used] # Update cache
  end

  # Actively expire the session cookie once it is carrying nothing useful,
  # so a browser that previously received one (e.g. just logged out, or was
  # shown a stored flash) falls back onto the CDN-cached anonymous pages on
  # its NEXT request, instead of bypassing the cache until the browser
  # closes.
  #
  # This complements omit_session_cookie: that only *skips writing* a cookie
  # and cannot remove one the browser already holds; this sends an explicit
  # deletion. Runs as an after_action. See docs/cdn-cache-not-logged-in.md.
  #
  # Deliberately resilient to Rails/middleware internals: the session is
  # never literally empty (Rack always keeps a session_id, and the flash is
  # committed by middleware *after* this runs, so a spent 'flash' key may
  # still linger). We therefore use flash.empty? as the authoritative "is
  # there a flash to carry" signal and a read-only check for "is there any
  # real user content left", then suppress the session middleware's own
  # write. Correctness is pinned by
  # test/integration/drop_session_cookie_test.rb, which asserts the final
  # cookie state rather than any internal behavior.
  # @return [void]
  def drop_unneeded_session_cookie
    # Only act when the browser actually sent the cookie. This is
    # load-bearing: an anonymous request WITHOUT it is the cacheable case,
    # and we must never add a Set-Cookie there (it would be cached and
    # shipped to every visitor). Requests that DO carry it are already
    # passed to origin by the CDN (never cached), so a deletion header on
    # them is safe. Also the cheap early-out that keeps the hot cacheable
    # path free.
    return unless request.cookies.key?(SESSION_COOKIE_NAME)
    return if logged_in?            # never touch a logged-in user's session
    return unless flash.empty?      # a pending flash still needs the cookie

    # Keep the cookie if the session still holds real per-user content (a CSRF
    # token a rendered form needs, locale, forwarding_url, ...).
    return if session_has_user_content?

    # Suppress the session middleware's own Set-Cookie so it cannot emit a
    # competing cookie alongside our deletion.
    omit_session_cookie
    cookies.delete(SESSION_COOKIE_NAME, path: '/')
  end

  # True when the session holds real per-user data -- anything beyond the
  # framework bookkeeping keys (Rack's always-present session_id and a spent
  # flash). any? short-circuits on the first real key and allocates no
  # intermediate arrays. Read-only on purpose: mutating the session here would
  # itself generate a session_id and defeat the check. Unknown future keys
  # count as content, so callers fail safe (keep the cookie).
  # @return [Boolean]
  def session_has_user_content?
    session.keys.any? { |key| !SESSION_BOOKKEEPING_KEYS.include?(key.to_s) }
  end

  # Attempts to login using remember token cookies.
  # ONLY works for local users - GitHub users must re-authenticate via OAuth.
  # Returns [user_id, timestamp] if successful, [nil, nil] otherwise.
  #
  # @return [Array<Integer, Time>, Array<nil, nil>]
  # rubocop:disable Metrics/AbcSize
  def try_remember_token_login
    cookie_user_id = cookies.signed[:user_id]
    return [nil, nil] unless cookie_user_id

    user = User.find_by(id: cookie_user_id)
    return [nil, nil] unless user&.authenticated?(:remember, cookies[:remember_token])

    # GitHub users should not use remember tokens - they must use OAuth
    return [nil, nil] if user.provider == 'github'

    # Valid remember token for local user - create new session
    now = Time.now.utc
    session[:user_id] = user.id
    session[:time_last_used] = now

    I18n.locale = user.preferred_locale.to_sym
    # We found the user DB data, record it in case we need it later.
    @current_user = user

    [user.id, now]
  end
  # rubocop:enable Metrics/AbcSize

  include SessionsHelper
end
# rubocop: enable Metrics/ClassLength
