# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Fuzz target for the full markdown processing pipeline.
# Exercises all three code paths in MarkdownProcessor.render:
#   1. PREFIXED_URL_REGEX fast path (prefixed bare URL)
#   2. MARKDOWN_UNNECESSARY fast path (plain text, no markdown needed)
#   3. CommonMarker HTML generation + URL-protocol sanitization
#
# Requires the commonmarker gem (ships a pre-built x86_64-linux native gem;
# see test/fuzz/build.sh for how OSS-Fuzz installs it).
#
# Run via OSS-Fuzz (see test/fuzz/) or locally with Ruzzy:
#   gem install commonmarker
#   LD_PRELOAD=$(ruby -e 'require "ruzzy"; print Ruzzy::ASAN_PATH') \
#     ruby script/fuzz_markdown_processor.rb [corpus_dir]

require 'ruzzy'
require 'cgi'

# Minimal stubs for ActiveSupport extensions used by the markdown processor
# so that Rails does not need to be loaded.
class String
  def html_safe
    self
  end

  def blank?
    strip.empty?
  end
end

# Load the markdown modules directly; Rails autoloading is unavailable here.
$LOAD_PATH.unshift(File.join(__dir__, '..', 'app', 'lib'))
require 'invoke_commonmarker'
require 'markdown_processor'

test_one_input =
  lambda do |data|
    input = data.dup.force_encoding('UTF-8')
    begin
      MarkdownProcessor.render(input)
    rescue StandardError
      # Seeking crashes and security bugs, not Ruby-level exceptions.
    end
    0
  end

Ruzzy.fuzz(test_one_input)
