# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# SimpleCov configuration. SimpleCov automatically loads this file from the
# project root on `require 'simplecov'`, so it is the single source of truth
# for coverage configuration.
#
# Put configuration HERE, *not* in test/test_helper.rb. Two separate kinds of
# processes must agree on these settings:
#
#   1. The test processes, which measure coverage and write results.
#      test/test_helper.rb calls SimpleCov.start.
#   2. The rake process that merges those results and reports coverage gaps
#      ('test:optimized' and 'test:coverage_gaps' in lib/tasks/default.rake),
#      which only does `require 'simplecov'`.
#
# Anything configured solely in test_helper.rb is invisible to (2), and that
# bit us badly: merge_timeout was set to 3600 in test_helper.rb, but the
# merging rake process kept SimpleCov's 600-second default. Once the slow
# system tests pushed a run past 10 minutes, the merge silently discarded
# every regular-test result as "expired", so thoroughly tested code was
# reported as completely untested. See merge_timeout below.
#
# NOTE: If you change SimpleCov configuration (used locally), you may also
# need to change codecov configuration (used on the website) as managed
# via codecov.yml.

SimpleCov.configure do
  load_profile 'rails'

  # Ensure this is NOT set to false - we use its test merging capabilities
  merging true

  # merge_timeout must exceed the duration of an ENTIRE `rake test:optimized`
  # run, not just one test process. That run writes the regular tests'
  # results, then runs the much slower system tests, and only merges
  # everything at the end. Any result older than merge_timeout is dropped
  # from the merged report; because coverage is reported per line, a dropped
  # result does not look like an error, it looks like a large block of
  # untested code. SimpleCov's default is only 600 seconds (10 minutes).
  #
  # 'test:optimized' deletes coverage/ before it starts (see 'test:clear'),
  # so every result present is from the current run and none should expire.
  merge_timeout 3600

  # Give each process a unique name so they don't overwrite each other
  # if running in parallel.
  command_name "job-#{ENV['TEST_ENV_NUMBER'] || 'manual'}"

  # The HTML report is for humans; the machine-readable JSON report uploaded
  # to Codecov is written separately by the test:coverage_gaps rake task.
  # When DEFER_COVERAGE is set (as CI and 'test:optimized' do), the merged
  # result is only complete once all parallel + system runs finish, so skip
  # report generation in the test processes and use the minimal formatter.
  formatter(
    if ENV['DEFER_COVERAGE']
      SimpleCov::Formatter::SimpleFormatter # Minimal overhead
    else
      SimpleCov::Formatter::HTMLFormatter
    end
  )

  group 'Validators', 'app/validators'
  skip '/config/'
  skip '/lib/tasks'
  skip '/test/'
  skip '/vendor/'

  # Exclude baseline development scripts (not run in production).
  #
  # CAREFUL: a regexp skip is matched against SourceFile#project_filename,
  # which is the path relative to the project root and has NO leading slash
  # ("lib/baseline_html_parser.rb"). A regexp anchored like %r{^/lib/...}
  # matches nothing at all, and a skip that matches nothing fails silently -
  # the files simply reappear in the report as untested code. (String skips
  # such as '/test/' above are immune: SimpleCov strips a leading slash from
  # those before matching. Regexps get no such normalization.)
  #
  # Anchor with \A and \z so this stays limited to top-level lib/, leaving
  # the real production code in app/lib/ measured.
  skip %r{\Alib/baseline_.*\.rb\z}
end
