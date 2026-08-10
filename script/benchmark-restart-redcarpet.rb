#!/usr/bin/env ruby

# frozen_string_literal: true

# Benchmark the performance overhead of recreating a Redcarpet markdown
# processor on every request, instead of reusing it.

require 'benchmark'

require_relative '../config/environment'

puts 'Benchmarking performance overhead of recreating Redcarpet markdown'
puts 'processor on every request, instead of reusing it.'

# The options we use, so we're doing a fair analysis.
REDCARPET_MARKDOWN_RENDERER_OPTIONS = {
  filter_html: true, no_images: true,
    no_styles: true, safe_links_only: true,
    link_attributes: { rel: 'nofollow ugc noopener noreferrer' }
}.freeze

REDCARPET_MARKDOWN_PROCESSOR_OPTIONS = {
  no_intra_emphasis: true, autolink: true,
  space_after_headers: true, fenced_code_blocks: true
}.freeze

# Quick test to ensure it works, and warm up things
text = "# Hello World\nThis is a **test**."
# The warning we see is processing; creating the renderer is a one-time
# event that doesn't care about inputs
renderer = Redcarpet::Render::HTML.new(REDCARPET_MARKDOWN_RENDERER_OPTIONS)
markdown = Redcarpet::Markdown.new(renderer, REDCARPET_MARKDOWN_PROCESSOR_OPTIONS)

puts "First markdown = #{markdown}\n"

n = 10_000
Benchmark.bm do |x|
  x.report('Reused: ') { n.times { markdown.render(text) } }
  # Re-create the markdown processor (but not the renderer) on each request
  x.report('New Instance: ') do
    n.times do
      renderer = Redcarpet::Render::HTML.new(REDCARPET_MARKDOWN_RENDERER_OPTIONS)
      processor = Redcarpet::Markdown.new(renderer, REDCARPET_MARKDOWN_PROCESSOR_OPTIONS)
      processor.render(text)
    end
  end
end
