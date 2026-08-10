# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Invoke the Redcarpet markdown processor with *MAXIMIZED* safety

# We've used redcarpet for years. It's capable, fast, and doesn't
# fragment memory. However, we've recently seen it crash every once in a while
# with this report, which may simply be because we're stressing it more:
# md->work_bufs[BUFFER_SPAN].size == 0
# This issue may be related, it has the error report:
# https://github.com/vmg/redcarpet/issues/570

# This failure is rare and we've been unable to replicate it
# at this time. We're open to switching. Commonmarker is really good, but
# when we tried to switch to it, its use led to uncontrolled memory growth
# we couldn't accept. A pure-Ruby solution can't work for us,
# we have to support too many requests.

# We've also occasionally seen this error report:
# NotImplementedError: method 'to_s' called on unexpected
# T_IMEMO object (0x00007fd5c82c83c8 flags=0x8703a)
# app/lib/invoke_redcarpet.rb:245:in 'Redcarpet::Markdown#render'
# The reference to T_IMEMO is surprising; that's a low-level detail that
# simply should never be visible to the test.
# Gemini suggested the following:
# Class variables in Ruby are shared across the inheritance hierarchy
# and persist for the lifetime of the process. In a test environment:
# C-Extension State: The Redcarpet::Markdown object holds a pointer to
# a C-struct representing your RENDERER.
# Memory Reuse: If a test modifies the global state or if the test runner
# (like RSpec or Minitest) interacts with the class in a way that causes
# the Ruby VM to move objects in memory (Compacting GC), a class variable
# pointing to a C-backed object can become "stale."
# The T_IMEMO Connection: The fact that you are seeing a T_IMEMO object
# means that the memory address where the Renderer used to live has been
# reclaimed by the Ruby VM for internal bookkeeping. Because the class
# variable didn't "release" that address, the processor.render call tries
# to execute C-code against an internal VM structure.

# Our earlier efforts to prevent this, by re-creating markdown
# renderers and processors, and using each pair only once.
# Originally I only re-created the markdown processor instance, since
# that's where the original error reports came from, namely
# `md->work_bufs[BUFFER_SPAN].size == 0`.
# The benchmark indicates that if a project section
# needs 50 markdown renders (an unlikely high number for a project),
# instantiating a processor each time adds 50*(0.104432-0.010429)/10000
# = 0.47 milliseconds (0.00047 seconds) in real time for showing a project.
# By itself that didn't eliminate crashes.
# I modified the benchmark to see the overhead of *also* re-creating
# the renderer for each markdown process. If again some project display
# *also* needs 50 markdown renders (an unlikely high number for a project),
# instantiating a markdown processor *and* renderer
# each time adds 50*(0.442712-0.012445)/10000
# = 2.15 milliseconds in real time for showing a project.
# Notice that I'm always using "real" time as the conservative answer.
# Our current "project shows" take around 22msec, so that is a ~10%
# increase in execution time of our most common request type.

# However, creating objects each time we want to process markdown meant
# we had to clean them up later, creating *huge* occasional latencies.
# We created them in batches and put them in a queue, to try to put them
# in a place where we could recover them. All of that extra mechanism
# created huge overhead in efforts to work around bugs in the library.
# We instead fixed the underlying library, sent our fixes upstream, and plan
# to use our forked version until upstream is fixed. As a result, we can
# use the markdown processor in the simple way as intended. Our fixes also
# raise exceptions (instead of crashing) if certain assertions fail; this
# lets us log the problem and recreate objects.

