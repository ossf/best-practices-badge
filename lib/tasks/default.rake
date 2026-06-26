# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# CII Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Rake tasks for BadgeApp

# If you use our standard development environment you usually
# don't need to prefix commands with "bundle exec" or "bin/" to ensure
# you're running in the correct Ruby virtual environment. That's because
# the rbenv system that we install makes those prefixes optional,
# eliminating the risk of forgetting them during development.
# However, rake tasks that *might* be run in the CI, staging, or production
# generally *must* include "bundle exec", because we don't run rbenv
# there. We use rbenv only as a development-time convenience, and try to
# minimize what we install in production, and we try to make our
# CI system similar to production.

require 'English'
require 'json'

# NOTE: Our default runs test:optimized, not just test.
# We want to make sure things work using *all* our tests.
# test:optimized runs regular tests (parallelized) then system tests (serial).
# We do the whitespace check early, so it will fail early.
# AI assistants just can't help but add whitespace at the end of lines.
task(:default).clear.enhance %w[
  rbenv_rvm_setup
  notice
  whitespace_check
  ruby_syntax
  bundle
  bundle_audit
  generate_criteria_doc
  rubocop
  markdownlint
  rails_best_practices
  license_okay
  license_finder_report.html
  yaml_syntax_check
  html_from_markdown
  eslint
  report_code_statistics
  percent_gems_up_to_date
  test:optimized
]
# Temporarily removed fasterer
# Waiting for Ruby 2.4 support: https://github.com/seattlerb/ruby_parser/issues/239
# Temporarily removed railroader because of local install problems;
# it's still run by the CI for every pull request

# Run Continuous Integration (CI) check processes.
# This is a shorter list; many checks are run by a separate "pronto" task.
# Temporarily includes "railroader", we hope to move that to pronto.
# Removed bundle_doctor due to CircleCI failures
# Temporarily removed fasterer
task(:ci).clear.enhance %w[
  rbenv_rvm_setup
  ruby_syntax
  bundle_audit
  markdownlint
  license_okay
  license_finder_report.html
  whitespace_check
  yaml_syntax_check
  report_code_statistics
  railroader
]

# Simple smoke test to avoid development environment misconfiguration
desc 'Ensure that rbenv or rvm are set up in PATH'
task :rbenv_rvm_setup do
  # Skip this check in CI environments where Ruby is managed differently
  next if ENV['CI']

  path = ENV.fetch('PATH', nil)
  if !path.include?('.rbenv') && !path.include?('.rvm') && !path.include?('.asdf')
    raise StandardError, 'Must have rbenv or rvm in PATH'
  end
end

# Do a quick check of Ruby syntax, takes only ~2 sec in most cases
desc 'Check for ruby syntax problems on **.rb files modified last 7 days'
task :ruby_syntax do
  # Exclude temporary files beginning with comma and files under temp/.
  # The `ruby -c` command only checks one file, so re-invoke for each file.
  # Do checks in parallel to speed results.
  puts 'Checking ruby syntax in files modified in the last 7 days...'
  sh 'find . -name "*.rb" ! -name ",*" ! -path "./temp/*" -mtime -7 -print0 | ' \
     'xargs -0 -L 1 -P $(nproc) ruby -c > /dev/null'
end

desc 'Run Rubocop'
task :rubocop do
  # The default configuration is in .rubocop.yml
  sh 'bundle exec rubocop'
end

desc 'Run rails_best_practices with options'
task :rails_best_practices do
  # The config file (config/rails_best_practices.yml) controls which checks
  # are enabled/disabled. File-exclusion and mode flags must be passed on
  # the command line — the YAML 'exclude:' key is silently ignored by the gem.
  # tmp/ is excluded by the gem's built-in defaults; the others are not.
  sh 'bundle exec rails_best_practices ' \
     '--features --spec --without-color ' \
     '--exclude "temp/,railroader/,/,"'
end

desc 'Setup railroader if needed'
task 'railroader/bin/railroader' do
  # "gem install" doesn't honor Gemfile.lock, so use git clone + bundle install
  sh 'mkdir -p railroader'
  sh 'cd railroader; ' \
     'git clone --depth 1 ' \
     'https://github.com/david-a-wheeler/railroader.git ./ ; ' \
     'cp ../.ruby-version .; bundle install'
end

desc 'Run railroader'
task railroader: %w[railroader/bin/railroader] do
  # TEMPORARY: DISABLE
  # Disable pager, so that "rake" can keep running without halting.
  # sh 'bundle exec railroader --quiet --no-pager'
  # Workaround to run correct version of railroader & its dependencies.
  # We have to set BUNDLE_GEMFILE so bundle works inside the rake task
  sh 'cd railroader; BUNDLE_GEMFILE=$(pwd)/Gemfile bundle exec bin/railroader --quiet --no-pager $(dirname $(pwd))'
end

desc 'Run bundle if needed'
task :bundle do
  sh 'bundle check || bundle install'
end

# NOTE: We've had some trouble with bundle doctor, so it might
# not be run by default.
desc 'Run bundle doctor - check for some Ruby gem configuration problems'
task :bundle_doctor do
  sh 'bundle doctor'
end

desc 'Report code statistics'
task :report_code_statistics do
  verbose(false) do
    sh 'script/report_code_statistics'
  end
end

# Helper function to check network availability
def network_available?
  require 'socket'
  Socket.tcp('github.com', 443, connect_timeout: 5) { true }
rescue StandardError
  false
end

# rubocop:disable Metrics/BlockLength
desc 'Run bundle-audit - check for known vulnerabilities in dependencies'
task :bundle_audit do
  # rubocop:disable Metrics/MethodLength
  def bundle_audit_update_successful?
    max_retries = 4
    current_try = 0

    while current_try < max_retries
      cmd_options = { out: File::NULL, err: File::NULL }
      if system('bundle exec bundle audit update', cmd_options)
        puts 'Successful bundle audit update.' if verbose
        return true
      end

      current_try += 1
      remaining = max_retries - current_try
      if verbose
        puts "Bundle audit update failed. Number of tries left=#{remaining}"
      end
      sleep 2 if current_try < max_retries
    end

    if verbose
      puts 'Bundle audit update failed after multiple attempts. Skipping.'
    end
    false
  end
  # rubocop:enable Metrics/MethodLength

  # If SKIP_BUNDLE_AUDIT set, skip `bundle audit` to allow other checks.
  next if ENV['SKIP_BUNDLE_AUDIT']

  apply_bundle_audit =
    if network_available?
      if verbose
        puts 'Have network access, trying to update ' \
             'bundle-audit database.'
      end
      bundle_audit_update_successful?
    else
      if verbose
        puts 'Cannot update bundle-audit database; ' \
             'using current data.'
      end
      true
    end

  if apply_bundle_audit
    # Sometimes there are vulnerability reports that aren't exploitable in
    # our system. When upgrading isn't easy, we'll identify those cases
    # (and rationale) in the file .bundler-audit.yml
    sh 'bundle exec bundle audit check'
  end
end
# rubocop:enable Metrics/BlockLength

# We don't normally print a list of out-of-date gems, that would create
# a lot of output that is normally useless. The developer can always run
# "bundle outdated" if that's important.
desc 'Report percentage of gems that are up-to-date if network available'
task :percent_gems_up_to_date do
  if network_available?
    begin
      bundle_list_output = `bundle list 2>/dev/null`
      if $CHILD_STATUS.success?
        total_gems =
          bundle_list_output.lines.count do |line|
            line.match?(/^\s+\*\s/)
          end
        outdated_output = `bundle outdated 2>/dev/null`
        outdated_count =
          $CHILD_STATUS.success? ? 0 : count_outdated_gems(outdated_output)
        up_to_date = total_gems - outdated_count
        percent =
          if total_gems.zero?
            100.0
          else
            (up_to_date.to_f / total_gems * 100).round(1)
          end

        puts "Gem stats: out-of-date=#{outdated_count}, " \
             "up-to-date=#{up_to_date}, total=#{total_gems}, " \
             "%up-to-date=#{percent}%"
      else
        puts 'Unable to determine total gem count'
      end
    rescue StandardError => e
      puts "Error checking gem status: #{e.message}"
    end
  else
    puts 'Network not available, skipping gem status check'
  end
