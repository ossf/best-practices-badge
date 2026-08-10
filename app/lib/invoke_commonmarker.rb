# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Invoke the Commonmarker markdown processor with sanitization

module InvokeCommonmarker
  require 'commonmarker'

  # We once used Redcarpet to process markdown, but it became
  # unreliable as we began using it a lot.
  # So we switched to Commonmarker, a different markdown processor that
  # supports a somewhat similar but not identical set of options.
  #
  # Here are the old Redcarpet Markdown renderer configuration:
  # REDCARPET_MARKDOWN_RENDERER_OPTIONS = {
  #   filter_html: true, no_images: true,
  #   no_styles: true, safe_links_only: true,
  #   link_attributes: { rel: 'nofollow ugc' }
  # }.freeze
  # REDCARPET_MARKDOWN_PROCESSOR_OPTIONS = {
  #   no_intra_emphasis: true, autolink: true,
  #   space_after_headers: true, fenced_code_blocks: true
  # }.freeze
  #
  # Note in particular that adding rel='nofollow ugc' isn't directly
  # supported by Commonmarker, and that's important,
  # because if we don't add that, attackers will want to add garbage
  # to improve some site's SEO. So we must supplement Commonmarker
  # with a sanitizer to use it in our context.
  #

  # We do NOT use render.unsafe = true. We use the default (safe mode)
  # which blocks all raw HTML. This is the same behavior as Redcarpet had.
  # We then use fast regex operations to add security attributes to links
  # and strip disallowed URL protocols.
  #
  # When we first switched to Commonmarker we used unsafe: true and
  # a scrubber building on Rails::Html::PermitScrubber.
  # This provided a lot of *great* functionality, because then users
  # could use markdown *and* embed a lot of safe HTML.
  # However, this approach caused a *massive* number of Ruby objects to be
  # created (nodes to represent parts of the HTML), that then needed to
  # be walked with Ruby code. We optimized this, and if the site was
  # rarely visited, it'd be fine. However, even when we optimized
  # this approach, it caused a dramatic
  # spike in 95th percentile average response times (~100ms->~160ms)
  # and caused RSS memory use to go out-of-control. Even aggressive
  # compaction couldn't prevent the system's memory use from
  # growing, running out of memory, and crashing.
  # So we switched to forbidding HTML and using simple regexes when
  # we must handle full markdown.
  #
  COMMONMARKER_OPTIONS = {
    render: {
      escape: true # Escape raw HTML so users can see what they entered (safely)
    },
    extension: {
      autolink: true, # Autolink URLs to simplify references
      tagfilter: true, # Filters out potentially harmful tags like <style>
      strikethrough: true, # Often used alongside GitHub-flavored markdown
      table: true, # Tables can be useful in justification text
    }
  }.freeze

  # Regex to match allowed URL protocols and relative URLs.
  # This allows http:, https:, mailto:, relative paths (/, ./, ../),
  # and anchors (#).
  # This prevents anything else such as javascript:, data:,
  # and other dangerous protocols.
  ALLOWED_MARKDOWN_URL_PATTERN = %r{\A(?:https?:|mailto:|/|\.\.?/|#)}i

  # Invoke Commonmarker and sanitize the result
  #
  # @param content [String] The content to render as Markdown
  # @return [String] HTML-safe rendered and sanitized output
  #
  # rubocop:disable Metrics/MethodLength
  def self.invoke_and_sanitize(content)
    # Commonmarker releases the GVL here for thread-safe parallel execution
    # Using unsafe: false (default), so raw HTML is blocked.
    html = Commonmarker.to_html(content, options: COMMONMARKER_OPTIONS)

    # For <a href add the required rel="..." values and
    # strip hrefs with disallowed protocols. Commonmarker always generates
    # href as the *first* argument (if there is an href) and always uses
    # double quotes for the href parameter, and users can't use HTML directly,
    # so we only handle this case (there's no need for single-quote code
    # or for handling parameters before href).
    #
    # In the longer term we could consider instead using html-pipeline
    # <https://github.com/gjtorikian/html-pipeline> as discussed in
    # https://github.com/gjtorikian/commonmarker/issues/432
    # The gem html-pipeline supports tag selectors, so you don't have
    # to process every HTML node.
    # At one time I used Rails::Html::PermitScrubber with Commonmarker,
    # and tried to optimize it. However, that approach invokes Ruby on
    # every HTML node, and that is a killer for performance.
    # We *must* use html-pipeline, or something like it, as well as
    # various scrubbing measures, if we ever allow a subset of straight HTML.
    # This regex isn't adequate if users can create their own <a ...> entries.
    html.gsub!(/<a href="([^"]*?)"([^>]*)>/m) do
      url = ::Regexp.last_match(1)
      after = ::Regexp.last_match(2)

      if url.match?(ALLOWED_MARKDOWN_URL_PATTERN)
        # Valid URL - keep it and add security attributes
        # href comes before rel to match previous behavior
        "<a href=\"#{url}\" rel=\"nofollow ugc noopener noreferrer\"#{after}>"
      else
        # Strip href attribute - link becomes plain text
        '<a>'
      end
    end

    # Mark as html_safe since Commonmarker escapes HTML and we've validated URLs
    # rubocop:disable Rails/OutputSafety
    html.html_safe
    # rubocop:enable Rails/OutputSafety
  end
  # rubocop:enable Metrics/MethodLength
end
