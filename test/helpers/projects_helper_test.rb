# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# rubocop:disable Metrics/ClassLength
class ProjectsHelperTest < ActionView::TestCase
  include ProjectsHelper

  test 'markdown - simple' do
    input = 'hi'
    valid_result = "<p>hi</p>\n"
    assert_equal valid_result, markdown(input)
    assert_equal valid_result, MarkdownProcessor.render(input, true)
    assert_equal valid_result, MarkdownProcessor.render(input, false)
  end

  test 'markdown - emphasis' do
    input = '*hi*'
    valid_result = "<p><em>hi</em></p>\n"
    assert_equal valid_result, markdown(input)
    assert_equal valid_result, MarkdownProcessor.render(input, true)
    assert_equal valid_result, MarkdownProcessor.render(input, false)
  end

  test 'markdown - Embedded HTML i filtered out or escaped' do
    # It's okay to filter out or escape HTML.
    input = '<i>hi</i>'
    valid_results = ["<p>hi</p>\n", "<p>&lt;i&gt;hi&lt;/i&gt;</p>\n"]
    assert_includes valid_results, markdown(input)
    assert_includes valid_results, MarkdownProcessor.render(input, true)
    assert_includes valid_results, MarkdownProcessor.render(input, false)
  end

  test 'markdown - bare URL' do
    assert_equal(
      '<p><a href="http://www.dwheeler.com" ' \
      'rel="nofollow ugc noopener noreferrer">' \
      "http://www.dwheeler.com</a></p>\n",
      markdown('http://www.dwheeler.com')
    )
  end

  test 'markdown - angles around URL' do
    assert_equal(
      '<p><a href="http://www.dwheeler.com" ' \
      'rel="nofollow ugc noopener noreferrer">' \
      "http://www.dwheeler.com</a></p>\n",
      markdown('<http://www.dwheeler.com>')
    )
  end

  test 'markdown - hyperlinks are generated with nofollow' do
    input = '[Hello](http://www.dwheeler.com)'
    valid_result = '<p><a href="http://www.dwheeler.com" ' \
                   'rel="nofollow ugc noopener noreferrer">' \
                   "Hello</a></p>\n"
    assert_equal valid_result, markdown(input)
    assert_equal valid_result, MarkdownProcessor.render(input, true)
    assert_equal valid_result, MarkdownProcessor.render(input, false)
  end

  test 'markdown - raw HTML a stripped out (enforcing nofollow)' do
    # Ensure users cannot
    # bypass nofollow by using raw HTML. Use markdown syntax instead.
    # Negative test (for security) - verifies raw HTML is escaped
    input = '<a href="https://www.dwheeler.com">Junk</a>'
    valid_results = [
      "<p>Junk</p>\n",
      '<p>&lt;a href=&quot;https://www.dwheeler.com' \
      "&quot;&gt;Junk&lt;/a&gt;</p>\n"
    ]
    assert_includes valid_results, markdown(input)
    assert_includes valid_results, MarkdownProcessor.render(input, true)
    assert_includes valid_results, MarkdownProcessor.render(input, false)
  end

  test 'markdown - no script HTML' do
    # Allowing <script> would be a big security vulnerability.
    # We need to either strip it out or escape it (both are fine).
    # Negative test (security)
    input = '<script src="hi"></script>Hello'
    valid_results = ["<p>Hello</p>\n", "&lt;script src=&quot;hi&quot;&gt;&lt;/script&gt;Hello\n"]
    assert_includes valid_results, markdown(input)
    assert_includes valid_results, MarkdownProcessor.render(input, true)
    assert_includes valid_results, MarkdownProcessor.render(input, false)
  end

  test 'markdown - Embedded onclick rejected' do
    # Raw HTML is removed or escaped, including tags with onclick.
    # This prevents XSS attacks via event handlers.
    # Negative test (security)
    input = '<i onclick="alert();">hi</i>'
    valid_results = ["<p>hi</p>\n", "<p>&lt;i onclick=&quot;alert();&quot;&gt;hi&lt;/i&gt;</p>\n"]
    assert_includes valid_results, markdown(input)
    assert_includes valid_results, MarkdownProcessor.render(input, true)
    assert_includes valid_results, MarkdownProcessor.render(input, false)
  end

  test 'markdown - _target not included' do
    # Raw HTML is escaped (escape: true), so target="..." cannot be injected.
    # This protects against tabnabbing attacks. See:
    # "Target="_blank" - the most underestimated vulnerability ever"
    # by Alexander "Alex" Yumashev, May 4 2016
    # https://www.jitbit.com/alexblog/
    # 256-targetblank---the-most-underestimated-vulnerability-ever/
    # Negative test (security)
    input = '<a href="https://www.dwheeler.com" target="_blank">Hello</a>'
    valid_results = [
      "<p>Hello</p>\n",
      "<p>&lt;a href=&quot;https://www.dwheeler.com&quot; target=&quot;_blank&quot;&gt;Hello&lt;/a&gt;</p>\n"
    ]
    assert_includes valid_results, markdown(input)
    assert_includes valid_results, MarkdownProcessor.render(input, true)
    assert_includes valid_results, MarkdownProcessor.render(input, false)
  end

  test 'markdown - javascript: URL scheme rejected' do
    # javascript: URLs are a major XSS attack vector. We only allow
    # http(s), mailto, relative URLs, and anchors.
    # Negative test (security)
    input = '[Click me](javascript:alert("XSS"))'
    valid_results = [
      "<p>Click me</p>\n", "<p><a >Click me</a></p>\n",
      "<p><a>Click me</a></p>\n",
      # This is safe because [..] has no meaning in raw HTML:
      "<p>[Click me](javascript:alert(&quot;XSS&quot;))</p>\n"
    ]
    assert_includes valid_results, markdown(input)
    assert_includes valid_results, MarkdownProcessor.render(input, true)
    assert_includes valid_results, MarkdownProcessor.render(input, false)
  end

  test 'markdown - javascript: URL scheme in raw HTML rejected' do
    # Raw HTML is escaped (escape: true), so javascript: URLs are visible
    # but not executable. This is safe and shows users what they entered.
    # Negative test (security)
    input = '<a href="javascript:alert(\'XSS\')">Click</a>'
    valid_results = [
      "<p>Click</p>\n",
      # This is safe, because [..](...) has no meaning in raw HTML:
      "<p>[Click me](javascript:alert(&quot;XSS&quot;))</p>\n",
      # This is safe, &lt; disables any interpretation by HTML:
      "<p>&lt;a href=&quot;javascript:alert('XSS')&quot;&gt;Click&lt;/a&gt;</p>\n"
    ]
    assert_includes valid_results, markdown(input)
    assert_includes valid_results, MarkdownProcessor.render(input, true)
    assert_includes valid_results, MarkdownProcessor.render(input, false)
  end

  test 'markdown - invalid URI has href stripped' do
    # Raw HTML is escaped (escape: true), so malformed URIs are visible
    # but not executable. Users can see the malformed URL.
    # Negative test (security)
    # Either the <a isn't allowed, or it is normally
    # but the link isn't allowed. What we do *not* want is '<a href="ht!tp://'
    input = '<a href="ht!tp://bad[url]">Link</a>'
    valid_results = [
      "<p>Link</p>\n",
      "<p>&lt;a href=&quot;ht!tp://bad[url]&quot;&gt;Link&lt;/a&gt;</p>\n"
    ]
    assert_includes valid_results, markdown(input)
    assert_includes valid_results, MarkdownProcessor.render(input, true)
    assert_includes valid_results, MarkdownProcessor.render(input, false)
  end

  test 'markdown - imbalanced HTML tags are handled' do
    # Imbalanced HTML tags are handled (removed, escaped, or balanced)
    # This prevents layout breakage and shows users what they entered.
    # Negative test (security)
    input = '<i>hello'
    valid_results = ["<p>hello</p>\n", "<p>&lt;i&gt;hello</p>\n", "<p><i>hello</i></p>\n"]
    assert_includes valid_results, markdown(input)
    assert_includes valid_results, MarkdownProcessor.render(input, true)
    assert_includes valid_results, MarkdownProcessor.render(input, false)

    # Orphaned closing tags are also escaped
    input = 'hello</i>'
    valid_results = ["<p>hello</p>\n", "<p>hello&lt;/i&gt;</p>\n"]
    assert_includes valid_results, markdown(input)
    assert_includes valid_results, MarkdownProcessor.render(input, true)
    assert_includes valid_results, MarkdownProcessor.render(input, false)

    # Multiple tags are escaped
    input = '<i>hello <strong>world'
    valid_results = [
      "<p>hello world</p>\n", "<p>&lt;i&gt;hello &lt;strong&gt;world</p>\n",
      "<p><i>hello <strong>world</strong></i>\n"
    ]
    assert_includes valid_results, markdown(input)
    assert_includes valid_results, MarkdownProcessor.render(input, true)
    assert_includes valid_results, MarkdownProcessor.render(input, false)
  end

  test 'markdown - trivial text' do
    # Test to make sure our optimization for simple text doesn't cause
    # obvious weird problems.
    assert_equal "<p>Simple text.</p>\n", markdown('Simple text.')
  end

  test 'markdown - nil' do
    assert_equal '', markdown(nil)
  end

  test 'Commonmarker security configuration' do
    # This test documents our security approach: raw HTML is escaped
    # (escape: true), and only markdown-generated HTML is allowed to execute.
    # We use regex to validate URLs and inject security attributes.

    # Verify ALLOWED_MARKDOWN_URL_PATTERN exists and permits safe protocols
    pattern = InvokeCommonmarker::ALLOWED_MARKDOWN_URL_PATTERN
    assert pattern.match?('http://example.com')
    assert pattern.match?('https://example.com')
    assert pattern.match?('mailto:test@example.com')
    assert pattern.match?('/path/to/page')
    assert pattern.match?('../relative')
    assert pattern.match?('./relative')
    assert pattern.match?('#anchor')

    # Verify dangerous protocols are blocked
    assert_not pattern.match?('javascript:alert()')
    assert_not pattern.match?('data:text/html')
    assert_not pattern.match?('vbscript:')
  end

  test 'Ensure tiered_percent_as_string works' do
    I18n.with_locale(:de) do
      assert_equal 'In Arbeit, 74% Fortschritt für Passing',
                   tiered_percent_as_string(74)
    end
    I18n.with_locale(:en) do
      assert_nil tiered_percent_as_string(nil)
      assert_equal 'In Progress, 74% completed for passing',
                   tiered_percent_as_string(74)
      assert_equal 'Passing, 23% completed for silver',
                   tiered_percent_as_string(123)
      assert_equal 'Silver, 52% completed for gold',
                   tiered_percent_as_string(252)
      assert_equal 'Gold', tiered_percent_as_string(300)
    end
    # I18n.with_locale(:fr) do
    #    assert_equal 'WRONG', tiered_percent_as_string(74)
    # end
  end

  test 'Empty repo list works' do
    empty_result = fork_and_original([])
    assert_equal [[], []], empty_result
  end

  test 'baseline_id_to_display converts internal to display form' do
    assert_equal 'OSPS-AC-03.01', baseline_id_to_display('osps_ac_03_01')
    assert_equal 'OSPS-BR-01.02', baseline_id_to_display(:osps_br_01_02)
    assert_equal 'OSPS-QA-05.02', baseline_id_to_display('osps_qa_05_02')
  end

  test 'baseline_id_to_display returns original for non-baseline IDs' do
    assert_equal 'version_semver', baseline_id_to_display('version_semver')
    assert_equal 'crypto_password_storage',
                 baseline_id_to_display('crypto_password_storage')
  end

  test 'baseline_id_to_display converts field names with suffixes' do
    assert_equal 'OSPS-AC-03.01_status',
                 baseline_id_to_display('osps_ac_03_01_status')
    assert_equal 'OSPS-BR-01.02_justification',
                 baseline_id_to_display('osps_br_01_02_justification')
    assert_equal 'OSPS-QA-05.02_status',
                 baseline_id_to_display('osps_qa_05_02_status')
  end

  test 'baseline_id_to_display returns original for invalid suffixes' do
    # Should not convert field names with unrecognized suffixes
    assert_equal 'osps_ac_03_01_invalid',
                 baseline_id_to_display('osps_ac_03_01_invalid')
  end

  test 'BASELINE_FIELD_DISPLAY_NAME_MAP is frozen and contains mappings' do
    # Verify the constant is frozen for thread safety
    assert ProjectsHelper::BASELINE_FIELD_DISPLAY_NAME_MAP.frozen?
    # Verify it contains at least some baseline field mappings
    assert ProjectsHelper::BASELINE_FIELD_DISPLAY_NAME_MAP.any?
    # Verify sample mappings are correct
    if ProjectsHelper::BASELINE_FIELD_DISPLAY_NAME_MAP.key?('osps_ac_01_01_status')
      assert_equal 'OSPS-AC-01.01_status',
                   ProjectsHelper::BASELINE_FIELD_DISPLAY_NAME_MAP['osps_ac_01_01_status']
    end
  end

  # We've commented out this mapping, so there's nothing to test.
  # test 'BASELINE_DISPLAY_TO_INTERNAL_NAME_MAP is frozen and contains reverse mappings' do
  #   # Verify the constant is frozen for thread safety
  #   assert ProjectsHelper::BASELINE_DISPLAY_TO_INTERNAL_NAME_MAP.frozen?
  #   # Verify it contains at least some baseline field mappings
  #   assert ProjectsHelper::BASELINE_DISPLAY_TO_INTERNAL_NAME_MAP.any?
  #   # Verify sample reverse mappings are correct
  #   if ProjectsHelper::BASELINE_DISPLAY_TO_INTERNAL_NAME_MAP.key?('OSPS-AC-01.01_status')
  #     assert_equal 'osps_ac_01_01_status',
  #                  ProjectsHelper::BASELINE_DISPLAY_TO_INTERNAL_NAME_MAP['OSPS-AC-01.01_status']
  #   end
  # end

  test 'baseline_id_to_display uses precomputed map' do
    # Verify it returns correct values for baseline IDs
    assert_equal 'OSPS-AC-03.01', baseline_id_to_display('osps_ac_03_01')
    assert_equal 'OSPS-BR-01.02_status',
                 baseline_id_to_display('osps_br_01_02_status')
    # Verify it returns original for non-baseline IDs
    assert_equal 'name', baseline_id_to_display('name')
  end

  test 'compute_baseline_display_name handles 4-part baseline IDs' do
    # Test line 237: parts.size == 4 case
    result = ProjectsHelper.send(:compute_baseline_display_name,
                                 'osps_ac_03_01')
    assert_equal 'OSPS-AC-03.01', result
  end

  test 'compute_baseline_display_name returns original for malformed IDs' do
    # Test line 242: else case for unrecognized format
    # osps_ prefix but wrong number of parts
    result = ProjectsHelper.send(:compute_baseline_display_name,
                                 'osps_invalid')
    assert_equal 'osps_invalid', result
  end

  test 'compute_baseline_internal_name returns original for non-baseline' do
    # Test line 256: return early if not OSPS- format
    result = ProjectsHelper.send(:compute_baseline_internal_name,
                                 'version_semver')
    assert_equal 'version_semver', result
  end

  test 'compute_baseline_internal_name converts baseline display to internal' do
    # Test line 260: convert OSPS- format to internal
    result = ProjectsHelper.send(:compute_baseline_internal_name,
                                 'OSPS-AC-03.01')
    assert_equal 'osps_ac_03_01', result
  end

  # If we uncomment baseline_id_to_internal, here are tests for it.
  # test 'baseline_id_to_internal uses precomputed map' do
  #   # Verify it returns correct values for baseline display names
  #   assert_equal 'osps_ac_03_01', baseline_id_to_internal('OSPS-AC-03.01')
  #   assert_equal 'osps_br_01_02_status',
  #                baseline_id_to_internal('OSPS-BR-01.02_status')
  #   # Verify it returns original for non-baseline IDs
  #   assert_equal 'name', baseline_id_to_internal('name')
  # end

  # test 'baseline_id_to_internal converts display to internal form' do
  #   assert_equal 'osps_ac_03_01', baseline_id_to_internal('OSPS-AC-03.01')
  #   assert_equal 'osps_br_01_02', baseline_id_to_internal('OSPS-BR-01.02')
  #   assert_equal 'osps_qa_05_02', baseline_id_to_internal('osps-qa-05.02')
  # end

  # test 'baseline_id_to_internal returns original for non-baseline IDs' do
  #   assert_equal 'version_semver', baseline_id_to_internal('version_semver')
  #   assert_equal 'crypto_password_storage',
  #                baseline_id_to_internal('crypto_password_storage')
  # end

  test 'status_to_string converts integer 0 to ?' do
    assert_equal '?', status_to_string(0)
  end

  test 'status_to_string converts integer 1 to Unmet' do
    assert_equal 'Unmet', status_to_string(1)
  end

  test 'status_to_string converts integer 2 to N/A' do
    assert_equal 'N/A', status_to_string(2)
  end

  test 'status_to_string converts integer 3 to Met' do
    assert_equal 'Met', status_to_string(3)
  end

  test 'status_to_string returns nil for nil input' do
    assert_nil status_to_string(nil)
  end

  # Tests for bare URL optimization in markdown processing
  test 'markdown - bare basic URL generates correct result' do
    url = 'https://github.com/Apetree100122/w3id.org'
    result = markdown(url)
    assert_equal '<p><a href="https://github.com/Apetree100122/w3id.org" ' \
                 'rel="nofollow ugc noopener noreferrer">' \
                 'https://github.com/Apetree100122/w3id.org</a></p>' + "\n", result
  end

  test 'markdown - bare URL with simple query string' do
    url = 'https://wiki.onap.org/pages/viewpage.action?pageId=8226539'
    result = markdown(url)
    assert_equal '<p><a href="' \
                 'https://wiki.onap.org/pages/viewpage.action?pageId=8226539" ' \
                 'rel="nofollow ugc noopener noreferrer">' \
                 'https://wiki.onap.org/pages/viewpage.action?pageId=8226539' \
                 '</a></p>' + "\n", result
  end

  test 'markdown - bare URL with multiple query parameters' do
    url = 'https://node-data.atlassian.net/secure/' \
          'RapidBoard.jspa?rapidView=2&view=detail'
    result = markdown(url)
    # NOTE: & is HTML-escaped to &amp; in the output (correct behavior)
    assert_equal '<p><a href="https://node-data.atlassian.net/' \
                 'secure/RapidBoard.jspa?rapidView=2&amp;view=detail" ' \
                 'rel="nofollow ugc noopener noreferrer">' \
                 'https://node-data.atlassian.net/secure/' \
                 'RapidBoard.jspa?rapidView=2&amp;view=detail</a></p>' + "\n", result
  end

  test 'markdown - ampersand escaping with complex query string' do
    # Real-world example with multiple parameters
    url = 'https://gitlab.com/project/issues?' \
          'assignee_id=5&milestone_id=10&state=opened'
    result = markdown(url)
    assert_equal '<p><a href="https://gitlab.com/project/issues?' \
                 'assignee_id=5&amp;milestone_id=10&amp;state=opened" ' \
                 'rel="nofollow ugc noopener noreferrer">' \
                 'https://gitlab.com/project/issues?' \
                 'assignee_id=5&amp;milestone_id=10&amp;state=opened</a></p>' + "\n",
                 result
  end

  test 'markdown - ampersand not confused with HTML entities' do
    # Test that we don't double-escape or confuse & with HTML entities
    # The URL contains &amp; as parameter name (weird but valid)
    url = 'https://example.com?param=test&amp=value'
    result = markdown(url)

    # The &amp (as a parameter name) should be in the href
    # This tests we're not doing double-escaping
    assert result.include?('href="https://example.com?param=test&amp;amp=value"'),
           'Parameter name "amp" should be preserved with proper & escaping'
  end

  # Detailed unit tests for PREFIXED_URL_REGEX
  test 'PREFIXED_URL_REGEX matches valid simple URLs' do
    valid_urls = [
      'http://example.com',
      'https://example.com',
      'HTTP://EXAMPLE.COM',
      'https://example.com/path',
      'https://example.com/path/to/file',
      'https://example.com/path/to/file.html',
      'https://example.com:8080/path',
      'https://sub.example.com',
      'https://deep.sub.example.com',
      'https://example.com#anchor',
      'https://example.com/path#anchor',
      'https://example.com/%22',
      'https://example.com/%27',
      'https://example.com/path%20with%20spaces',
      'https://github.com/user/repo',
      'https://github.com/Apetree100122/w3id.org',
      'https://wiki.onap.org/pages/viewpage.action',
      'https://node-data.atlassian.net/secure/RapidBoard.jspa',
      'https://example.com?query=value',
      'https://example.com?q=test&page=2',
      'https://example.com/path?query=value',
      'https://example.com?query=workflow%3ACodeQL',
      'https://example.com?a=1&b=2&c=3',
      'https://gitlab.com/group/project/issues/new?issue%5Bassignee_id%5D=',
      'https://github.com/devfile/alizer/tree/main?tab=readme-ov-file',
      'https://savannah.gnu.org/bugs/?func=additem&group=make',
      'https://drive.google.com/drive/folders/0B?tid=0Bxrr',
      'https://example.com/path?key=value#anchor'
    ]

    valid_urls.each do |url|
      assert url.match?(MarkdownProcessor::PREFIXED_URL_REGEX),
             "Expected #{url.inspect} to match PREFIXED_URL_REGEX"
    end
  end

  test 'PREFIXED_URL_REGEX rejects URLs with dangerous characters' do
    dangerous_urls = [
      'http://example.com/<script>',
      'http://example.com/"onclick="alert()"',
      "http://example.com/'test'",
      'https://example.com:8080<script>/path',
      'http://example.com/<img src=x>',
      'http://example.com/path">attack',
      "http://example.com/path'>attack",
      'http://example.com/path<script>alert(1)</script>',
      'javascript:alert(1)',
      'data:text/html,<script>alert(1)</script>'
    ]

    dangerous_urls.each do |url|
      assert_not url.match?(MarkdownProcessor::PREFIXED_URL_REGEX),
                 "Expected #{url.inspect} to NOT match PREFIXED_URL_REGEX (security)"
    end
  end

  test 'PREFIXED_URL_REGEX rejects non-URL strings' do
    non_urls = [
      'just plain text',
      'not a url at all',
      'example.com', # Missing protocol
      'http://localhost', # Single-label domain
      'http://', # Incomplete
      'https:/example.com', # Malformed protocol, only one /.
      'http://example', # Single-label domain
      'See http://example.com for details', # Extra text before and after
      'http://example.com is great', # Extra text after
      '', # Empty string
      'http://example.com with spaces', # Unencoded spaces after URL
    ]

    non_urls.each do |text|
      assert_not text.match?(MarkdownProcessor::PREFIXED_URL_REGEX),
                 "Expected #{text.inspect} to NOT match PREFIXED_URL_REGEX"
    end
  end

  test 'PREFIXED_URL_REGEX captures prefix before URL' do
    # Test cases: [input, expected_prefix, expected_url]
    # Note: URL is in group 3 (group 2 is optional < for balanced bracket check)
    test_cases = [
      ['Click here: http://example.com', 'Click here: ', 'http://example.com'],
      [
        'View more at: https://test.org/path', 'View more at: ',
        'https://test.org/path'
      ],
      ['Check this https://foo.bar', 'Check this ', 'https://foo.bar'],
      ['http://example.com', '', 'http://example.com'], # No prefix
      ['123 http://num.test', '123 ', 'http://num.test'], # Digits in prefix
      # Angle brackets around URL (balanced)
      ['<http://example.com>', '', 'http://example.com'],
      ['See: <https://test.org>', 'See: ', 'https://test.org'],
    ]

    test_cases.each do |input, expected_prefix, expected_url|
      match = input.match(MarkdownProcessor::PREFIXED_URL_REGEX)
      assert match, "Expected #{input.inspect} to match PREFIXED_URL_REGEX"
      assert_equal expected_prefix, match[1],
                   "Expected prefix #{expected_prefix.inspect} for #{input.inspect}"
      assert_equal expected_url, match[3],
                   "Expected URL #{expected_url.inspect} for #{input.inspect}"
    end
  end

  test 'PREFIXED_URL_REGEX rejects unbalanced angle brackets' do
    unbalanced = [
      '<http://example.com',   # Missing closing >
      'http://example.com>',   # Missing opening <
      'See: <http://test.org', # Prefix with missing >
    ]

    unbalanced.each do |text|
      assert_not text.match?(MarkdownProcessor::PREFIXED_URL_REGEX),
                 "Expected #{text.inspect} to NOT match (unbalanced brackets)"
    end
  end

  test 'PREFIXED_URL_REGEX accepts various path characters' do
    urls_with_special_paths = [
      'https://example.com/path-with-dashes',
      'https://example.com/path_with_underscores',
      'https://example.com/path.with.dots',
      'https://example.com/path~tilde',
      'https://example.com/path:colon',
      'https://example.com/path@at',
      'https://example.com/path!bang',
      'https://example.com/path$dollar',
      'https://example.com/path&amp',
      'https://example.com/path(parens)',
      'https://example.com/path*star',
      'https://example.com/path+plus',
      'https://example.com/path,comma',
      'https://example.com/path;semicolon',
      'https://example.com/path=equals',
      'https://example.com/%2F%2F', # Encoded slashes
    ]

    urls_with_special_paths.each do |url|
      assert url.match?(MarkdownProcessor::PREFIXED_URL_REGEX),
             "Expected #{url.inspect} to match PREFIXED_URL_REGEX"
    end
  end

  test 'PREFIXED_URL_REGEX handles anchors correctly' do
    urls_with_anchors = [
      'https://example.com#top',
      'https://example.com/page#section',
      'https://example.com#section-name',
      'https://example.com#section_name',
      'https://example.com#section.name',
      'https://example.com#123',
      'https://example.com/path?query=value#anchor',
      'https://example.com#', # Empty anchor
    ]

    urls_with_anchors.each do |url|
      assert url.match?(MarkdownProcessor::PREFIXED_URL_REGEX),
             "Expected #{url.inspect} to match PREFIXED_URL_REGEX"
    end
  end

  # Tests for MARKDOWN_UNNECESSARY pattern to ensure it detects
  # texts that don't need markdown processing.
  # We presume we don't use smartyquotes, so ' and " are passed through.
  # rubocop:disable Metrics/BlockLength
  test 'MARKDOWN_UNNECESSARY matches simple text that needs no processing' do
    simple_texts = [
      'Simple text',
      'Simple text.',
      'Hello world',
      'Hello, world!',
      'This is a test.',
      'This is a test with h, m, w, and x in it.',
      'Text with (parentheses)',
      'Text with "quotes"',
      "Text with 'single quotes'",
      'Text with "curly double quotes"',
      "Text with 'curly single quotes'", # rubocop:disable Style/StringLiterals
      'Text with numbers 123',
      'Text with percent 50%',
      'Question?',
      'Multiple sentences. Like this one.',
      'Comma, semicolon; and more!',
      # HTML entities (passed through - visually equivalent)
      '&quot;',
      '&#8217;',
      '&#8220;',
      '&#8221;',
      'Text with &quot; entity',
      'Text with &#8217; entity',
      '&ldquo;',
      '&rdquo;',
      '&lsquo;',
      '&rsquo;',
      # International characters (Unicode letters)
      'Café',
      'schön!', # Some German words confuse the spellchecker
      'Año nuevo',
      'Привет мир',
      '你好世界',
      'مرحبا بالعالم',
      # Multi-line without blank lines (single paragraph)
      "Line 1\nLine 2",
      "First line\nSecond line",
      "First line\nSecond line\nThird line",
      "Multiple lines\nof simple text\nwithout blank lines",
      "Hello world\nGoodbye world",
      "Café\nschön!",
      "Text line 1\nText line 2\nText line 3\nText line 4",
      # Multi-line with international characters
      "First line\n你好\nThird line",
      "English\nEspañol\nFrançais",
      # Multi-line with optional \r
      "English\r\nEspañol\r\nFrançais",
      # Things that look like autolink but aren't.
      "Hello.\nSee the README.md and CONTRIBUTING.md files.",
      "Hello.\nSee example.com version 1.2.3.0.",
      "Hello.\nUse the https:// protocol.",
    ]

    simple_texts.each do |text|
      assert text.match?(MarkdownProcessor::MARKDOWN_UNNECESSARY),
             "Expected #{text.inspect} to match MARKDOWN_UNNECESSARY"
    end
  end
  # rubocop:enable Metrics/BlockLength

  # rubocop:disable Metrics/BlockLength
  test 'MARKDOWN_UNNECESSARY rejects text requiring markdown processing' do
    markdown_texts = [
      # Anything with "<" *must* not be passed through.
      # Forbidding some uses of "<" is the key requirement for security, so
      # we simply don't accept "<" here.
      '<',
      # Numbered lists
      '1. First item',
      '2. Second item',
      '10. Tenth item',
      "Text\n1. Item", # List on second line
      "Text\n 1. Item", # List on second line, indented
      "Text\n  1. Item",
      "Text\n   1. Item",
      # Un-numbered lists
      '* Item',
      '- Item',
      '+ Item',
      "Text\n* Item", # List on second line
      "Text\n- Item",
      "Text\n+ Item",
      # Headings
      '# Heading',
      '## Heading 2',
      '### Heading 3',
      '#### Heading 4',
      "Text\n# Heading", # Heading on second line
      # Horizontal lines
      '---',
      "Text\n---", # Horizontal line on second line
      # autolinking URLs and domain names
      'http://example.com',
      'https://example.com',
      '<https://example.com>',
      'www.example.com',
      'Text with http://example.com in it',
      'See www.example.com for details',
      "Text\nwww.example.com", # URL on second line
      "Text\nhttps://example.com",
      # Email addresses (need autolinking)
      'test@example.com',
      'user.name@example.com',
      'Contact test@example.com', # Can be handled, not this way
      # \ escaping
      'The backquote (\`) is a fine character',
      # Blank lines (paragraph breaks)
      "Line 1\n\nLine 2",
      "Line 1\n \nLine 2",
      "Line 1\n\t\nLine 2",
      "Line 1\n  \nLine 2",
      "Line 1\n   \nLine 2",
      "Line 1\n    \nLine 2",
      "Line 1\n     \nLine 2",
      "Line 1\n      \nLine 2",
      "Line 1\r\n\r\nLine 2",
      "Text\n\nMore text",
      "Multiple\n\nblank\n\nlines",
      # HTML metacharacters (need escaping)
      '<script>alert(1)</script>',
      '<i>italic</i>',
      'Text with <tags>',
      'Text with > and < symbols',
      # Markdown emphasis
      '*emphasis*',
      '_emphasis_',
      '**bold**',
      '__bold__',
      # Markdown links
      '[Link](http://example.com)',
      '[Link text](url)',
      # Code blocks
      '`code`',
      '```code block```',
      # Blockquotes
      '> Quote',
      # Tables
      "|ID|Status|\n|--|---|\n|1|OK|\n|2|FAIL|",
      "For example:\n  |ID|Status|\n  |--|---|\n  |1|OK|\n  |2|FAIL|",
      "| Name | Type | Description |\n| :--- | :--- | :--- |\n" \
      "| Alpha | User | Primary Admin |\n| Beta | Guest | Limited View |",
      # GFM table, without edge pipes. This is trickier. It's always caught
      # because these require "--- |" lines that our guard rejects.
      "Name | Type | Description\n--- | --- | ---\n" \
      "Alpha | User | Primary Admin\nBeta | Guest | Limited View",
    ]

    markdown_texts.each do |text|
      assert_not text.match?(MarkdownProcessor::MARKDOWN_UNNECESSARY),
                 "Expected #{text.inspect} to NOT match MARKDOWN_UNNECESSARY"
    end
  end

  test 'Markdown renders' do
    result = markdown('*emphasis*')
    assert_equal "<p><em>emphasis</em></p>\n", result
    assert result.html_safe?
  end

  test 'build_repo_select_groups with mixed repos' do
    repo_data_input = [
      ['repo1', false, 'http://example.com', 'https://github.com/user/repo1'],
      ['repo2', true, 'http://example2.com', 'https://github.com/user/repo2']
    ]
    result = build_repo_select_groups(repo_data_input, 'Original', 'Forked')
    assert_equal 2, result.length
    assert_equal 'Original', result[0][0]
    assert_equal 'Forked', result[1][0]
    assert_equal [['repo1', 'https://github.com/user/repo1']], result[0][1]
    assert_equal [['repo2', 'https://github.com/user/repo2']], result[1][1]
  end

  test 'build_repo_select_groups with only original repos' do
    repo_data_input = [
      ['repo1', false, 'http://example.com', 'https://github.com/user/repo1']
    ]
    result = build_repo_select_groups(repo_data_input, 'Original', 'Forked')
    assert_equal 1, result.length
    assert_equal 'Original', result[0][0]
    assert_equal [['repo1', 'https://github.com/user/repo1']], result[0][1]
  end

  test 'build_repo_select_groups with only forked repos' do
    repo_data_input = [
      ['repo2', true, 'http://example.com', 'https://github.com/user/repo2']
    ]
    result = build_repo_select_groups(repo_data_input, 'Original', 'Forked')
    assert_equal 1, result.length
    assert_equal 'Forked', result[0][0]
    assert_equal [['repo2', 'https://github.com/user/repo2']], result[0][1]
  end

  test 'build_repo_select_groups with empty data' do
    result = build_repo_select_groups([], 'Original', 'Forked')
    assert_equal [], result
  end

  test 'build_repo_select_groups with nil data' do
    result = build_repo_select_groups(nil, 'Original', 'Forked')
    assert_equal [], result
  end
  # rubocop:enable Metrics/BlockLength

  # --- non_criteria_automation_display ---

  test 'non_criteria_automation_display returns nil pair when field untouched' do
    @automated_fields  = {}
    @overridden_fields = {}
    css, icon = non_criteria_automation_display(:name)
    assert_nil css
    assert_nil icon
  end

  test 'non_criteria_automation_display returns yellow class for automated field' do
    @automated_fields  = { name: { new_value: 'My Project', explanation: nil } }
    @overridden_fields = {}
    css, icon = non_criteria_automation_display(:name)
    assert_equal ApplicationHelper::HIGHLIGHT_AUTOMATED_CLASS, css
    assert_equal ApplicationHelper::ROBOT_EMOJI_SAFE, icon
  end

  test 'non_criteria_automation_display returns orange class and details icon for overridden field' do
    @automated_fields  = {}
    @overridden_fields = { name: { old_value: 'old name', new_value: 'new name', explanation: nil } }
    css, icon = non_criteria_automation_display(:name)
    assert_equal ApplicationHelper::HIGHLIGHT_OVERRIDDEN_CLASS, css
    assert_match(/<details/, icon)
    assert_match(/⚠/, icon)
  end

  test 'non_criteria_automation_display includes explanation text when provided' do
    @automated_fields  = {}
    @overridden_fields = {
      name: { old_value: 'old', new_value: 'new', explanation: 'tool detected it' }
    }
    css, icon = non_criteria_automation_display(:name)
    assert_equal ApplicationHelper::HIGHLIGHT_OVERRIDDEN_CLASS, css
    assert_match(/tool detected it/, icon)
  end

  test 'non_criteria_automation_display omits explanation text when absent' do
    @automated_fields  = {}
    @overridden_fields = { name: { old_value: 'old', new_value: 'new', explanation: nil } }
    _css, icon = non_criteria_automation_display(:name)
    # explanation_part should be empty string → no stray "Justification:" label
    assert_no_match(/Justification/, icon)
  end

  test 'non_criteria_automation_display includes old justification when present' do
    @automated_fields  = {}
    @overridden_fields = {
      name: {
        old_value: 'old name', new_value: 'new name',
        old_justification: 'user wrote this', explanation: nil
      }
    }
    _css, icon = non_criteria_automation_display(:name)
    assert_match(/user wrote this/, icon)
  end

  test 'non_criteria_automation_display returns divergent icon with highlight class' do
    @automated_fields  = {}
    @overridden_fields = {}
    @divergent_fields  = { name: { proposed_value: 'suggested name' } }
    css, icon = non_criteria_automation_display(:name)
    assert_equal ApplicationHelper::HIGHLIGHT_DIVERGENT_CLASS, css,
                 'divergent field must highlight the row so the difference is visible'
    assert_match(/<details/, icon)
    assert_match(/≠/, icon)
    assert_match(/suggested name/, icon)
  end

  test 'non_criteria_automation_display includes justification in divergent icon' do
    @automated_fields  = {}
    @overridden_fields = {}
    @divergent_fields  = {
      name: {
        proposed_value: 'suggested name',
        proposed_justification: 'detected from repo'
      }
    }
    _css, icon = non_criteria_automation_display(:name)
    assert_match(/detected from repo/, icon)
  end
end
# rubocop:enable Metrics/ClassLength