end

# Helper function to count outdated gems from bundle outdated output
def count_outdated_gems(outdated_output)
  lines = outdated_output.lines
  gem_header_index = lines.find_index { |line| line.start_with?('Gem') }
  gem_header_index ? lines.length - gem_header_index - 1 : 0
end

# Use markdownlint to examine the usual markdown files.
# NOTE: If you don't want mdl to be run on a markdown file, rename it to
# end in ".markdown" instead.  (E.g., for markdown fragments.)
desc 'Run markdownlint (mdl) - check for markdown problems on **.md files'
task :markdownlint do
  # The default configuration is in .mdlrc + style config/markdown_style.rb
  # Exclude temporary files beginning with comma
  sh 'find . -name "*.md" ! -name ",*" ! -path "./tmp/*" ! -path "./temp/*" ! -path "*/.*" -print0 | xargs -0 bundle exec mdl'
end

# Apply JSCS to look for issues in JavaScript files.
# To use, must install jscs; the easy way is to use npm, and at
# the top directory of this project run "npm install jscs".
# This presumes that the jscs executable is installed in "node_modules/.bin/".
# See http://jscs.info/overview
#
# This not currently included in default "rake"; it *works* but is very
# noisy.  We need to determine which ruleset to apply,
# and we need to fix the JavaScript to match that.
# We don't scan 'app/assets/javascripts/application.js';
# it is primarily auto-generated code + special directives.
desc 'Run jscs - JavaScript style checker'
task :jscs do
  jscs_exe = 'node_modules/.bin/jscs'
  jscs_options = '--preset=node-style-guide -m 9999'
  jscs_files = 'app/assets/javascripts/project-form.js'
  sh "#{jscs_exe} #{jscs_options} #{jscs_files}"
end

desc 'Load current self.json'
task :load_self_json do
  require 'json'
  require 'open-uri'
  url = 'https://staging.bestpractices.dev/projects/1.json'
  contents = URI.parse(url).open.read
  pretty_contents = JSON.pretty_generate(JSON.parse(contents))
  File.write('docs/self.json', pretty_contents)
end

# We use a file here because we do NOT want to run this check if there's
# no need.  We use the file 'license_okay' as a marker to record that we
# HAVE run this program locally.
desc 'Examine licenses of reused components; see license_finder docs.'
file 'license_okay' => ['Gemfile.lock', 'docs/dependency_decisions.yml'] do
  sh 'bundle exec license_finder --decisions_file docs/dependency_decisions.yml && touch license_okay'
end

desc 'Create license report'
file 'license_finder_report.html' => [
  'Gemfile.lock',
  'docs/dependency_decisions.yml'
] do
  sh 'bundle exec license_finder report --format html > license_finder_report.html'
end

desc 'Notice about proposal requirements (for AI)'
task :notice do
  puts 'NOTE: Change proposals are *required* to pass "rake default" including'
  puts 'all linters and tests, and *must* have 100% test statement coverage.'
  puts
end

# Don't do whitespace checks on these YAML files:
YAML_WS_EXCEPTIONS ||= ':!test/vcr_cassettes/*.yml'

desc 'Check for trailing whitespace in all text files.'
task :whitespace_check do
  puts 'Checking for trailing whitespace...'

  # Find all files, exclude directories we don't want, exclude comma-prefixed
  # files, use file to identify text files, then check for trailing whitespace
  # This won't handle filenames with \n but those shouldn't be in our repo!
  cmd = <<~SHELL
    find . -type f ! -name ',*' \
      ! -path './vendor/*' ! -path './node_modules/*' \
      ! -path './railroader/*' ! -path './tmp/*' ! -path './temp/*' \
      ! -path './.git/*' \
      ! -path './log/*' ! -path './test/vcr_cassettes/*' \
      ! -path './license_finder_report.html' \
      ! -path './coverage/index.html' \
      ! -path './test/html_reports/*' \
      ! -path './public/assets/*' \
      -print0 | \
    xargs -0 file | \
    awk -F': ' '$2 ~ /(text|script)/ && $2 !~ /(executable|binary)/ \
      {print $1}' | \
    xargs grep -l '[[:space:]]$' 2>/dev/null || true
  SHELL

  output = `#{cmd}`

  if output.empty?
    puts 'No trailing whitespace found.'
  else
    puts 'Trailing whitespace found in these files:'
    puts output
    exit 1
  end
end

desc 'Check YAML syntax (except project.yml, which is not straight YAML)'
task :yaml_syntax_check do
  # Don't check "project.yml" - it's not a straight YAML file, but instead
  # it's processed by ERB (even though the filename doesn't admit it).
  puts 'Checking YAML syntax...'

  find_cmd = "find . -name '*.yml' ! -name 'projects.yml' ! -name ',*' " \
             "! -path './railroader/*' ! -path './vendor/*' ! -path './tmp/*' " \
             '-exec bundle exec yaml-lint {} + 2>&1'

  output = `#{find_cmd}`
  exit_status = $CHILD_STATUS.exitstatus

  if exit_status.zero?
    puts 'YAML syntax check completed successfully.'
  else
    puts 'YAML syntax check failed:'
    puts output
    exit exit_status
  end
end

# The following are invoked as needed.

desc 'Create visualization of gem dependencies (requires graphviz)'
task :bundle_viz do
  sh 'bundle viz --version --requirements --format svg'
end

desc 'Deploy current origin/main to staging'
task deploy_staging: :production_to_staging do
  sh 'git checkout staging && git pull && git merge --ff-only origin/main && git push && git checkout main'
end

desc 'Deploy current origin/staging to production'
task :deploy_production do
  sh 'git checkout production && git pull && git merge --ff-only origin/staging && git push && git checkout main'
end

rule '.html' => '.md' do |t|
  sh "script/my-markdown \"#{t.source}\" | script/my-patch-html > \"#{t.name}\""
end

markdown_files = Rake::FileList.new('*.md', 'docs/*.md')

# Use this task to locally generate HTML files from .md (markdown)
task 'html_from_markdown' => markdown_files.ext('.html')

file 'docs/criteria.md' =>
     [
       'criteria/criteria.yml', 'config/locales/en.yml',
       'docs/criteria-header.markdown', 'docs/criteria-footer.markdown',
       './gen_markdown.rb'
     ] do
  sh './gen_markdown.rb'
end

# Name task so we don't have to use the filename
task generate_criteria_doc: 'docs/criteria.md' do
end

desc 'Use fasterer to report Ruby constructs that perform poorly'
task :fasterer do
  sh 'fasterer'
end

