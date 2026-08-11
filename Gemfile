# frozen_string_literal: true

# This lists all gems we directly depend on.
# We depend on explicit version numbers (so we can control upgrade times).
# Any one gem is listed no more than once (to prevent referring to
# different version numbers in different environments).

# KEEP IN SYNC WITH .github/dependabot.yml, which proposes our gem updates
# on a schedule. Two kinds of decision recorded here are mirrored there,
# and changing one without the other silently loses its effect:
#
# * A gem pinned to an exact version below, or capped with "<", is one
#   whose upgrades we time by hand rather than take routinely. Those gems
#   are named in that file's "gems-minor" exclude-patterns, so a minor
#   bump arrives as its own pull request rather than inside the weekly
#   batch of low-risk updates.
#
# * A cap that records a KNOWN DEFECT rather than a version we simply have
#   not reached yet is ALSO listed there under "ignore". The two say
#   different things: a cap here means "do not resolve to that version",
#   while the ignore means "do not propose it at all". That distinction
#   matters because Dependabot is configured to raise our ceilings when a
#   newer version needs the room, so a cap alone is not a durable block.
#
# So when you add, remove, or loosen a pin or a cap below, open that file.

# The Rails release train moves as one. Its gems pin each other with "=",
# not "~>", so railties 8.1.3.1 requires exactly activesupport 8.1.3.1 and
# actionpack 8.1.3.1; updating one alone cannot resolve. Update all of their
# versions below together, then run this:
# bundle update actionmailer actionpack actionview activejob activemodel \
#        activerecord activesupport railties rails
#
# rails-i18n is NOT part of that set, though it used to be listed here. It
# requires "railties >= 8.0.0, < 9", so any Rails 8.x satisfies it and it
# can move on its own schedule. The exception is a MAJOR upgrade: going to
# Rails 9 needs the rails-i18n constraint below widened in the same commit,
# because rails-i18n 8.x refuses railties 9. Nothing proposes that pair
# automatically, so it is a hand edit when the time comes.

# NOTE: When updating you may see a spurious message like this:
#   WARN: Unresolved or ambiguous specs during Gem::Specification.reset:
#       stringio (>= 0)
#       Available/installed versions of this gem:
#       - 3.1.7
#       - 3.1.1
#   WARN: Clearing out unresolved specs. Try 'gem cleanup <gem>'
# It's basically spurious. Run `gem cleanup stringio` and move on.

# Important: we use `require: false` for many gems, including
# various linters, as is typical. Every one of them is run as a separate
# process ("bundle exec rubocop", "bundle exec license_finder", ...),
# so *always* loading the library into the application buys nothing and
# would cost about 1.3 seconds on EVERY rake task start. Measured:
# rubocop 0.86s, rubocop-rails 0.30s, license_finder 0.09s,
# rails_best_practices 0.04s. RuboCop's extensions are loaded by
# .rubocop.yml's "plugins:" inside that separate process.

source 'https://rubygems.org'

# Use current ruby version (as stated in .ruby-version file)
# https://stackoverflow.com/questions/32934651/is-it-a-bad-practice-to-list-ruby-version-in-both-gemfile-and-ruby-version-dotf
ruby File.read('.ruby-version').strip

