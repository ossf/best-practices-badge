# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.

# Work out the environment the way RAILS ITSELF does, rather than by
# testing ENV['RAILS_ENV'] alone. Rails.env is
# ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development', so an UNSET
# RAILS_ENV means development, and unset is the normal case for "rake",
# "rails console" and "rails server".
#
# This file used to test ENV['RAILS_ENV'] == 'development' directly, so
# Bootsnap was skipped in exactly those cases: measured at 3.89s against
# 2.09s for "rake -T". About 1.8 seconds, lost every time anyone did the
# ordinary thing, on the machine of every developer.
rails_env = ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'

if rails_env == 'development'
  begin
    require 'bootsnap'
    Bootsnap.setup(
      # Path to your cache
      cache_dir:            'tmp/cache',
      # We are in development here by definition, per the check above.
      development_mode:     true,
      # Should we optimize the LOAD_PATH with a cache?
      load_path_cache:      true,
      # Sets `RubyVM::InstructionSequence.compile_option =
      #   { trace_instruction: false }`
      # Should compile Ruby code into ISeq cache?
      compile_cache_iseq:   true,
      # Should compile YAML into a cache?
      compile_cache_yaml:   true
    )
  rescue LoadError
    # bootsnap is in the development bundle group, so a bundle installed
    # without that group has no gem to require. Carry on: this is a
    # cache, not a dependency, and refusing to boot over a missing
    # accelerator would be worse than booting slowly.
    warn 'Note: bootsnap is not installed, so boot will be slower.'
  end
end
