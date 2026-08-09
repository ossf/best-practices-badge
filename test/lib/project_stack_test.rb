# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'
require 'tmpdir'

# No require_relative: lib/ is an autoload path, and requiring it here
# would move this file's load-time lines out of the test worker's
# coverage result. See test/lib/heroku_ruby_availability_test.rb.

class ProjectStackTest < ActiveSupport::TestCase
  def with_config(text)
    Dir.mktmpdir('project_stack') do |dir|
      path = File.join(dir, 'config.yml')
      File.write(path, text)
      yield path
    end
  end

  test 'reads the stack from the executor image pin, or says why not' do
    {
      "- image: heroku/heroku:24-build@sha256:a6e743f5\n" => 'heroku-24',
      "- image: heroku/heroku:26-build\n" => 'heroku-26'
    }.each do |config, expected|
      with_config(config) do |path|
        assert_equal expected, ProjectStack.name(config_path: path)
      end
    end

    with_config("- image: cimg/ruby:3.4.1\n") do |path|
      error =
        assert_raises(ProjectStack::Unknown) do
          ProjectStack.name(config_path: path)
        end
      assert_match(%r{No heroku/heroku}, error.message)
    end

    error =
      assert_raises(ProjectStack::Unknown) do
        ProjectStack.name(config_path: '/nonexistent/config.yml')
      end
    assert_match(/No .*config\.yml/, error.message)
  end

  # The real file must keep answering, or the probe and the guard both
  # lose their footing the day someone reformats it.
  test 'the real .circleci/config.yml still answers' do
    assert_match(/\Aheroku-\d+\z/, ProjectStack.name)
  end
end
