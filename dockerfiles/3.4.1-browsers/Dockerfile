# "cimg" are newer CircleCI images, built on Ubuntu, supposed to be
# faster and more deterministic. For more on these images see:
# See https://hub.docker.com/r/cimg/ruby
# https://circleci.com/developer/images/image/cimg/ruby

# OpenSSF Scorecard wants us to pin our image to a deterministic
# docker image. A discussion about docker pinning is here:
# https://medium.com/@tariq.m.islam/container-deployments-a-lesson-in-deterministic-ops-a4a467b14a03
# You can get the hash value for a specific image by using "docker images"
# and querying about REPOSITORY:TAG, for example:
# docker pull cimg/ruby:3.4.1-browsers
# will return:
#3.4.1-browsers: Pulling from cimg/ruby
#Digest: sha256:REPLACE_WITH_ACTUAL_HASH_FROM_docker_pull_cimg_ruby_3.4.1-browsers
# For more about Docker pinning, see:
# https://docs.docker.com/engine/reference/commandline/pull/#pull-an-image-by-digest-immutable-identifier
# So instead of something like "FROM cimg/ruby:3.4.1-browsers", we indicate
# the sha256 hash, and note the "pin" value.

# $ docker pull cimg/ruby:3.4.1-browsers
# 3.4.1-browsers: Pulling from cimg/ruby
# Digest: sha256:REPLACE_WITH_ACTUAL_HASH_FROM_docker_pull_cimg_ruby_3.4.1-browsers
# Status: Downloaded newer image for cimg/ruby:3.4.1-browsers
# docker.io/cimg/ruby:3.4.1-browsers

# pin :3.4.1-browsers
FROM cimg/ruby@sha256:a0b57bca5e631081ac79c5b316a480f282da03e71b164e0ad40426766e0ebac7
# skip installing gem documentation
# We need "cmake" to build the C code required by some gems.
# We need "shared-mime-info" for gem mimemagic.
RUN sudo apt-get update && sudo apt-get install -y cmake shared-mime-info

# Install Bundler 2.7.x (compatible with Ruby 3.4+)
# This eliminates Gem::Platform constant redefinition warnings that occur
# when using Bundler 2.5.x with Ruby 3.4's RubyGems 3.7.2
# Why do this extra step?:
# - `gem install bundler` uses the Ruby/RubyGems that's already in the cimg/ruby:3.4.1-browsers image
# - `-v '~> 2.7.0'` installs latest Bundler 2.7.x (compatible with Ruby 3.4)
# - `--no-document` skips gem documentation to reduce image size
# - This runs as root (before `USER circleci`), so the bundler is system-wide
RUN gem install bundler -v '~> 2.7.0' --no-document

RUN mkdir -p /home/circleci/project && chown circleci:circleci /home/circleci/project

USER circleci

WORKDIR /home/circleci/project

# Ensure .dockerignore exists so we don't accidentally bake
# local assets into the image
COPY .dockerignore ./

COPY --chown=circleci:circleci . .

# Wipe any potential metadata and force a total recompile
RUN bundle exec rake assets:clobber
RUN RAILS_ENV=production bundle exec rake assets:precompile