# Tasks for Fastly including purging and testing the cache.
namespace :fastly do
  # Implement purge_all (full purge) of Fastly CDN cache.  Invoke using:
  #   heroku run --app HEROKU_APP_HERE -- rake fastly:purge
  # Run this if code changes will cause a change in badge level, since otherwise
  # the old badge levels will keep being displayed until the cache times out.
  # See: https://robots.thoughtbot.com/
  # a-guide-to-caching-your-rails-application-with-fastly
  # This will cause a SIGNIFICANT temporary increase in activity, since
  # it will completely empty the CDN cache.
  # This requires environment variables to be set, specifically
  # 'FASTLY_API_KEY' and 'FASTLY_SERVICE_ID'. See:
  # https://developer.fastly.com/reference/api/purging/
  # Basically, we'll do POST /service/service_id/purge_all
  # Unfortunately we *cannot* do a soft purge, "Fastly-Soft-Purge: 1"
  # on a purge-all, per the Fastly documentation.
  desc 'Purge ALL of Fastly cache (takes about 5s)'
  task :purge_all do
    puts 'Starting purge ALL of Fastly cache (typically takes about 5s)'
    # The following is needed to load fastly_rails without bringing in the
    # entire Rails environment (which we don't need).
    $LOAD_PATH.append("#{Dir.getwd}/app/lib")
    require 'fastly_rails'
    FastlyRails.purge_all
    puts 'Cache purged'
  end

  desc 'Test Fastly Caching'
  task :test, [:site_name] do |_t, args|
    args.with_defaults site_name: 'https://staging.bestpractices.dev/projects/1/badge'
    puts 'Starting test of Fastly caching'
    verbose(false) do
      sh "script/fastly_test #{args.site_name}"
    end
  end
end

desc 'Drop development database'
task :drop_database do
  puts 'Dropping database development'
  # Command from http://stackoverflow.com/a/13245265/1935918
  sh "echo 'SELECT pg_terminate_backend(pg_stat_activity.pid) FROM " \
     'pg_stat_activity WHERE datname = current_database() AND ' \
     "pg_stat_activity.pid <> pg_backend_pid();' | psql development; " \
     'dropdb -e development'
end

desc 'Copy database from production into development (requires access privs)'
task :pull_production do
  puts 'Getting production database'
  Rake::Task['drop_database'].reenable
  Rake::Task['drop_database'].invoke
  sh 'heroku pg:pull DATABASE_URL development --app production-bestpractices'
  Rake::Task['db:migrate'].reenable
  Rake::Task['db:migrate'].invoke
end

# Don't use this one unless you need to
desc 'Copy active production database into development (if normal one fails)'
task :pull_production_alternative do
  puts 'Getting production database (alternative)'
  sh 'heroku pg:backups:capture --app production-bestpractices && ' \
     'curl -o db/latest.dump `heroku pg:backups:url ' \
     '     --app production-bestpractices` && ' \
     'rake db:reset && ' \
     'pg_restore --verbose --clean --no-acl --no-owner -U `whoami` ' \
     '           -d development db/latest.dump'
end

desc 'Copy active main database into development (requires access privs)'
task :pull_main do
  puts 'Getting main database'
  Rake::Task['drop_database'].reenable
  Rake::Task['drop_database'].invoke
  sh 'heroku pg:pull DATABASE_URL development --app master-bestpractices'
  Rake::Task['db:migrate'].reenable
  Rake::Task['db:migrate'].invoke
end

# This just copies the most recent backup of production; in almost
# all cases this is adequate, and this way we don't disturb production
# unnecessarily.  If you want the current active database, you can
# force a backup with:
# heroku pg:backups:capture --app production-bestpractices
desc 'Copy production database backup to main stage, overwriting main database'
task :production_to_main do
  sh 'heroku pg:backups:restore $(heroku pg:backups:url ' \
     '--app production-bestpractices) DATABASE_URL --app master-bestpractices'
  sh 'heroku run:detached bundle exec rake db:migrate --app master-bestpractices'
end

desc 'Copy production database backup to staging, overwriting staging database'
task :production_to_staging do
  sh 'heroku pg:backups:restore $(heroku pg:backups:url ' \
     '--app production-bestpractices) DATABASE_URL ' \
     '--app staging-bestpractices --confirm staging-bestpractices'
  sh 'heroku run:detached bundle exec rake db:migrate --app staging-bestpractices'
end

# require 'rails/testtask.rb'
# Rails::TestTask.new('test:features' => 'test:prepare') do |t|
#   t.pattern = 'test/features/**/*_test.rb'
# end

task 'test:features' => 'test:prepare' do
  $LOAD_PATH << 'test'
  Minitest.rake_run(['test/features'])
end

# This gem isn't available in production
# Use string comparison, because Rubocop doesn't know about fake_production
if Rails.env.production? || Rails.env == 'fake_production'
  task :eslint do
    puts 'Skipping eslint checking in production (libraries not available).'
  end
else
  require 'eslintrb/eslinttask'
  Eslintrb::EslintTask.new :eslint do |t|
    t.pattern = 'app/assets/javascripts/*.js'
    # If you modify the exclude_pattern, also modify file .eslintignore
    t.exclude_pattern = 'app/assets/javascripts/application.js'
    # The configuration is in .eslintrc
    t.options = :eslintrc
  end
end

desc 'Stub do-nothing jobs:work task to eliminate Heroku log complaints'
task 'jobs:work' do
end

desc 'Run in fake_production mode'
# This tests the asset pipeline
task :fake_production do
  sh 'RAILS_ENV=fake_production bundle exec rake assets:precompile'
  sh 'RAILS_ENV=fake_production bundle check || bundle install'
  sh 'RAILS_ENV=fake_production rails server -p 4000'
end

desc 'precompile assets'
task :precompile do
  sh 'rm -rf tmp/cache/* public/assets/*'
  sh 'bundle exec rake assets:precompile'
end

# rubocop:disable Metrics/MethodLength
def normalize_values(input, locale)
  # The destination locale is "locale".
  input.transform_values! do |value|
    if value.is_a?(Hash)
      normalize_values value, locale
    elsif value.is_a?(String)
      normalize_string value, locale
    elsif value.is_a?(NilClass)
      value
    else
      raise TypeError 'Not Hash, String or NilClass'
    end
  end
end
# rubocop:enable Metrics/MethodLength

