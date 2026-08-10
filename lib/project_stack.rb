# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Which Heroku stack is this project on?
#
# ONE ANSWER, FROM ONE PLACE: the heroku/heroku tag in
# .circleci/config.yml. CI derives CNB_STACK_ID from inside that image
# and the deploy job sets the applications' stack to match, so reading
# the tag is reading the same decision rather than a second opinion,
# and it answers the same on a runner and a laptop, where no
# CNB_STACK_ID exists.
#
# A regexp rather than a YAML parse, because script/heroku_ruby_versions
# loads this where there is no bundle, and one pinned tag needs no more.
module ProjectStack
  CONFIG_PATH = '.circleci/config.yml'

  # "heroku/heroku:24-build", possibly with an @sha256 digest after it.
  IMAGE_TAG = %r{heroku/heroku:(\d+)-build}

  class Unknown < StandardError; end

  module_function

  # @param config_path [String] where the executor image is pinned
  # @return [String] e.g. "heroku-24"
  # @raise [Unknown] if the pin is missing or unreadable
  def name(config_path: CONFIG_PATH)
    unless File.exist?(config_path)
      raise Unknown, "No #{config_path} to read the stack from"
    end

    match = IMAGE_TAG.match(File.read(config_path))
    if match.nil?
      raise Unknown, "No heroku/heroku:NN-build image in #{config_path}"
    end

    "heroku-#{match[1]}"
  end
end
