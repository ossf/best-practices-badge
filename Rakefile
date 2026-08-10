# frozen_string_literal: true

# This Rakefile loads this project's own tasks, WITHOUT necessarily
# loading the Rails environment. It then boots a Rails environment only
# if one of the tasks you asked for (possibly indirectly) needs it.
#
# This file *used* to require config/application unconditionally, so
# every single rake invocation paid to start 'rails/all' plus Bundler.require
# of every gem in the Gemfile (including the test-only ones).
# Starting up that environment takes about six seconds, and
# it meant "rake deploy_production" - five git commands -
# could not run without a complete development environment.
#
# Now, a task needs Rails unless *every* task reachable from it is
# (1) one of ours and (2) marked ":no_rails".
# Anything unfamiliar means yes, so tasks defined by Rails and by gems
# (db:migrate, solid_queue:start, translation:sync) keep working exactly
# as before (we have never heard of the name, so we boot Rails).
#
# See lib/tasks/default.rake for what's required for each rake task.
#
# The two ways this can be wrong are very unequal, which is the point.
# Booting when we needn't costs six seconds. Skipping when we should not
# is only possible if somebody marked a task ":no_rails" that really uses
# Rails, and that fails loudly with "uninitialized constant Rails" rather
# than doing something quietly wrong. The audit below exists to keep even
# that from happening, and it runs on every invocation.

# Set up the bundle BEFORE anything else, including our own task files.
# They require gems of their own, eslintrb among them, and a gem
# activated by plain RubyGems takes the newest installed version rather
# than the one Gemfile.lock names. Bundler then refuses when the
# application finally loads:
#
#   Gem::LoadError: You have already activated multi_json 1.21.0, but
#   your Gemfile requires multi_json 1.20.1
#
# config/application used to do this for us, by way of config/boot, back
# when it was required unconditionally at the top of this file. Now that
# it is not, this has to be here, or plain "rake" outside "bundle exec"
# stops working. It is cheap: bundler/setup resolves the lock file and
# fixes the load path, and loads no Rails.
require File.expand_path('config/boot', __dir__)

require 'rake'

# The marker itself: an empty task, so that ":no_rails" is a real
# prerequisite Rake can resolve rather than a comment we hope someone
# reads. Declared before our files load, so they can depend on it.
desc 'Marker: the task depending on this needs no Rails application'
task :no_rails

# Some of our code must run only once Rails and its gems have defined
# THEIR tasks, because it enhances them: see "test:run" and
# "translation:sync" in lib/tasks/default.rake. That code cannot run when
# we skip the boot, and it must not run before load_tasks when we do not.
# Registering it here is how it gets to run at the one moment it can.
def after_rails_tasks(&block)
  @after_rails_tasks ||= []
  @after_rails_tasks << block
end

def run_after_rails_tasks
  (@after_rails_tasks || []).each(&:call)
end

# Does this name, or anything it depends on, need the application?
#
# Ask Rake to resolve the name rather than checking a list of our own.
# Rake::Task[] also synthesizes what it legitimately can: a file task for
# a file that exists, such as a Gemfile.lock prerequisite, and a rule
# match for a file we know how to build, such as README.html from
# README.md. Anything it cannot resolve belongs to Rails or to a gem,
# and those exist only after the boot, so the answer there is yes.
def rake_needs_rails?(name, seen = {})
  return true  if name == 'environment'
  return false if name == 'no_rails'
  return false if seen[name]

  seen[name] = true
  task =
    begin
      Rake::Task[name]
    rescue RuntimeError
      nil
    end
  return true if task.nil?

  task.prerequisites.any? { |prereq| rake_needs_rails?(prereq.to_s, seen) }
end