# rubocop:disable Metrics/MethodLength
def normalize_string(value, locale)
  # Remove trailing whitespace
  value.sub!(/\s+$/, '')
  # Forcibly substitute GitHub organization with literal string match
  value = value.gsub('github.com/coreinfrastructure/best-practices-badge',
                     'github.com/ossf/best-practices-badge')

  # Forcibly substitute the old production domain with the current one.
  # Our site moved from bestpractices.coreinfrastructure.org to
  # www.bestpractices.dev (we use the www. host, not the bare domain,
  # because bare DNS domains complicate our Fastly CDN setup). Like the
  # GitHub-org rewrite above, this catches stale references that arrive
  # via translation.io so we don't have to hand-edit translated strings.
  value = value.gsub('bestpractices.coreinfrastructure.org',
                     'www.bestpractices.dev')

  return value if value.exclude?('<')

  # Google Translate generates html text that has predictable errors.
  # The last entry mitigates the target=... vulnerability.  We don't need
  # to "counter" attacks from ourselves, but it does no harm and it's
  # easier to protect against everything.
  value.gsub('< a ', '<a ')
       .gsub(/< \057/, '</')
       .gsub(/<\057 /, '</')
       .gsub('<Strong>', '<strong>')
       .gsub('<Em>', '<em>')
       .gsub(/ Href *=/, 'href=')
       .gsub('href = ', 'href=')
       .gsub('class = ', 'class=')
       .gsub('target = ', 'target=')
       .gsub('target="_ blank">', 'target="_blank">')
       .gsub(/target="_blank" *>/, 'target="_blank" rel="noopener">')
       .gsub(%r{https: // }, 'https://')
       .gsub(%r{href="/en/}, "href=\"/#{locale}/")
       .gsub(%r{href='/en/}, "href='/#{locale}/")
end
# rubocop:enable Metrics/MethodLength

def normalize_yaml(path)
  # Reformats with a line-width of 80, removes trailing whitespace from all
  # values and fixes some predictable errors automatically.
  require 'yaml'
  Dir[path].each do |filename|
    # Compute locale from filename (it must be before the last period)
    locale = filename.split('.')[-2]
    normalized = normalize_values(YAML.load_file(filename), locale)
    File.write(filename, normalized.to_yaml(line_width: 60).gsub(/\s+$/, ''))
  end
end

desc "Ensure you're on the main branch"
task :ensure_main do
  raise StandardError, 'Must be on main branch to proceed' unless
    `git rev-parse --abbrev-ref HEAD` == "main\n"

  puts 'On main branch, proceeding...'
end

desc 'Reformat en.yml'
task :reformat_en do
  normalize_yaml Rails.root.join('config', 'locales', 'en.yml')
end

desc 'Fix locale text'
task :fix_localizations do
  normalize_yaml Rails.root.join('config', 'locales', 'translation.*.yml')
end

desc 'Save English translation file as .ORIG file'
task :backup_en do
  FileUtils.cp Rails.root.join('config', 'locales', 'en.yml'),
               Rails.root.join('config', 'locales', 'en.yml.ORIG'),
               preserve: true # this is the equivalent of cp -p
end

desc 'Restore English translation file from .ORIG file'
task :restore_en do
  FileUtils.mv Rails.root.join('config', 'locales', 'en.yml.ORIG'),
               Rails.root.join('config', 'locales', 'en.yml')
end

# The "translation:sync" task syncs up the translations, but uses the usual
# YAML writer, which writes out trailing whitespace.  It should not do that,
# and the trailing whitespace causes later failures in testing, so we fix.
# Problem already reported:
# - https://github.com/aurels/translation-gem/issues/13
# - https://github.com/yaml/libyaml/issues/46
# We save and restore the en version around the sync to resolve.
# The task only runs in development, since the gem is only loaded then.
if Rails.env.development?
  Rake::Task['translation:sync'].enhance %w[ensure_main backup_en] do
    at_exit do
      Rake::Task['restore_en'].invoke
      Rake::Task['fix_localizations'].invoke
      puts "Now run: git commit -sam 'rake translation:sync'"
    end
  end
end

desc 'Fix Gravatar use_gravatar fields for local users'
task fix_use_gravatar: :environment do
  User.where(provider: 'local').find_each do |u|
    actually_exists = u.gravatar_exists
    if u.use_gravatar != actually_exists # Changed result - set and store
      # Use "update_column" so that updated_at isn't changed, and also
      # to do things more quickly.  There are no model validations that
      # can be affected setting this boolean value, so let's skip them.
      # rubocop: disable Rails/SkipsModelValidations
      u.update_column(:use_gravatar, actually_exists)
      # rubocop: enable Rails/SkipsModelValidations
    end
  end
end

require 'net/http'
# Request uri, reply true if fetchable. Follow redirects 'limit' times.
# See: https://docs.ruby-lang.org/en/2.0.0/Net/HTTP.html
# rubocop:disable Metrics/MethodLength
def fetchable?(uri_str, limit = 10)
  return false if limit <= 0

  # Use GET, not HEAD. Some websites will say a page doesn't exist when given
  # a HEAD request, yet will redirect correctly on a GET request. Ugh.
  response = Net::HTTP.get_response(URI.parse(uri_str))
  case response
  when Net::HTTPSuccess then
    return true
  when Net::HTTPRedirection then
    # Recurse, because redirection might be to a different site
    location = response['location']
    warn "    redirected to <#{location}>"
    return fetchable?(location, limit - 1)
  else
    return false
  end
end
# rubocop:enable Metrics/MethodLength

def link_okay?(link)
  return false if link.blank?
  # '%{..}' is used when we generate URLs, presume they're okay.
  return true if link.start_with?('mailto:', '/', '#', '%{')
  # Shortcut: If we have anything other than http/https, it's wrong.
  return false unless link.start_with?('https://', 'http://')
  # Quick check - if there's a character other than URI-permitted, fail.
  # Note that space isn't included (including space is a common error).
  return false if %r{[^-A-Za-z0-9_\.~!*'\(\);:@\&=+\$,\/\?#\[\]%]}.match?(link)

  warn "  <#{link}>"
  fetchable?(link)
end

def validate_links_in_string(translation, from, seen)
  translation.scan(/href=["'][^"']+["']/).each do |snippet|
    link = snippet[6..-2]
    next if seen.include?(link) # Already seen it, don't complain again.

    if link_okay?(link)
      seen.add(link)
    else
      # Don't add failures to what we've seen, so that we report all failures
      puts "\nFAILED LINK IN #{from.join('.')} : <#{link}>"
    end
  end
end

# Recursive validate links.  "seen" refers to a set of links already seen.
# To recurse we really want kind_of?, not is_a?, so disable rubocop rule
# rubocop:disable Style/ClassCheck
def validate_links(translation, from, seen)
  if translation.kind_of?(Array)
    translation.each_with_index do |i, part|
      validate_links(part, from + [i], seen)
    end
  elsif translation.kind_of?(Hash)
    translation.each { |key, part| validate_links(part, from + [key], seen) }
  elsif translation.kind_of?(String) # includes safe_html
    validate_links_in_string(translation.to_s, from, seen)
  end
end
# rubocop:enable Style/ClassCheck

desc 'Validate hypertext links'
task validate_hypertext_links: :environment do
  seen = Set.new # Track what we've already seen (we'll skip them)
  I18n.available_locales.each do |loc|
    validate_links I18n.t('.', locale: loc), [loc], seen
  end
end

# Convert project.json -> project.sql (a command to re-insert data).
# This only *generates* a SQL command; I did it this way so that it's easy
# to check the command to be run *before* executing it, and this also makes
# it easy to separately determine the database to apply the command to.
# Note that this depends on non-standard PostgreSQL extensions.
desc 'Convert file "project.json" into SQL insertion command in "project.sql".'
task :create_project_insertion_command do
  puts 'Reading file project.json (this uses PostgreSQL extensions)'
  file_contents = File.read('project.json')
  data_hash = JSON.parse(file_contents)
  project_id = data_hash['id']
  puts "Inserting project id #{project_id}"
  # Escape JSON using SQL escape ' -> '', so we can use it in a SQL command
  escaped_json = "'" + file_contents.gsub("'", "''") + "'"
  sql_command = 'insert into projects select * from ' + "json_populate_record(NULL::projects, #{escaped_json});"
  File.write('project.sql', sql_command)
  puts 'File project.sql created. To use this, do the following (examples):'
  puts 'Local:  rails db < project.sql'
  puts 'Remote: heroku pg:psql --app production-bestpractices < project.sql'
end

# Change owner of PROJECT to USER. Both must be numbers. To use:
# heroku run --app production-bestpractices rake change_owner -- PROJECT OWNER
# You can run a SQL command to do this instead, but an error such as
# forgetting the WHERE clause can cause a big mistake. The statement would be:
# echo "UPDATE projects SET user_id = {OWNER_NUM} WHERE id = {PROJECT_NUM}" | \
#  heroku pg:psql --app master-bestpractices

desc 'Change owner of PROJECT. rake change_owner -- PROJECT_NUM NEW_OWNER_NUM'
task change_owner: :environment do
  # Project.update_all_badge_percentages(Criteria.keys)
  ARGV.shift # Drop rake task name
  ARGV.shift # Drop '--'
  project_number = Integer(ARGV.first) # Raise exceptions on non-integers
  user_number = Integer(ARGV[1])
  # Retrieve and print current project/owner
  project = Project.find(project_number.to_i)
  puts("Project      ##{project.id} #{project.name}")
  old_owner_id = project.user_id
  old_owner_name = User.find_by(id: old_owner_id)&.name
  puts("Former owner ##{old_owner_id} #{old_owner_name}")
  # Retrieve and print new owner info
  new_owner_id = user_number.to_i
  new_owner_record = User.find(new_owner_id)
  new_owner_name = new_owner_record.name
  puts("New owner    ##{new_owner_id} #{new_owner_name}")
  # Cause change
  if project.user_id == new_owner_id
    puts('No change, nothing done')
  else
    project.user_id = new_owner_id
    project.save!
    puts("Revert with: rake change_owner -- #{project.id} #{old_owner_id}")
  end
  # Rake tries to run the arguments which is annoying.
  # ARGV.shift; ARGV.shift doesn't work, so just flat-out exit(0).
  exit(0)
end

# Use this if the badge rules change.  This will email those who
# lose a badge because of the changes (gains are not emailed here).
desc 'Run to recalculate all badge percentages for all projects'
task update_all_badge_percentages: :environment do
  Project.update_all_badge_percentages(Criteria.keys)
end

desc 'Run to recalculate higher-level badge percentages for all projects'
task update_all_higher_level_badge_percentages: :environment do
  Project.update_all_badge_percentages(Criteria.keys - ['0'])
end

desc 'Backfill baseline_tiered_percentage for all projects'
task backfill_baseline_tiered_percentage: :environment do
  puts 'Backfilling baseline_tiered_percentage for all projects...'
  count = 0
  # Small batch: projects are very wide (>400 cols), so the default 1000 can
  # OOM a 512MB dyno. See Project::BULK_RECALC_BATCH_SIZE.
  Project.find_each(batch_size: Project::BULK_RECALC_BATCH_SIZE) do |project|
    # rubocop:disable Rails/SkipsModelValidations
    # Intentionally skip validations for performance; we're computing from existing data
    project.update_column(:baseline_tiered_percentage,
                          project.compute_baseline_tiered_percentage)
    # rubocop:enable Rails/SkipsModelValidations
    count += 1
    puts "Processed #{count} projects..." if (count % 1000).zero?
  end
  puts "Done. Updated #{count} projects."
end

# Rekeys all stored user email addresses after an EMAIL_ENCRYPTION_KEY rotation.
# See docs/secrets-policy.md for the full rotation procedure (including
# how to use BADGEAPP_DENY_LOGIN to quiesce the database first).
# Safe to re-run if interrupted; users that fail to rekey are skipped.
desc 'Rekey (change keys) of email addresses'
task rekey: :environment do
  old_key = [ENV.fetch('EMAIL_ENCRYPTION_KEY_OLD', nil)].pack('H*')
  User.find_each do |u|
    # rubocop:disable Style/RedundantBegin
    begin
      u.rekey(old_key) # Raises exception if there's a CipherError.
      Rails.logger.info "Rekeyed email address of user id #{u.id}"
      u.save! if u.email.present?
    rescue OpenSSL::Cipher::CipherError
      Rails.logger.info "Cannot rekey user #{u.id}"
    end
    # rubocop:enable Style/RedundantBegin
  end
end

Rake::Task['test:run'].enhance ['test:features']

# Ensure assets are precompiled before running any test task.
# Outside CI: auto-recompiles if stale (avoids hours of debugging cache bugs).
# In CI: fails fast to catch missing precompilation in the pipeline.
# NOTE: Added as a test-task prereq rather than in an initializer,
# to avoid the startup-time interference described in
# lib/asset_staleness_middleware.rb (e.g., assets:precompile itself
# starts with stale assets — checking at startup would spuriously fail it).
%w[test test:all test:system].each do |t|
  Rake::Task[t].enhance(['test:ensure_assets']) if Rake::Task.task_defined?(t)
end

desc 'Ensure precompiled assets are current before running tests'
task 'test:ensure_assets' => :environment do
  # require_relative path from lib/tasks/ up to project root then into lib/
  require_relative '../../lib/asset_staleness_checker'
  checker = AssetStalenessChecker.from_rails_config(Rails.application)
  next unless checker&.assets_stale?

  if ENV['CI']
    abort 'ERROR: Stale precompiled assets detected. Run: rake assets:precompile'
  else
    warn 'WARNING: Stale assets detected, auto-recompiling...'
    Rake::Task['assets:precompile'].invoke
  end
end

# Clear test coverage results to start fresh.
# SimpleCov merges results from previous runs, which can be misleading
# if there's "old" information present.
desc 'Clear all previous test coverage results'
task 'test:clear' do
  puts 'test:clear - Clearing all previous test coverage results.'

  # Remove the entire directory to ensure a 100% fresh start
  # with no previous results. It will be recreated later.
  coverage_dir = Rails.root.join('coverage')
  FileUtils.rm_rf(coverage_dir)
end

# Run all tests with parallelization for regular tests.
# System tests run separately (serial) due to fixed Capybara port binding
# and the heavy load imposed by system tests.
# SimpleCov automatically merges coverage from all parallel workers.
# Clears coverage first to avoid merging stale results from previous runs.
desc 'Run ALL tests: regular tests parallelized, system tests serial'
task 'test:optimized' => 'test:ensure_assets' do
  puts 'To see test names, set env var SLOW=true' if ENV['SLOW'].to_s.empty?

  require 'simplecov'
  # Clear all previous test results FIRST so we have clean results
  Rake::Task['test:clear'].invoke
  # Set an ENV var so SimpleCov knows not to format the report yet
  ENV['DEFER_COVERAGE'] = 'true'
  # Prepare the test database
  Rake::Task['test:prepare'].invoke

  # Run "normal" tests and report their intermediate results
  sh 'rails test'
  # result.covered_percent calculates based on what's in the
  # .resultset.json right now, WITHOUT indicating that we're done testing
  intermediate_total = SimpleCov.result.covered_percent.round(2)
  puts "\nIntermediate Coverage (Regular Tests): #{intermediate_total}%\n"

  sh 'rails test:system'
  # Report any coverage gaps
  Rake::Task['test:coverage_gaps'].invoke
end

desc 'Report coverage gaps from SimpleCov results'
task 'test:coverage_gaps' do
  require 'simplecov'

  puts 'Merging results from all runs...'
  # It returns a SimpleCov::Result object.
  result = SimpleCov::ResultMerger.merged_result

  puts "Combined Coverage: #{result.covered_percent.round(2)}%"

  # In CI, write coverage/coverage.json from the merged result so the
  # Codecov CLI (see .circleci/config.yml) has a file to upload. This MUST
  # happen here, not in test_helper.rb: the test workers run with
  # DEFER_COVERAGE set, which swaps in the minimal SimpleFormatter, so a
  # report formatter never runs during the test processes. The merged
  # result is only complete once all parallel + system test runs finish.
  #
  # We use SimpleCov::Formatter::JSONFormatter (from simplecov_json_formatter,
  # a dependency of simplecov) because Codecov's backend natively parses its
  # output. We previously used the abandoned 'codecov' gem's formatter, but
  # it emits the deprecated "network" report format that the current Codecov
  # backend rejects as "unusable report ... incorrect data format", silently
  # yielding 0% coverage on the site even though the upload itself succeeds.
  if ENV['CI']
    require 'simplecov_json_formatter'
    SimpleCov::Formatter::JSONFormatter.new.format(result)
  end

  # Iterate through files using SimpleCov's own 'missed_lines' logic
  # to report what we missed.
  gaps_found = false
  result.files.each do |source_file|
    missed_lines = source_file.missed_lines.map(&:line_number)

    next if missed_lines.empty?

    # We have missed lines. Group consecutive lines into ranges.
    ranges = []
    missed_lines.sort.each do |line|
      if ranges.empty? || ranges.last.last != line - 1
        ranges << [line, line]
      else
        ranges.last[1] = line
      end
    end

    range_strs = ranges.map { |f, l| f == l ? f.to_s : "#{f}-#{l}" }
    relative_path = source_file.filename.sub("#{Rails.root}/", '')
    puts 'FAILURE: Untested production code statements exist.' unless gaps_found
    puts 'Untested lines (FILENAME: LINE NUMBERS) are:' unless gaps_found
    puts "#{relative_path}: #{range_strs.join(', ')}"
    gaps_found = true
  end

  puts 'All files have 100% statement coverage.' unless gaps_found
  raise StandardError, 'Has untested production code statements.' if gaps_found
end

# This is the task to run every day, e.g., to record statistics
# Configure your system (e.g., Heroku) to run this daily.  If you're using
# Heroku, see: https://devcenter.heroku.com/articles/scheduler
desc 'Run daily tasks used in any tier, e.g., record daily statistics'
task daily: :environment do
  ProjectStat.create!
  puts 'Purging never-activated local accounts older than ' \
       "#{User::UNACTIVATED_ACCOUNT_LIFETIME.inspect}."
  puts "Purged #{User.purge_unactivated_accounts} never-activated account(s)."
  day_for_monthly = (ENV['BADGEAPP_DAY_FOR_MONTHLY'] || '5').to_i
  Rake::Task['monthly'].invoke if Time.now.utc.day == day_for_monthly
end

# List purgeable users (never-activated local accounts older than
# UNACTIVATED_ACCOUNT_LIFETIME that have no project or additional rights)
# to stdout as CSV, one per line: name, email, created_at.
# Requires EMAIL_ENCRYPTION_KEY and EMAIL_BLIND_INDEX_KEY to decrypt emails.
# Example: EMAIL_ENCRYPTION_KEY=... EMAIL_BLIND_INDEX_KEY=... rake list_purgeable_unactivated_users
desc 'Print purgeable never-activated local accounts to stdout as CSV.'
task list_purgeable_unactivated_users: :environment do
  require 'csv'
  csv = CSV.new($stdout)
  csv << %w[name email created_at]
  User.purgeable_unactivated_accounts.find_each do |user|
    csv << [user.name, user.email_if_decryptable, user.created_at.iso8601]
  end
end

# Identify activated local accounts that look like bot/spam registrations.
# Used by list_suspicious_activated_users and purge_suspicious_activated_users.
# Each yields/lists only accounts that:
#   - are local (password-based), activated, own no projects, have no
#     additional_rights, have not logged in for over a year (or never), and
#     were created more than a year ago.
#
# Heuristics (reasons) reported per account:
#
#   random_email   - the local part has 4+ dot-separated segments of 1-3 chars,
#                    matching the fragmented pattern bots use to register many
#                    accounts from one Gmail address (Gmail ignores dots in the
#                    local part, so a.b.c.d@gmail.com and abcd@gmail.com
#                    deliver to the same inbox). Note: some privacy-conscious
#                    users deliberately dot their own address as a
#                    spam-tracking alias per service, but such users typically
#                    log in and own projects (both filtered out above).
#
# The following name heuristics apply only to Latin-script names (names
# containing characters outside U+0000-U+024F are skipped — they may be
# Chinese, Arabic, Cyrillic, etc. and require different analysis):
#
#   low_vowels     - fewer than 15% of letters are vowels (aeiou/y plus common
#                    accented Latin vowels). All human languages use vowels;
#                    a very low ratio strongly suggests a random string.
#
#   consonant_run  - 5 or more consecutive consonants within a single word.
#                    Even the most consonant-heavy natural languages rarely
#                    exceed 4 in a row.
#
#   rare_letters   - more than 35% of inner-word letters (excluding capitalised
#                    first letters, which are conventional in proper names) are
#                    from {q, x, z, j} — uncommon in nearly all Latin-script
#                    languages.
#

# Yields each suspicious activated user with their decrypted email and reasons.
# rubocop:disable Metrics/MethodLength
def each_suspicious_activated_user
  one_year_ago = 1.year.ago
  User.where(provider: 'local', activated: true)
      .where('last_login_at < ? OR last_login_at IS NULL', one_year_ago)
      .where(created_at: ...one_year_ago)
      .where.missing(:projects)
      .where.missing(:additional_rights)
      .find_each do |user|
    email = user.email_if_decryptable
    reasons = SuspiciousUserUtils.name_suspicion_reasons(user.name.to_s)
    reasons << 'random_email' if SuspiciousUserUtils.suspicious_email?(email)
    next if reasons.empty?

    yield user, email, reasons
  end
end
# rubocop:enable Metrics/MethodLength

desc 'Print suspicious activated local accounts to stdout as CSV.'
task list_suspicious_activated_users: :environment do
  require 'csv'
  csv = CSV.new($stdout)
  csv << %w[name email created_at last_login_at reasons]
  each_suspicious_activated_user do |user, email, reasons|
    csv << [
      user.name, email, user.created_at.iso8601,
      user.last_login_at&.iso8601, reasons.join(';')
    ]
  end
end

desc 'Destroy suspicious activated local accounts (see list_suspicious_activated_users).'
task purge_suspicious_activated_users: :environment do
  count = 0
  each_suspicious_activated_user do |user, _email, _reasons|
    user.destroy
    count += 1
  end
  puts "Purged #{count} suspicious activated account(s)."
end

# Run this task to email a limited set of reminders to inactive projects
# and to drain any pending badge-loss or badge-warning notification queues.
# Configure your system (e.g., Heroku) to run this daily.  If you're using
# Heroku, see: https://devcenter.heroku.com/articles/scheduler
# rubocop:disable Style/Send
desc 'Send daily reminder and badge-notification emails (rate-limited).'
task reminders: :environment do
  puts 'Sending inactive project reminders. List of reminded project ids:'
  p ProjectsController.send :send_reminders
  puts 'Sending badge-loss notifications. Emails sent:'
  p Project.send_loss_notifications
  puts 'Sending badge-warning notifications. Emails sent:'
  p Project.send_warning_notifications
  true
end
# rubocop:enable Style/Send

# Send badge-loss notifications as a standalone task.
# Normally this is called automatically by the 'reminders' task.
# Only notifies owners whose badge was lost due to criteria changes
# (set by update_all_badge_percentages). Respects user important_notifications
# preference and caps at BADGEAPP_MAX_BADGE_LOSS_NOTIFICATIONS (default 10).
desc 'Send badge-loss notifications (rate-limited); also runs via reminders.'
task badge_loss_notifications: :environment do
  puts 'Sending badge-loss notifications. Emails sent:'
  p Project.send_loss_notifications
  true
end

# Run this task to preview which projects would lose a badge when criteria
# change.  No database writes are made; results are printed to stdout.
# Provide the date the criteria change takes effect via EFFECTIVE_DATE.
# Example: rake badge_warning_report EFFECTIVE_DATE=2026-05-01
desc 'Print projects that would lose a badge when criteria change (no DB writes).'
task badge_warning_report: :environment do
  date_str =
    ENV.fetch('EFFECTIVE_DATE') do
      raise ArgumentError, 'Set EFFECTIVE_DATE=YYYY-MM-DD'
    end
  Project.update_all_badge_warnings(
    Criteria.keys, effective_date: Date.parse(date_str), report: true
  )
end

# Run this task once after reviewing badge_warning_report to set the warning
# flags so that badge_warning_notifications can send emails.
# Example: rake update_badge_warnings EFFECTIVE_DATE=2026-05-01
desc 'Set badge-warning flags for projects that will lose a badge.'
task update_badge_warnings: :environment do
  date_str =
    ENV.fetch('EFFECTIVE_DATE') do
      raise ArgumentError, 'Set EFFECTIVE_DATE=YYYY-MM-DD'
    end
  Project.update_all_badge_warnings(
    Criteria.keys, effective_date: Date.parse(date_str)
  )
end

# Send badge-warning notifications as a standalone task.
# Normally this is called automatically by the 'reminders' task.
# Only notifies owners whose badge WILL BE lost due to upcoming criteria
# changes (set by update_badge_warnings). Respects user important_notifications
# preference and caps at BADGEAPP_MAX_BADGE_WARNING_NOTIFICATIONS (default 10).
desc 'Send badge-warning notifications (rate-limited); also runs via reminders.'
task badge_warning_notifications: :environment do
  puts 'Sending badge-warning notifications. Emails sent:'
  p Project.send_warning_notifications
  true
end

# rubocop:disable Style/Send
desc 'Send monthly announcement of passing projects'
task monthly_announcement: :environment do
  puts 'Sending monthly announcement. List of reminded project ids:'
  p ProjectsController.send :send_monthly_announcement
  true
end
# rubocop:enable Style/Send

desc 'Run monthly tasks (called from "daily")'
task monthly: %i[environment monthly_announcement fix_use_gravatar] do
end

# Send a mass email, subject MASS_EMAIL_SUBJECT, body MASS_EMAIL_BODY.
# If you set MASS_EMAIL_WHERE, only matching records will be emailed.
# We send *separate* emails for each user, so that users won't be able
# to learn of each other's email addresses.
# We do *NOT* try to localize, for speed.
desc 'Send a mass email (e.g., a required GDPR notification)'
task :mass_email do
  subject = ENV.fetch('MASS_EMAIL_SUBJECT', nil)
  body = ENV.fetch('MASS_EMAIL_BODY', nil)
  where_condition = ENV['MASS_EMAIL_WHERE'] || 'true'
  raise if !subject || !body

  User.where(where_condition).find_each do |u|
    UserMailer.direct_message(u, subject, body).deliver_now
    Rails.logger.info "Mass notification sent to user id #{u.id}"
  end
end

# Run this task periodically if we want to test the
# install-badge-dev-environment script
desc 'check that install-badge-dev-environment works'
task :test_dev_install do
  puts 'Updating test-dev-install branch'
  sh <<-TEST_BRANCH_SHELL
    git checkout test-dev-install
    git merge --no-commit main
    git checkout HEAD circle.yml
    git commit -a -s -m "Merge main into test-dev-install"
    git push origin test-dev-install
    git checkout main
  TEST_BRANCH_SHELL
end

# Run some slower tests. Doing this on *every* automated test run would be
# slow things down, and the odds of them being problems are small enough
# that the slowdown is less worthwhile.  Also, some of the tests (like the
# CORS tests) can interfere with the usual test setups, so again, they
# aren't worth running in the "normal" automated tests run on each commit.
desc 'Run slow tests (e.g., CORS middleware stack location)'
task :slow_tests do
  # Test CORS library middleware stack location check in environments.
  # Because of the way it works, Rack::Cors *must* be first in the Rack
  # middleware stack, as documented here: https://github.com/cyu/rack-cors
  # This test verifies this precondition, because it'd be easy to
  # accidentally cause this assumption to fail as code is changed and
  # gems are added or updated.
  # This is a slow test (we bring up a whole environment).
  %w[production development test].each do |environment|
    command = "RAILS_ENV=#{environment} rake middleware"
    result = IO.popen(command).readlines.grep(/^use /).first.chomp
    Kernel.abort("Misordered #{command}") unless result == 'use Rack::Cors'
  end
end

# Search for & print matching email address.
# Presumes we are in a Rails environment
def real_search_email(email)
  # Trivial email validation check. This isn't sophisticated, this is primarily
  # to prevent swapping the email & name fields when calling search_user.
  raise ArgumentError unless /.+@.+/.match?(email)

  results = User.where(email: email).select('id, name, encrypted_email, encrypted_email_iv').pluck(
    :id, :name
  )
  puts results
end

# Search for a given user email address.
desc 'Search for users with given email (for GDPR requests)'
task search_email: :environment do
  ARGV.shift # Drop rake task name
  ARGV.shift if ARGV.first == '--' # Skip garbage
  email = ARGV.first
  puts "Searching for email '#{email}'; matching ids and names are:"
  real_search_email(email)
  puts 'End of results.'
  exit(0) # Work around rake
end

# Search for & print matching name.
# Presumes we are in a Rails environment
def real_search_name(name)
  name_downcase = name.downcase
  results = User.where('lower(name) LIKE ?', "%#{name_downcase}%")
                .select('id, name, encrypted_email, encrypted_email_iv')
                .pluck(:id, :name)
  puts results
end

# Search for a given user name.
# Note: This is slow, because we don't have an index for this.
# We instead must linerarly search the database.
# However, we only get 1-5 requests/month, the queries are from a
# trusted source, and speed isn't critical, so we haven't bothered.
# We use a case-mapped search and LIKE, to greatly reduce the risk of
# failing to find the user name.
desc 'Search for users with given case-insensitive name (for GDPR requests)'
task search_name: :environment do
  ARGV.shift # Drop rake task name
  ARGV.shift if ARGV.first == '--' # Skip garbage
  name = ARGV.first
  puts "Searching for name '#{name}' ignoring case; matching ids and names are:"
  real_search_name(name)
  puts 'End of results.'
  exit(0) # Work around rake
end

# Search for a given user name AND email address.
desc 'Search for users with NAME and EMAIL (for GDPR requests)'
task search_user: :environment do
  ARGV.shift # Drop rake task name
  ARGV.shift if ARGV.first == '--' # Skip garbage
  name = ARGV.first
  email = ARGV[1]
  puts "Searching for name '#{name}', email #{email} (ignoring case for both)"
  real_search_name(name)
  real_search_email(email)
  puts 'Done.'
  exit(0) # Work around rake
end

desc 'Search stdin tab-separated values "Name" and "Email 1" (for GDPR)'
task search_users_tsv: :environment do
  # Read 1 line, which are the tab-separated-value headers
  # Find the column numbers for 'Name' and 'Email 1', case-insensitive
  # (if no 'Email 1', try 'Email').
  header_line = STDIN.readline.chomp
  headers = header_line.split("\t")

  # Find column indices case-insensitively
  name_col = headers.find_index { |h| h.casecmp('name').zero? }
  email_col = headers.find_index { |h| h.casecmp('email 1').zero? } ||
              headers.find_index { |h| h.casecmp('email').zero? }

  unless name_col && email_col
    puts "Error: Could not find columns 'Name' and 'Email[ 1]'"
    puts "Found headers: #{headers.inspect}"
    exit(1)
  end

  # In a loop, read a line from stdin, it's tab separated.
  # Find 'name' and 'email' from corresponding columns
  # In the loop, find them.
  STDIN.each_line do |line|
    fields = line.chomp.split("\t")
    name = fields[name_col]&.strip
    email = fields[email_col]&.strip

    if name.present?
      real_search_name(name)
    end
    if email.present?
      real_search_email(email)
    end
    puts '---'
  end
end

# Helper function, escape characters for shell
def shell_escape(s)
  # Prepend `\` in front of chars unless A-Za-z0-9._@
  return '""' if s.blank?

  # Escape by surrounding with double quotes and escaping double quotes and backslashes
  '"' + s.gsub('\\', '\\\\').gsub('"', '\\"') + '"'
end

def shell_escape_if_known(s)
  if s.blank? || s == '??'
    'UNKNOWN'
  else
    shell_escape(s)
  end
end

desc 'Search remotely stdin tab-separated values "Name" and "Email" (for GDPR)'
task search_remote_users_tsv: :environment do
  # Read 1 line, which are the tab-separated-value headers
  # Find the column numbers for 'Name' and 'Email 1', case-insensitive
  # (if no 'Email 1', try 'Email').
  header_line = STDIN.readline.chomp
  headers = header_line.split("\t")

  # Find column indices case-insensitively
  name_col = headers.find_index { |h| h.casecmp('name').zero? }
  email_col = headers.find_index { |h| h.casecmp('email 1').zero? } ||
              headers.find_index { |h| h.casecmp('email').zero? }
  email2_col = headers.find_index { |h| h.casecmp('email 2').zero? }

  unless name_col && email_col
    puts "Error: Could not find columns 'Name' and 'Email[ 1]'"
    puts "Found headers: #{headers.inspect}"
    exit(1)
  end

  # In a loop, read a line from stdin, it's tab separated.
  # Find 'name' and 'email' from corresponding columns
  # We're passing through a remote shell so we must shell escape everything.
  STDIN.each_line do |line|
    fields = line.chomp.split("\t")
    name = shell_escape_if_known(fields[name_col]&.strip)
    email = shell_escape_if_known(fields[email_col]&.strip&.delete_prefix('email: '))

    system("heroku run --app production-bestpractices rake search_user -- #{name} #{email}")
    if email2_col
      email2 = shell_escape_if_known(fields[email2_col]&.strip)
      if email2 != 'UNKNOWN'
        system("heroku run --app production-bestpractices rake search_email -- #{email2}")
      end
    end
    puts '---'
  end
end

desc 'Update Database list of bad passwords from raw-bad-passwords-lowercase'
task update_bad_password_db: :environment do
  BadPassword.force_load
end

desc 'Update SVG badge images from shields.io'
task :update_badge_images do
  # require 'Paleta'
  sh 'curl -o app/assets/images/badge_static_passing.svg ' \
     'https://img.shields.io/badge/openssf_best_practices-passing-4c1'
  sh 'curl -o app/assets/images/badge_static_silver.svg ' \
     'https://img.shields.io/badge/openssf_best_practices-silver-c0c0c0'
  sh 'curl -o app/assets/images/badge_static_gold.svg https://img.shields.io/badge/openssf_best_practices-gold-ffd700'
  100.times do |percent|
    # scale "color" to be greener as we approach passing, to provide a
    # visual indication of progress for those who can see color
    color = Paleta::Color.new(:hsl, (percent * 0.45) + 15, 85, 43).hex
    puts(color)
    sh "curl -o app/assets/images/badge_static_#{percent}.svg " \
       'https://img.shields.io/badge/openssf_best_practices-in_progress_' \
       "#{percent}%25-#{color}"
  end
  # TODO: Capture widths
  sh <<-CAPTURE_WIDTHS
    file='app/assets/images/badge_static_widths.txt'
    echo '{' > "$file"
    for level in passing silver gold $(seq 0 99)
    do
      width=$(grep -Eo 'width="[0-9]*"' app/assets/images/badge_static_"$level".svg | head -1 | tr -dc '0-9')
      echo "  '${level}': ${width}," >> "$file"
    done
    echo '}' >> "$file"
  CAPTURE_WIDTHS
  puts <<-REMINDERS
    Reminders:
    Extract app/assets/images/badge_static_widths.txt into app/models/badge.rb
    cp -p app/assets/images/badge_static_passing.svg \
          test/fixtures/files/badge-passing.svg
    cp -p app/assets/images/badge_static_silver.svg \
          test/fixtures/files/badge-silver.svg
    cp -p app/assets/images/badge_static_gold.svg \
          test/fixtures/files/badge-gold.svg
    cp -p app/assets/images/badge_static_88.svg \
          test/fixtures/files/badge-88.svg
  REMINDERS
end

desc 'Generate unsubscribe URL for email address in brackets'
task :generate_unsubscribe_url, [:email] => :environment do |_t, args|
  if args.email.blank?
    puts 'Error: Email address is required'
    puts 'Usage: rake generate_unsubscribe_url[user@example.com]'
    exit 1
  end

  email = args.email.strip

  # Invoking the helper is complicated because it calls Rails libraries.
  # Configure URL options for the rake environment (read-only)
  base_url = ENV['PUBLIC_HOSTNAME'] || 'bestpractices.dev'
  protocol = Rails.application.config.force_ssl ? 'https' : 'http'

  # Create a simple module that provides URL options without modifying globals
  url_helper =
    Module.new do
      include Rails.application.routes.url_helpers
      include UnsubscribeHelper

      define_method :default_url_options do
        { host: base_url, protocol: protocol }
      end
    end

  # Extend an object with our helper module
  helper_instance = Object.new.extend(url_helper)

  # Generate URL (nil locale lets browser preference determine locale)
  url = helper_instance.generate_unsubscribe_url(email, locale: nil)
  puts url
end

# Fields to check for markdown optimization analysis.
# Defined as a method to allow lazy loading (Project may not be available
# at rake file load time).
def md_optimization_fields
  @md_optimization_fields ||= [
    *Project::ALL_CRITERIA_JUSTIFICATION_STRINGS, 'description'
  ].freeze
end

# Categorize a field's content for markdown optimization analysis.
# @param content [String, nil] The field content to categorize
# @return [Symbol] The category (:is_nil, :blank, :prefixed_url,
#                  :markdown_unnecessary, or :call_markdown_processor)
def categorize_markdown_content(content)
  return :is_nil if content.nil?
  return :blank if content.blank?

  stripped = content.to_s.strip
  if stripped.match(MarkdownProcessor::PREFIXED_URL_REGEX)
    :prefixed_url
  elsif stripped.match?(MarkdownProcessor::MARKDOWN_UNNECESSARY)
    :markdown_unnecessary
  else
    :call_markdown_processor
  end
end

# Process a single project's markdown fields for optimization analysis.
# @param project [Project] The project to analyze
# @param processor [Redcarpet::Markdown] The markdown processor
# @param counts [Hash] Hash to accumulate category counts
def analyze_project_markdown(project, processor, counts)
  puts "Project #{project.id} (#{project.name}):"
  md_optimization_fields.each do |field|
    content = project[field]
    category = categorize_markdown_content(content)
    counts[category] += 1
    # Check that we *can* render this as markdown.
    # This will help us detect errors in the markdown processor.
    if category != :is_nil && category != :blank
      processor.render(content.to_s.strip)
    end
  end
  # Project description is also shown truncated, so make sure we
  # can also render *that* as markdown.
  # See app/views/projects/_table.html.erb:31-33:
  short_description = project.description.to_s.truncate(160, separator: ' ')
  processor.render(short_description)
end

desc 'Print markdown optimization information and verify processability.'
# Use :environment to bring in Rails
task markdown_optimizations: :environment do
  projects = Project.order(:id) # rubocop:disable Rails/OrderById

  # Guard clause: Exit early if there is nothing to process
  if projects.none?
    puts 'No projects found. Exiting.'
    next # Use 'next' to exit the task block early
  end

  renderer = Redcarpet::Render::HTML.new(
    InvokeRedcarpet::REDCARPET_MARKDOWN_RENDERER_OPTS
  )
  processor = Redcarpet::Markdown.new(
    renderer, InvokeRedcarpet::REDCARPET_MARKDOWN_PROCESSOR_OPTS
  )

  counts = Hash.new(0) # default count is 0

  projects.each do |project|
    analyze_project_markdown(project, processor, counts)
  end
  puts counts
  puts "\nFinal results:"
  puts "Number of projects = #{Project.count}"
  texts = counts.values.sum
  puts "Number of texts = #{texts}"
  nil_texts = counts[:is_nil]
  counts.delete(:is_nil)
  non_nil_texts = counts.values.sum
  puts "Number of nil texts = #{nil_texts} (#{(100 * nil_texts.to_f / texts).round(2)}%)"
  puts "Number of non-nil texts = #{non_nil_texts} (#{(100 * non_nil_texts.to_f / texts).round(2)}%)"
  puts "\nStatistics among the non-nil texts:"
  counts.each do |key, value|
    puts "Category #{key} count=#{value} (#{(100 * value.to_f / non_nil_texts).round(2)}%)"
  end
end

desc 'Print hello as simple smoke test.'
task :hello do
  puts 'Hello'
end