# The action* gems are Rails portions. When you upgrade their versions, be
# sure to upgrade them in sync, *including* railties.
# Loading only what we use reduces memory use & attack surface.
# gem 'actioncable' # Not used. Client/server comm channel.
# gem 'activestorage' # Not used. Attaches cloud files to ActiveRecord.
gem 'actionmailer', '~> 8.1.1' # Rails. Send email.
gem 'actionpack', '~> 8.1.1' # Rails. MVC framework.
gem 'actionview', '~> 8.1.1' # Rails. View.
gem 'activejob', '~> 8.1.1' # Rails. Async jobs.
gem 'activemodel', '~> 8.1.1' # Rails. Model basics.
gem 'activerecord', '~> 8.1.1' # Rails. ORM and query system.
# gem 'activestorage' # Not used. Attaches cloud files to ActiveRecord.
gem 'activesupport', '~> 8.1.1' # Rails. Underlying library.
# gem 'activetext' # Not used. Text editor that fails to support markdown.
gem 'attr_encrypted', '~> 4' # Simplify encrypting model attributes
gem 'bcrypt', '~> 3.1.18' # Security - for salted hashed interacted passwords
gem 'blind_index', '~> 2.8.1' # Index encrypted data (email addresses)
gem 'bootstrap-sass', '~> 3.4' # Use bootstrap v3
gem 'bootstrap-social-rails', '~> 4.12' # Pretty social media buttons
gem 'bootstrap_form', '~> 2.7' # DO NOT update unless updating bootstrap
gem 'bundler' # Ensure it's available
# Note: if webpacker is used, see chartkick website for added instructions
gem 'chartkick', '~> 5.2' # Chart project_stats
gem 'commonmarker', '~> 2.9.0' # Process markdown in textareas
gem 'faraday-retry', '~> 2.1' # Force retry of faraday requests for reliability
# We no longer use "fastly-rails"; it doesn't support Rails 6+.
# They recommend switching to the "fastly" gem (aka "fastly-ruby"),
# but fastly-ruby is not designed to support multi-threading, so we
# call the Fastly API directly instead.
gem 'font_awesome5_rails' # Font Awesome 5 web fonts, CSS, JavaScript for Rails
gem 'http_accept_language', '~> 2.1' # Determine user's preferred locale
gem 'httparty' # HTTP convenience. rake fix_use_gravatar
gem 'imagesLoaded_rails', '~> 4.1' # JavaScript - enable wait for image load
gem 'jbuilder', '~> 2.11' # Template mechanism for JSON format results
gem 'jquery-rails', '~> 4.4' # JavaScript jQuery library (for Rails)
# We once used 'jquery-ui-rails', JavaScript jQueryUI library (for Rails),
# for jquery-ui/autocomplete (a polyfill for missing functionality in Safari).
gem 'lograge', '~> 0.12' # Simplify logs
gem 'mail', '~> 2.7' # Ruby mail handler
#
# Specially pin multi_json because of an incompatibility with sawyer.
# multi_json 1.21.0 renamed MultiJson into MultiJSON. The old MultiJson stub
# uses method_missing but Sawyer calls MultiJson.method(:load), which
# bypasses method_missing and resolves to Kernel#load.
# As a result, sawyer calls Kernel#load (the file-loader)
# instead of MultiJSON.load (the JSON parser).
# Every GitHub API response body then gets passed to Kernel.load as a Ruby file
# path, causing LoadError due to corrupted JSON deserialization.
# Fix: Limit update until sawyer or multi_json releases a compatible fix.
# Also listed under "ignore" in .github/dependabot.yml, so it is not even
# proposed; lift both together once sawyer or multi_json fixes this.
gem 'multi_json', '< 1.21.0'
gem 'octokit', '~> 7' # GitHub's official Ruby API
gem 'omniauth-github', '~> 2.0' # Authentication to GitHub (get project info)
#
# Gem omniauth-rails_csrf_protection protects omniauth logins and
# provides a proper integration of omniauth with Rails.
# This requires explanation.
# Gem omniauth 1.x series has vulnerability CVE-2015-9284 if GET requests
# are used.
# OmniAuth gem 2.x requires POST requests by default, which is a
# security improvement.
# However, omniAuth 2.x uses Rack's built-in AuthenticityToken class,
# NOT Rails' CSRF system. When using Rails, we need to instead use Rails'
# ActionController::RequestForgeryProtection for CSRF protection.
# For a discussion on this countermeasure see:
# <https://github.com/omniauth/omniauth/wiki/Resolving-CVE-2015-9284>.
# At one time I did this:
# gem 'omniauth-rails_csrf_protection',
#    git: 'https://github.com/cookpad/omniauth-rails_csrf_protection.git',
#    ref: 'b33ff2e57f7c0530da76da6b4b358218f1e7f230'
# to provide a stronger guarantee that what I reviewed is what will
# be loaded, by specifying a specific hash reference.
# However, using a git reference busts CI pipeline caching, slowing down
# all testing, and over time we've become more comfortable that this is
# the "standard way to resolve this issue".
gem 'omniauth-rails_csrf_protection', '~> 2.0' # integrate omniauth with rails
gem 'pagy', '~> 43.5' # Paginator for web pages
gem 'paleta', '~> 0.3' # Color manipulation, used for badges
gem 'paper_trail', '~> 17.0' # Record previous versions of project data
gem 'pg', '~> 1.4' # PostgreSQL database, used for data storage
gem 'pg_search', '~> 2.3' # PostgreSQL full-text search
gem 'puma', '~> 7.0' # Faster webserver; recommended by Heroku
gem 'rack', '~> 3.2.3' # interface between web server + web framework (Rails)
gem 'rack-attack', '~> 6.8' # Implement rate limiting
gem 'rack-cors', '~> 3.0' # Enable CORS so JavaScript clients can get JSON
gem 'rack-headers_filter', '~> 0.0.1' # Filter out "dangerous" headers
# We no longer say: gem 'rails', '6.1.7.3' # Our web framework
# but instead load only what we use (to reduce memory use and attack surface).
# We load sprockets-rails, but its version number isn't kept in sync.
# Note: Update the gem versions of action* and railties in sync.
gem 'railties', '~> 8.1.1' # Rails. Rails core, loads rest of Rails
gem 'rails-i18n', '~> 8.1.0' # Localizations for Rails built-ins
# Redcarpet had reliability issues, but commonmarker has memory issues
# We've created a local fork, while providing pull requests upstream,
# to fix problems.
# gem 'redcarpet', '~> 3.5' # Process markdown in form textareas (justifications)
# If building gets stuck partway, unstick with: bundle update redcarpet
gem 'redcarpet', git: 'https://github.com/david-a-wheeler/redcarpet', branch: 'local_main'
gem 'sassc-rails' # compiles .scss (css replacement), replaces sass-rails
gem 'scout_apm' # Monitor for memory leaks
gem 'secure_headers', '~> 7' # Add hardening measures to HTTP headers
gem 'solid_queue', '~> 1.1' # ActiveJob database backend
# WARNING!!!!
# CHECK DEPLOYMENT FIRST IF YOU UPDATE sprockets-rails.
# The gem sprockets-rails version 3.4.1 (from 3.2.2) caused a regression
# in deployment (icons no longer displayed) that does NOT occur locally.
# WARNING!!!!
gem 'sprockets-rails', '3.5.2' # Rails. Asset precompilation
gem 'terser', '~> 1.1', require: false # Minify JavaScript
gem 'sentry-ruby' # Support Sentry real-time crash reporting
gem 'sentry-rails' # Support Sentry real-time crash reporting
gem 'ssrf_filter' # Ensure external URLs don't resolve to invalid IP addrs

