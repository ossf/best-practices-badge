# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# What's NEW in a bundle-audit report, said loudly enough to be noticed.
#
# WHY THIS EXISTS. .github/workflows/bundle_audit.yml keeps one open
# issue and rewrites its body each day. GitHub notifies nobody about a
# body edit, so once that issue was open, a new advisory (even a
# critical one) arrived silently. A comment does notify, so we comment,
# but only about advisories the issue didn't already list: an unchanged
# daily run must stay quiet, or the comments become noise.
#
# WHO IS TOLD comes from .github/CODEOWNERS, the owners of /Gemfile.lock,
# since they're the people who must approve the fix. GitHub can't
# mention a role ("all maintainers"), only users and teams, and a second
# list here would drift from that one.
#
# STANDARD LIBRARY ONLY. script/bundle_audit_news loads this on a bare
# runner with no bundle.
module BundleAuditNews
  # bundle-audit's own spelling of a severity.
  SEVERE = %w[Critical High].freeze

  ID_RE = /\b(?:GHSA(?:-[23456789cfghjmpqrvwx]{4}){3}|CVE-\d{4}-\d{4,})\b/

  # The file whose owners we notify.
  OWNED_PATH = '/Gemfile.lock'

  # A GitHub login or org/team, with its "@". Anything else in CODEOWNERS
  # (e.g., an email address) is skipped rather than mentioned.
  HANDLE_RE = %r{\A@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:/[\w.-]+)?\z}

  module_function

  # @param report [String] bundle-audit's text output
  # @return [Array<Hash>] one Hash per advisory, with :ids, :name,
  #   :version, :criticality and :title. bundle-audit repeats an
  #   advisory once per platform gem (nokogiri has nine), so each is kept
  #   only once.
  def parse(report)
    advisories = report.split(/\n\s*\n/).filter_map { |b| advisory(b) }
    advisories.uniq { |adv| adv[:ids] }
  end

  # @return [Hash, nil] one block of the report, or nil if it isn't one
  def advisory(block)
    fields = block.scan(/^(\w+): (.*)$/).to_h
    return unless fields['Name']

    {
      ids: block.scan(ID_RE).uniq, name: fields['Name'],
      version: fields['Version'], criticality: fields['Criticality'],
      title: fields['Title']
    }
  end

  # An advisory is new unless one of its IDs already appears in the
  # issue's previous body, whether as its GHSA or its CVE.
  # @param report [String] today's bundle-audit output
  # @param previous [String] the issue body before today's run, or ""
  # @return [Array<Hash>] the advisories not already reported
  def fresh(report, previous)
    known = previous.scan(ID_RE)
    parse(report).reject { |adv| adv[:ids].intersect?(known) }
  end

  # @return [Boolean] whether any of these advisories is High or Critical
  def severe?(advisories)
    advisories.any? { |adv| SEVERE.include?(adv[:criticality]) }
  end

  # @param codeowners [String] the text of .github/CODEOWNERS
  # @return [Array<String>] the handles owning OWNED_PATH. As in GitHub,
  #   the LAST matching line wins.
  def owners(codeowners)
    line =
      codeowners.lines.reverse.find do |l|
        l.split.first == OWNED_PATH
      end
    return [] unless line

    line.split.drop(1).grep(HANDLE_RE)
  end

  # SHORT ON PURPOSE. A comment is a notification, and the issue body
  # already holds the full report. So only High and Critical are listed
  # one by one, and only they mention the owners; anything milder is
  # one line, which still notifies people watching the repository.
  #
  # @param advisories [Array<Hash>] the new advisories
  # @param handles [Array<String>] who to mention if any is severe
  # @return [String, nil] the comment to post, or nil if nothing is new
  def comment(advisories, handles)
    return if advisories.empty?

    severe, other = advisories.partition { |a| SEVERE.include?(a[:criticality]) }
    mention = severe.empty? ? '' : "#{handles.join(' ')} "
    [
      "#{mention}bundle-audit found #{count(advisories)}. " \
      'The issue body has the full report.',
      (severe.map { |a| row(a) }.join("\n") unless severe.empty?),
      milder(other)
    ].compact.join("\n\n")
  end

  def count(advisories)
    "#{advisories.size} new #{advisories.size == 1 ? 'advisory' : 'advisories'}"
  end

  def row(adv)
    "- **#{adv[:criticality]}** #{adv[:name]} #{adv[:version]}: " \
      "#{adv[:title]} (#{adv[:ids].join(', ')})"
  end

  def milder(advisories)
    return if advisories.empty?

    # Not "pluck", which ActiveSupport adds; this file must run without it.
    # rubocop:disable-next Rails/Pluck
    names = advisories.map { |a| a[:name] }.uniq.join(', ')
    "Below High: #{count(advisories)}, in #{names}."
  end
end
