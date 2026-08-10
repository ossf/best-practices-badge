# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# rubocop:disable Metrics/BlockLength
Rails.application.configure do
  # Settings specified here will take precedence over those in
  # config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true
  # Cache store config (identical in development.rb and test.rb).
  # Ideally this would live in config/application.rb to avoid
  # repetition, but that file loads during `rails test` CLI boot
  # *before* SimpleCov starts, making no_dup_coder.rb invisible to
  # coverage tracking and breaking the 100% coverage requirement.
  # Keeping it in the environment files ensures the require happens
  # after SimpleCov starts (during Rails.application.initialize!).
  #
  # Moving to an initializer doesn't help either: initializers run
  # too late -- the cache store is already built from config set
  # during environment file loading, so an initializer's assignment
  # to config.cache_store is silently ignored (tests pass but the
  # cache doesn't actually use NoDupCoder).
  #
  # Using `load` instead of `require` in the test file to force
  # re-evaluation triggers "already initialized constant" warnings
  # and still leaves structural lines (module/def) uncovered.
  #
  # SimpleCov's track_files directive also doesn't help: it controls
  # which files appear in reports but can't retroactively record
  # coverage for lines executed before SimpleCov started.
  require_relative '../../lib/no_dup_coder'
  config.cache_store =
    :memory_store,
    {
      size: (ENV['RAILS_CACHE_SIZE'] || '128').to_i.megabytes,
      coder: NoDupCoder
    }

  # Enable Rack::Cache to put a simple HTTP cache in front of your application
  # Add `rack-cache` to your Gemfile before enabling this.
  # For large-scale production use, consider using a caching reverse proxy like
  # NGINX, varnish or squid.
  # config.action_dispatch.rack_cache = true

  # Serve static files from the `/public` folder.
  # The rails_serve_static_assets gem previously forced this to true;
  # we now set it directly. Our deployment requires Rails to serve
  # static files (no separate Apache/NGINX for static assets).
  config.public_file_server.enabled = true

  # Compress JavaScripts and CSS.
  config.assets.js_compressor = :terser
  config.assets.css_compressor = :sass

  # Do not allow "live compilation" using the assets pipeline
  # if a precompiled asset is unavailable.  Instead, assets must be precompiled
  # for the production environment.
  # The Rails guide for the asset pipeline at
  # https://guides.rubyonrails.org/asset_pipeline.html
  # says that live compilation "uses more memory, performs more poorly
  # than the default and is not recommended".
  # Disabling live compilation is also recommended by Heroku's documentation
  # at: https://devcenter.heroku.com/articles/rails-asset-pipeline#
  # compile-set-to-true-in-production
  # which says: "If you have enabled your application to config.assets.compile =
  # true in production, your application might be very slow...
  # This setting is also known to cause other run-time instabilities and is
  # generally not recommended. Instead we recommend either precompiling all
  # of your assets on deploy (which is the default)..."
  config.assets.compile = false

  # Asset digests allow you to set far-future HTTP expiration dates on all
  # assets, yet still be able to expire them through the digest params.
  config.assets.digest = true

  # `config.assets.precompile` and `config.assets.version` have moved to
  # config/initializers/assets.rb

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = 'X-Sendfile' # for Apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for NGINX

  # Force all access to the app over SSL, use Strict-Transport-Security, and use
  # secure cookies.
  config.force_ssl = true unless ENV['DISABLE_FORCE_SSL']

  # Use the :info log level by default, not the lowest (:debug);
  # the site is now busy enough that ":debug" floods the logs.
  # You can override this using RAILS_LOG_LEVEL
  config.log_level = (ENV['RAILS_LOG_LEVEL'] || :info).to_sym

  # Prepend all log lines with the following tags.
  # config.log_tags = [ :subdomain, :uuid ]

  # Log to stdout (12-factor app style). The rails_stdout_logging gem
  # previously did this; we now configure it directly.
  # NOTE: Rails 5.0+ defaults enable stdout logging when the RAILS_LOG_TO_STDOUT
  # env var is set. This explicit setup ensures stdout logging regardless of that
  # variable and adds TaggedLogging, so we keep it rather than relying on defaults.
  $stdout.sync = true
  config.logger = ActiveSupport::TaggedLogging.new(
    ActiveSupport::Logger.new($stdout)
  )

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store

  # Figure out public hostname
  host = ENV['PUBLIC_HOSTNAME'] || 'public-hostname-not-configured'

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.action_controller.asset_host = 'http://assets.example.com'
  # Set asset_host to help counter host header injection; see
  # https://github.com/ankane/secure_rails
  config.action_controller.asset_host = host

  # Configure email server we use for sending email to others. This server will,
  # by definition, be a Mail Transfer Agent (MTA).
  # For discussion about how to do this, see:
  # https://guides.rubyonrails.org/action_mailer_basics.html
  # https://www.railstutorial.org/book/account_activation_password_reset
  # We used to use SendGrid; see its documentation for more about that.
  # For more about configuring Amazon SES SMTP interface, see:
  # https://docs.aws.amazon.com/ses/latest/dg/send-email-smtp.html
  #
  # TODO: Eventually we should set raise_delivery_errors = true and handle exceptions,
  # so that we can do retries, and put email sending in a separate thread.
  # However, in the current code, if we raise delivery errors we cause paths to fail
  # such as updating a project when the email system isn't working. We'd rather let the
  # projects update, even when the email system isn't working properly.
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.default_url_options = { host: host }
  ActionMailer::Base.smtp_settings = {
    # NOTE: 'address' is NOT the email address of the *sender* but the domain of
    # the remote mail server (the MTA) that will be *receiving* the email and then send it on.
    address: ENV.fetch('BADGEAPP_SEND_EMAIL_ADDRESS', 'smtp.sendgrid.net'),
    # Avoid using port 25, use a TLS port instead.
    port: ENV.fetch('BADGEAPP_SEND_EMAIL_PORT', '465'),
    # "plain" authtication would send the password in the clear if sent on port 25.
    # However, we're assuming that we're using TLS to send email to the MTA.
    authentication: :plain,
    # This is the authentication data we'll send to the MTA to be authorized to send email
    user_name: ENV.fetch('BADGEAPP_SEND_EMAIL_USERNAME', nil),
    password: ENV.fetch('BADGEAPP_SEND_EMAIL_PASSWORD', nil),
    # This is used for the HELO announcement to the MTA:
    domain: ENV.fetch('BADGEAPP_SEND_EMAIL_DOMAIN', 'heroku.com'),
    # The following controls how we use TLS for hop-to-hop (point-to-point) encryption of
    # our emails to the MTA.
    # *Force* the direct use of TLS when sending email to the MTA. It's simple, which is an
    # advantage for security. This typically uses port 465 (not 587).
    # Amazon calls this "TLS Wrapper" in:
    # https://docs.aws.amazon.com/ses/latest/dg/smtp-connect.html
    tls: true
    #
    # This would use TLS opportunistically, via STARTTLS.
    # However, it would send email and passwords in the clear
    # if it can't. It's enough to counter most passive threats, but an active threat agent
    # could cause TLS to fail & force us to send things in the clear. So we won't use it.
    # This would typically use port 587.
    # enable_starttls_auto: true
    #
    # This would use STARTTLS but force the use of TLS. This works, but there are concerns
    # that starting the protocol *not* in TLS mode and *then* switching to TLS creates a
    # window of opportunity for problems as well as unnecessary complexity.
    # So while this is a reasonable alternative, for now we won't use it.
    # This would typically use port 587.
    # enable_starttls: true
  }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  # This is now handled by "initializers/i18n.rb"; see that file.
  # config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners.
  config.active_support.deprecation = :notify

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = Logger::Formatter.new

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Use Fastly as a CDN. See: https://devcenter.heroku.com/articles/fastly
  # config.action_controller.asset_host = ENV['FASTLY_CDN_URL']
  # Use CDN directly for static assets
  # The documentation for Fastly suggests setting
  # "config.serve_static_assets = true".  However, this has since been
  # renamed to "config.serve_static_files", which we already conditionally set.

  # Cache static content.  Cache for a long time; the asset cache is
  config.public_file_server.headers =
    {
      'Cache-Control' =>
        'public, s-maxage=31536000, max-age=31536000, immutable'
    }

  # Enable Rack's built-in compression mechanism; this is important for people
  # with slow network connections
  config.middleware.use Rack::Deflater

  # First thing, filter out bad HTTP headers (0 == first)
  # By default this accepts the HTTP headers set by Heroku (and thus trusted),
  # but otherwise removes some "dangerous" headers.  In particular, it
  # removes the X-Forwarded-Host HTTP header, which in Rails is
  # inexplicably trusted and is used in url_for, even though it comes
  # from an untrusted user. See:
  # https://github.com/rails/rails/issues/29893
  # https://github.com/ankane/secure_rails
  # http://carlos.bueno.org/2008/06/host-header-injection.html
  # We generally want to implement whitelists, not blacklists, but
  # this is an easy way to make sure that certain dangerous headers
  # cannot be unintentionally used in the first place.
  config.middleware.insert_before(0, Rack::HeadersFilter)

  # In production and fake_production environments turn on "lograge".
  # This makes the logs easier to read and removes cruft that, while useful
  # in development, can be overwhelming in production.
  config.lograge.enabled = true

  # Report user_id in logs
  # https://github.com/roidrage/lograge/issues/23
  config.lograge.custom_options =
    lambda do |event|
      uid = event.payload[:uid]
      if uid
        { uid: uid }
      else
        {}
      end
    end

  # The timeout used by Rack::Timeout is not set here (any more);
  # it is set via the environment variable RACK_TIMEOUT_SERVICE_TIMEOUT.
  # For more on controlling timeout-related times, see:
  # https://github.com/sharpstone/rack-timeout
  #
  # As a failsafe, we trigger an exception if the response just hangs for
  # too long.  We only do this in production, because it's not
  # supposed to happen in normal use - this is simply an automatic
  # recovery mechanism if things get stuck.  We don't do this in test or
  # development, because it interferes with their purposes.
  # This call will fail in fake_production, so we ignore the exception.
  # rubocop:disable Lint/SuppressedException
  begin
    # Unfortunately Rack::Timeout doesn't provide a lot of control over logging.
    # What it provides (now) is described here:
    # https://github.com/sharpstone/rack-timeout/blob/master/doc/logging.md
    # The timeout reports are really noisy, and don't seem to help debug
    # typical problems (if anything they get in the way).  Disable them.
    Rack::Timeout::Logger.disable
  rescue NameError
    # Do nothing if it's unavailable (this happens if we didn't load the gem)
  end
  # rubocop:enable Lint/SuppressedException

  # Configure active_job to use solid_queue as its back end when in production.
  config.active_job.queue_adapter = :solid_queue
  # We intentionally use *one* database for both the jobs and everythihg else.
  # This greatly simplifies backup, maintenance, etc. If you wanted the
  # jobs to go into their own database, you'd need to do something like:
  # config.solid_queue.connects_to = { database: { writing: :queue } }
end
# rubocop:enable Metrics/BlockLength