group :development, :test do
  gem 'awesome_print' # Pretty print Ruby objects
  gem 'bullet' # Avoid n+1 queries
  gem 'bundler-audit' # Alert if Gemfile.lock gems have known vulnerabilities
  gem 'dotenv', '~> 3.0' # Load env vars from .env files into Rails ENV
  gem 'eslintrb' # Linter for JavaScript code.
  gem 'json', '~> 2.16' # Process JSON format
  gem 'license_finder', '~> 7.0', require: false # Acceptable sw licenses
  gem 'mdl', '0.13.0' # Markdownlint - linter for markdown format
  # Removed pronto gems - comprehensive linting now handled by rake default
  gem 'rails_best_practices', '~> 1.23', require: false # Code quality
  # gem 'railroader', '4.3.8' # Security static analyzer. OSS fork of Brakeman
  gem 'rubocop', '1.88.2', require: false # Style checker
  gem 'rubocop-performance', '~> 1.20', require: false # Performance cops
  gem 'rubocop-rails', '2.33.4', require: false # Rails-specific cops
  gem 'ruby-graphviz', '1.2.5' # This is used for bundle viz
  # Spring, a preloader that keeps the application resident so repeated
  # commands start instantly. Commented out 2026-08-05 rather than
  # deleted, because reinstating it is this one line plus two in the
  # binstubs. Three reasons, in order of weight:
  #
  # * It is EASILY AND QUIETLY DISABLED, and was. Spring only intercepts
  #   commands through bin/ binstubs, and commit fa8b3645 regenerated
  #   those in August 2025, dropping the "load .../spring" line from
  #   bin/rails and bin/rake as a side effect. Nobody noticed for months,
  #   because nothing fails when a preloader silently stops preloading:
  #   things are merely slower. A dependency whose absence is invisible
  #   is a poor dependency to carry.
  # * It needs SPECIAL COMMANDS to do anything. It hooks binstubs, so it
  #   helps "bin/rake" and "bin/rails", while AGENTS.md tells developers
  #   to type plain "rake" and "rails", which go through the rbenv shims
  #   to the gem executables and never reach bin/. As used here it would
  #   have to change how everyone types every command.
  # * It HELPS LESS THAN IT DID. When boots were 8 to 11 seconds it was
  #   worth real inconvenience. Turning Bootsnap on for development and
  #   keeping the linters out of the application brought "rails console"
  #   to 4.6s, "rake -T" to 2.3s, and rake tasks that need no Rails to
  #   0.6s. What is left for a preloader to win is much smaller, and the
  #   price is a resident daemon holding a cached copy of the app that
  #   must be restarted when configuration changes.
  #
  # Rails itself agrees: Spring is no longer in the Gemfile that
  # "rails new" generates, as of Rails 7.
  #
  # bin/spring and config/spring.rb are deliberately left in place.
  # gem 'spring', '~> 4.1' # Preloader to speed development+test
  # Do NOT upgrade to vcr 6.*, as that is not OSS:
  gem 'vcr', '< 5.1' # Record network responses for later test reuse
  gem 'yaml-lint', '~> 0.1.2' # Check YAML file syntax