module InvokeRedcarpet
  require 'redcarpet'

  # Attributes attached to every generated link. All values are static
  # literals, so Ruby folds this into a compile-time constant.
  LINK_ATTRS = { rel: 'nofollow ugc noopener noreferrer' }.freeze

  # Markdown renderer configuration for Redcarpet.
  #
  # Keep the first key/value pair on the assignment line below. Because this
  # hash has a non-static value (LINK_ATTRS), Ruby builds it at run time, and
  # `Coverage.line_stub` - which SimpleCov uses to synthesize coverage for a
  # file that a given test process never loaded - then attributes the
  # statement to a *different* line than the running interpreter does.
  # Merging those two disagreeing results invents a line that no test can
  # ever cover, failing the "untested production code" check in
  # `rake test:coverage_gaps`. Moving the `{` back onto its own line brings
  # the phantom straight back - which is exactly what the cop disabled here
  # would do, so it must stay disabled.
  # rubocop:disable Layout/FirstHashElementLineBreak
  REDCARPET_MARKDOWN_RENDERER_OPTS = { filter_html: true, no_images: true,
                                       no_styles: true,
                                       safe_links_only: true,
                                       link_attributes: LINK_ATTRS }.freeze
  # rubocop:enable Layout/FirstHashElementLineBreak

  REDCARPET_MARKDOWN_PROCESSOR_OPTS = {
    no_intra_emphasis: true, autolink: true,
    space_after_headers: true, fenced_code_blocks: true
  }.freeze

  # Complain because the processor does not have the expected type
  #
  # @raise [TypeError]
  # @return [void]
  def self.processor_bad_type(p)
    # Unexpected type - log error and reset
    actual_type = p.class
    Rails.logger.error(
      "Redcarpet processor has unexpected type: #{actual_type} " \
      '(expected Redcarpet::Markdown)'
    )
    raise TypeError, "Redcarpet processor has wrong type: #{actual_type}"
  end

  # Log a render error with diagnostic information
  #
  # @param exception [Exception] The exception that occurred
  # @param current_content [String] The content being rendered when error occurred
  # @param previous_content [String, nil] The previously rendered content
  # @return [void]
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def self.log_render_error(exception, current_content)
    Rails.logger.error(
      "Redcarpet render failed: #{exception.class} - #{exception.message}"
    )
    Rails.logger.error(
      "Redcarpet current content (#{current_content.to_s.length} chars): " \
      "#{current_content.to_s[0..1000].inspect}"
    )
    return unless exception.backtrace

    Rails.logger.error("Redcarpet backtrace: #{exception.backtrace.first(10).join("\n  ")}")
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  # Create a new markdown processor for our current thread, along with
  # its associated render object, and store it
  # as being associated with our current thread.
  # They can't be shared between threads at the same time, so we'll just
  # create one for each thread.
  def self.new_markdown_processor
    renderer = Redcarpet::Render::HTML.new(REDCARPET_MARKDOWN_RENDERER_OPTS)
    processor = Redcarpet::Markdown.new(renderer,
                                        REDCARPET_MARKDOWN_PROCESSOR_OPTS)
    # Technically we don't need to record the renderer in Thread.current,
    # since it's referenced by the processor, but doing this *ensures* that
    # Ruby can see that the renderer is being used (and must not be reclaimed).
    Thread.current[:markdown_renderer] = renderer
    # This is the setting that matters - from now on, this thread will use
    # this markdown processor.
    Thread.current[:markdown_processor] = processor
    processor
  end

  # Invoke Redcarpet to render markdown content
  # with comprehensive error handling.
  #
  # This method wraps the Redcarpet call in defensive measures.
  # On error, it logs diagnostic info and either returns HTML-escaped content
  # or re-raises the exception (for testing).
  #
  # @param content [String] The content to render as Markdown
  # @param raise_on_error [Boolean] If true, re-raise exceptions instead of
  #   returning escaped content (for testing)
  # @param force_exception [Exception, nil] For testing: inject an exception
  # @return [ActiveSupport::SafeBuffer] HTML-safe rendered output
  #
  # rubocop:disable Rails/OutputSafety, Metrics/MethodLength
  # rubocop:disable Metrics/AbcSize
  def self.invoke_and_sanitize(
    content,
    raise_on_error: false,
    force_exception: nil,
    force_bad_type: false
  )
    # Get this thread's markdown processor, creating it if necessary
    processor = Thread.current[:markdown_processor] || new_markdown_processor

    # For testing: inject a bad type to test type checking
    processor = [] if force_bad_type

    # Check processor type (catches some Rails class reloading issues)
    # Warning: Rails class reloading can invalidate cached instances,
    # causing "wrong argument type"
    # errors even though is_a? checks pass against stale class definitions
    processor_bad_type(processor) unless processor.is_a?(Redcarpet::Markdown)

    # Defensive measure: ensure content is a string
    content_str = content.to_s

    # For testing: inject an exception to test exception handling
    raise force_exception if force_exception

    # Try to render the markdown
    result = processor.render(content_str)

    # The markdown processor, as configured, will generate safe results.
    # Without this operation html links, italics, etc. won't work.
    result.html_safe
  rescue StandardError => e # This also captures RuntimeError
    # Log comprehensive diagnostic information
    log_render_error(e, content)

    # Force recreation of the renderer and markdown processor objects, since
    # something has gone wrong with the current pair.
    Thread.current[:markdown_processor] = nil
    Thread.current[:markdown_renderer] = nil

    # Re-raise (for testing)
    raise if raise_on_error

    # Return HTML-escaped content as fallback
    # Not perfect, but provides safe output to caller
    ERB::Util.html_escape(content.to_s).html_safe
  end
  # rubocop:enable Rails/OutputSafety, Metrics/MethodLength
  # rubocop:enable Metrics/AbcSize
end
