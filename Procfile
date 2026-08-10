# We deliberately declare only "web".  Background jobs run inside Puma,
# using solid_queue via "plugin :solid_queue" in config/puma.rb, which is
# enabled by setting SOLID_QUEUE_IN_PUMA=true.  So we do NOT need, and do
# not want, a separate "worker" dyno.
#
# Beware: if a process type isn't in this file, Heroku's Ruby buildpack
# still supplies a default command for it, and its default for "worker"
# is "bundle exec rake jobs:work" (a Delayed Job convention we don't use).
# We ran a worker dyno for a long time because of that.  It ran a
# do-nothing stub task, exited immediately, and Heroku kept restarting
# it, so we paid for a dyno to crash-loop while a permanently red line
# sat in "heroku ps" and taught us to ignore that display.  Both tiers
# are now scaled with "heroku ps:scale worker=0".  Don't scale one up
# again unless you also give it a real command here.
#
# If you ever *do* want jobs off the web dyno, so they stop competing
# with request handling for CPU and memory, add an explicit line such as
#   worker: bundle exec rake solid_queue:start
# and turn SOLID_QUEUE_IN_PUMA off.  solid_queue coordinates through the
# database, so it won't run a job twice, but there's no reason to have
# two configurations to keep in step unless we need the separation.

# Database migrations run here, as a release phase command, rather than
# from the CI deploy job.
#
# Source for everything in this comment:
#   https://devcenter.heroku.com/articles/release-phase
#
# Heroku runs this in a one-off dyno after a successful build and
# BEFORE any dyno boots on the new release: "If the release command
# exits with a non-zero exit status ... the release is not deployed to
# the app's dyno formation."
#
# That is safer than what we did before.  Previously CI pushed the slug
# and then ran the migration separately, so a failed migration left the
# new code already live against an unmigrated database.  Now a failed
# migration means the new release never goes live at all and the
# previous one keeps serving.
#
# Two behaviours to know.  Release phase also runs on config var
# changes and on rollbacks, so this command must stay idempotent;
# db:migrate is.  And it has a one hour cap that cannot be extended,
# after which the release status becomes "expired".
#
# CI does NOT learn about failures from "git push heroku": Heroku
# documents that a build can succeed while its release fails, and does
# not document the push's exit status for that case.  The same article
# says that "for real-time detection during CI/CD pipelines, you would
# need to use the Platform API rather than rely solely on the git push
# exit code", so the deploy job polls that API instead.  See
# .circleci/config.yml.
release: bundle exec rails db:migrate

web: ./ignore-termerr env BUNDLE_DISABLE_EXEC_LOAD=true bundle exec puma -C config/puma.rb