end

# The "fake_production" environment is very much like production, however,
# we enable a few debug tools to help us find "production-only" bugs.
group :fake_production, :development, :test do
  gem 'pry-byebug' # debug tool
end

group :development do
  # Also listed under "ignore" in .github/dependabot.yml, so it is not even
  # proposed; lift both together when 1.24.x stops breaking VCR tests.
  gem 'bootsnap', '< 1.24.0' # Speed up boot via caches; 1.24.x breaks VCR tests
  gem 'memory_profiler', '~> 1.1.0' # Memory profiling to debug memory leaks
  # gem 'fasterer', '0.3.2' # Provide speed recommendations - run 'fasterer'
  # Waiting for Ruby 2.4 support:
  # https://github.com/seattlerb/ruby_parser/issues/239
  # gem 'traceroute', '0.8.1' # Adds 'rake traceroute' command to check routes
  # We bring in full rails in development in case we need it for debugging;
  # this also keeps some gems happy that don't realize that loading
  # only *parts* of Rails is fine:
  gem 'rails', '~> 8.1.1' # Rails (our web framework)
  # To update the translation gem, see the process docs in doc/testing.md
  gem 'translation', '1.41' # translation.io - translation service
  gem 'web-console' # In-browser debugger; use <% console %> or console
end

group :test do
  gem 'capybara-slow_finder_errors', require: false # ID slow Capybara finders
  # Pin minitest < 6.0 until minitest-reporters supports it.
  # Minitest 6.0 introduced breaking changes that cause minitest-reporters 1.7.1
  # to fail silently (tests don't run). Remove this constraint when
  # minitest-reporters releases a version compatible with minitest >= 6.0.
  # See: https://github.com/minitest-reporters/minitest-reporters/issues/336
  gem 'minitest', '< 6.0'
  gem 'minitest-reporters', '< 1.9.0', require: false # Improve minitest output format
  gem 'minitest-retry', require: false # Retry- avoid Capybara false failures
  gem 'ostruct' # OpenStruct; future-proof for Ruby 3.5+
  # Note: Updating 'rails-controller-testing' to '1.0.5' causes failures
  gem 'rails-controller-testing', '~> 1.0' # for `assigns` and `assert_template`
  gem 'selenium-webdriver' # Automates browser i/f for Rails system testing
  # Test coverage. We require both directly: simplecov in test_helper.rb, and
  # simplecov_json_formatter in test:coverage_gaps to write coverage/coverage.json
  # for the Codecov upload. List both so a future simplecov release that stops
  # bundling the JSON formatter can't break us in a surprising way.
  gem 'simplecov', require: false
  gem 'simplecov_json_formatter', require: false
  gem 'webmock', '~> 3.0', require: false # Mock HTTP requests for testing
end

group :production do
  gem 'rack-timeout', '~> 0.7.0' # Timeout; https://github.com/heroku/rack-timeout
end

# Post-install message from autoprefixer-rails:
# autoprefixer-rails was deprecated. Migration guide:
# https://github.com/ai/autoprefixer-rails/wiki/Deprecated
