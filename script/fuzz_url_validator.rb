# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Fuzz target for URL validation.
# Loads the real UrlValidator from app/validators/url_validator.rb via
# ActiveModel so any changes to the source are automatically exercised.
#
# Run via OSS-Fuzz (see test/fuzz/) or locally with Ruzzy:
#   gem install activemodel
#   export ASAN_OPTIONS="allocator_may_return_null=1:detect_leaks=0:use_sigaltstack=0"
#   LD_PRELOAD=$(ruby -e 'require "ruzzy"; print Ruzzy::ASAN_PATH') \
#     ruby script/fuzz_url_validator.rb [corpus_dir]

require 'ruzzy'
require 'active_model'

$LOAD_PATH.unshift(File.join(__dir__, '..', 'app', 'validators'))
require 'url_validator'

VALIDATOR = UrlValidator.new(attributes: [:repo_url])

test_one_input =
  lambda do |data|
    input = data.dup.force_encoding('UTF-8')
    begin
      VALIDATOR.url_acceptable?(input)
    rescue StandardError
      # Seeking crashes and memory-safety bugs, not Ruby exceptions.
    end
    0
  end

Ruzzy.fuzz(test_one_input)