# Every BODIED task of ours must answer the question: ":environment" or
# ":no_rails". Silence is not an answer, it is an omission, and an
# omission is invisible until the day it is wrong.
#
# Two exemptions, both forced rather than chosen. A file task cannot
# carry the marker: Rake::Task#timestamp returns Time.now, so a plain
# task as a file task's prerequisite makes it out of date on every run,
# and "rake license_okay" would rescan every gem for ever. A bodiless
# task has nothing to touch Rails with: it is a pure prerequisite list,
# the walk above already decides it, and marking one would be a claim
# about its closure that could quietly stop being true.
def rake_task_body(task)
  file, line = task.actions.first&.source_location
  return '' unless file && line && File.exist?(file)

  @rake_source ||= {}
  from = (@rake_source[file] ||= File.readlines(file))[(line - 1)..]
  rake_body_lines(from).grep_v(/\A\s*#/).join
end

# From the "task ... do" line to the "end" that closes it, by
# indentation. Comments are dropped by the caller: they do not execute,
# and one of them says "without bringing in the entire Rails
# environment", which would otherwise be read as a task using Rails.
def rake_body_lines(lines)
  closing = /\A\s{#{lines.first[/\A\s*/].size}}end\b/
  lines.each_with_index
       .take_while { |text, i| i.zero? || text !~ closing }
       .map(&:first)
end

# Names that mean "this body uses the application": Rails itself, and
# every model, so that "User.where(...)" counts.
def rake_rails_regexp
  models =
    Dir['app/models/**/*.rb'].map do |f|
      File.basename(f, '.rb').split('_').map(&:capitalize).join
    end
  Regexp.union(/\bRails\b/, /\bActiveRecord\b/, /\bApplicationRecord\b/,
               /\bI18n\b/, *models.map { |m| /\b#{m}\b/ })
end

# [tasks that answered nothing, tasks whose answer contradicts the body]
def rake_marker_problems(names)
  rails_re = rake_rails_regexp
  names.each_with_object([[], []]) do |name, (unanswered, wrong)|
    task = Rake::Task[name]
    next if task.actions.empty? || task.is_a?(Rake::FileTask)

    prereqs = task.prerequisites.map(&:to_s)
    next if prereqs.include?('environment')

    if !prereqs.include?('no_rails')
      unanswered << name
    elsif rake_task_body(task).match?(rails_re)
      wrong << name
    end
  end
end

def audit_rake_markers!(names)
  unanswered, wrong = rake_marker_problems(names)
  return if unanswered.empty? && wrong.empty?

  message = ['Every task with a body must say whether it needs Rails.']
  unless unanswered.empty?
    message << "Says neither, add ': :environment' or ': :no_rails' to: " \
               "#{unanswered.sort.join(', ')}"
  end
  unless wrong.empty?
    message << "Claims ':no_rails' but the body uses Rails: " \
               "#{wrong.sort.join(', ')}"
  end
  raise message.join("\n  ")
end

# Load our own task files. They are plain Ruby and cost milliseconds; it
# is Rails, not Rake, that is expensive. Sorted so the order does not
# depend on the filesystem.
#
# Guarded because three tests do "load 'Rakefile'", and Rake APPENDS
# actions when a task is defined twice rather than replacing them, so a
# second load would give every task body two copies. The "defined?" test
# also keeps this constant from warning about being reinitialized.
unless defined?(OUR_RAKE_TASKS_LOADED)
  before = Rake::Task.tasks.map(&:name)
  Dir.glob(File.expand_path('lib/tasks/*.rake', __dir__)).each { |file| load file }
  # Audit here, not later, and in this same Rake application. Rake swaps
  # Rake.application in and out (Rake.with_application), so a list of task
  # names captured now is meaningless against a different application
  # later: looking one up raises "Don't know how to build task". Running
  # the check here also means it runs on EVERY invocation, including the
  # fast ones that never boot Rails.
  audit_rake_markers!(Rake::Task.tasks.map(&:name) - before)
  OUR_RAKE_TASKS_LOADED = true
end

# "rake foo[bar]" names the task "foo", so strip any argument list. An
# empty list means we were loaded by something other than the rake
# command line, such as a test, and those want the whole application.
wanted = Rake.application.top_level_tasks.map { |task| task.split('[').first }
if wanted.empty? || wanted.any? { |task| rake_needs_rails?(task) }
  require File.expand_path('config/application', __dir__)

  # 'environment' is the condition that works. This guard used to test
  # for the 'stats' task and for STATS_DIRECTORIES as well, neither of
  # which exists on Rails 8.1, so two thirds of it could never fire.
  Rails.application.load_tasks unless Rake::Task.task_defined?('environment')

  run_after_rails_tasks
end
