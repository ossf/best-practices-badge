# frozen_string_literal: true

# Copyright the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'
require 'prism'

# Finds places that build a regex at runtime from inputs that aren't
# obviously trusted. See DynamicRegexAuditTest for the trust rule.
class DynamicRegexFinder < Prism::Visitor
  # Nodes that are always trusted: literals and constants.
  TRUSTED_NODES = [
    Prism::ConstantReadNode, Prism::ConstantPathNode, Prism::StringNode,
    Prism::RegularExpressionNode, Prism::SymbolNode, Prism::IntegerNode,
    Prism::FloatNode, Prism::NilNode, Prism::TrueNode, Prism::FalseNode
  ].freeze

  # A match/match? receiver that is surely a fixed pattern.
  PATTERN_RECEIVERS = [
    Prism::RegularExpressionNode, Prism::InterpolatedRegularExpressionNode,
    Prism::ConstantReadNode, Prism::ConstantPathNode
  ].freeze

  # @param node [Prism::Node, nil]
  # @return [Array<String>] source of each not-obviously-trusted part
  def self.untrusted_parts(node)
    case node
    when Prism::CallNode
      # No receiver: could be anything (e.g., params). A block could
      # compute anything, so be conservative there too.
      return [node.slice] if node.receiver.nil? || node.block

      untrusted_parts(node.receiver) + untrusted_parts(node.arguments)
    when nil, *TRUSTED_NODES then []
    else
      children = node.compact_child_nodes
      # A leaf we don't know (e.g., a local variable) isn't trusted.
      children.empty? ? [node.slice] : children.flat_map { |c| untrusted_parts(c) }
    end
  end

  attr_reader :sites

  def initialize(path)
    super()
    @path = path
    @sites = []
  end

  def visit_interpolated_regular_expression_node(node)
    record(node, 'interpolated-regex', node.parts)
    super
  end

  def visit_call_node(node)
    if regexp_constructor?(node)
      record(node, "Regexp.#{node.name}", node.arguments&.arguments)
    elsif %i[match match?].include?(node.name) && node.arguments &&
          !PATTERN_RECEIVERS.include?(node.receiver.class)
      # String#match and #match? compile a String argument as a regex.
      record(node, node.name.to_s, [node.arguments.arguments.first])
    end
    super
  end

  private

  def regexp_constructor?(node)
    node.receiver.is_a?(Prism::ConstantReadNode) &&
      node.receiver.name == :Regexp && %i[new compile union].include?(node.name)
  end

  def record(node, kind, inputs)
    parts = Array(inputs).flat_map { |n| self.class.untrusted_parts(n) }
    return if parts.empty?

    key = "#{kind}: #{parts.map { |s| s.gsub(/\s+/, ' ') }.join(', ')}"
    @sites << [@path, node.location.start_line, key]
  end
end

# Ruby's regex compiler (Onigmo) has had memory-safety bugs, e.g., those
# fixed in Ruby 3.4.12, reachable only by compiling a pattern from
# *untrusted* data. Matching untrusted text against our own patterns is
# fine. This test finds every place our production and CI/CD code builds
# a regex at runtime, and requires each one whose pattern isn't obviously
# trusted to be reviewed and listed in ALLOWLIST.
#
# Trusted: literals, constants, and anything computed only from them
# (e.g., Sections::BADGE_URL_SUFFIX.values). That includes ENV, ARGV, and
# STDIN, which we control. Anything else (a local or instance variable,
# a parameter, or a method call without a receiver, such as params) isn't
# obviously trusted, so it needs review.
#
# This is a review gate, not data-flow analysis: an entry says a reviewer
# checked that the named inputs can't come from untrusted data.
class DynamicRegexAuditTest < ActiveSupport::TestCase
  # Reviewed sites, by file. Each entry is "KIND: INPUTS", where INPUTS
  # are the not-obviously-trusted parts the pattern is built from.
  ALLOWLIST = {
    'Rakefile' => [
      'interpolated-regex: lines',
      # Source text, not interpolation:
      'Regexp.union: models.map { |m| /\\b#{m}\\b/ }', # rubocop:disable Lint/InterpolationCheck
      'interpolated-regex: m',
      'match?: rails_re'
    ],
    'app/lib/build_detective.rb' => ['match: name_pattern'],
    'app/lib/name_from_url_detective.rb' => [
      'match: homepage_url', 'match: repo_url'
    ],
    'app/lib/repo_files_examine_detective.rb' => ['match: name_pattern'],
    'app/lib/subdir_file_contents_detective.rb' => [
      'match: name_pattern', 'match?: p'
    ],
    'lib/tasks/default.rake' => [
      'match?: allowed',
      'interpolated-regex: key',
      'Regexp.new: js_anchors_to_ruby(inner)',
      'Regexp.new: js_anchors_to_ruby(pattern)',
      'match?: text'
    ],
    'lib/tasks/machine_translation_helpers.rb' => [
      'interpolated-regex: term', 'match?: pattern'
    ],
    'script/update_mapping_comments.rb' => [
      'interpolated-regex: indent', 'match?: cont_re'
    ],
    'script/update_security_insights_comments.rb' => [
      'interpolated-regex: indent', 'match?: cont_re'
    ]
  }.freeze

  # Ruby files in production and CI/CD code (not tests: their data is ours).
  def ruby_files
    Dir.chdir(Rails.root) do
      Dir.glob(%w[app/**/*.rb lib/**/*.{rb,rake} config/**/*.rb Rakefile]) +
        Dir.glob('{script,bin}/*').select do |f|
          File.file?(f) && File.open(f, &:gets)&.match?(/\A#!.*ruby/)
        end
    end
  end

  def all_sites
    ruby_files.flat_map do |path|
      finder = DynamicRegexFinder.new(path)
      Prism.parse_file(Rails.root.join(path).to_s).value.accept(finder)
      finder.sites
    end
  end

  test 'every regex built from untrusted-looking input is reviewed' do
    sites = all_sites
    unreviewed = sites.reject { |path, _, key| ALLOWLIST.fetch(path, []).include?(key) }
    assert_empty unreviewed.map { |path, line, key| "#{path}:#{line}: #{key}" },
                 'New regex built at runtime from a value that is not a ' \
                 'literal or constant. Ruby regex-compiler bugs can be ' \
                 'reachable from untrusted patterns. Confirm the input ' \
                 "can't come from untrusted data, then add the entry to " \
                 'ALLOWLIST.'

    found = sites.to_set { |path, _, key| [path, key] }
    stale =
      ALLOWLIST.flat_map { |path, keys| keys.map { |k| [path, k] } }
               .reject { |entry| found.include?(entry) }
    assert_empty stale, 'ALLOWLIST entries that no longer match any ' \
                        'site; remove them.'
  end

  test 'detects untrusted input and accepts trusted input' do
    finder = DynamicRegexFinder.new('example.rb')
    Prism.parse(<<~'RUBY').value.accept(finder)
      Regexp.new(params[:q])
      /x#{user}y/
      'abc'.match?(input)
      Regexp.union(Sections::BADGE_URL_SUFFIX.values)
      Regexp.compile(ENV['P'] || 'z')
      /\A#{FOO.source}\z/
      text.match?(SOME_RE)
      SOME_RE.match?(text)
    RUBY
    assert_equal [
      'Regexp.new: params', 'interpolated-regex: user',
      'match?: input'
    ],
                 finder.sites.map(&:last)
  end
end
