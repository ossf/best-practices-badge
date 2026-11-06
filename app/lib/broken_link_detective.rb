# frozen_string_literal: true

# Copyright 2015-2026, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# rubocop:disable Metrics/ClassLength
# Detective that checks URLs in homepage_url, repo_url, and criteria
# justifications, marking criteria with broken links as not passing.
class BrokenLinkDetective < Detective
  using SymbolRefinements

  BASE_URL_INPUTS = %i[
    homepage_url homepage_url_status homepage_url_justification
    sites_https_status sites_https_justification
    repo_url repo_public_status repo_public_justification
  ].freeze

  ALL_CRITERIA_STATUS = Criteria.all.map(&:status).freeze
  ALL_CRITERIA_JUSTIFICATION = Criteria.all.map(&:justification).freeze

  INPUTS = BASE_URL_INPUTS

  OUTPUTS = (
    %i[
      homepage_url_status homepage_url_justification
      sites_https_status sites_https_justification
      repo_public_status repo_public_justification
    ] +
    ALL_CRITERIA_STATUS +
    ALL_CRITERIA_JUSTIFICATION
  ).uniq.freeze

  PREREQUISITE_CRITERIA = %i[achieve_passing achieve_silver].freeze

  # Bound foreground link checks executed during synchronous form edits/saves.
  FOREGROUND_MAX_DURATION = 10
  FOREGROUND_TIMEOUT = 3

  def initialize(
    link_checker = nil,
    grace_days: Project::BROKEN_LINK_GRACE_DAYS,
    current_date: nil
  )
    super()
    @link_checker = link_checker
    @grace_days = grace_days
    @current_date = current_date
  end

  def analyze(evidence, current)
    checker = @link_checker || LinkChecker.new(
      retries: 0,
      timeout: FOREGROUND_TIMEOUT,
      max_total_duration: FOREGROUND_MAX_DURATION
    )
    @results = {}
    check_homepage_url(checker, current)
    check_all_criteria(checker, current, evidence.project)
    @results
  end

  private

  def check_homepage_url(checker, current)
    url = current[:homepage_url]
    return if url.blank?

    current_just = current[:homepage_url_justification]
    status = checker.url_status(url)
    if status == :ok
      clean_marker_if_needed(:homepage_url_justification, current_just)
    elsif status == :broken
      handle_broken_link(
        :homepage_url_status, :homepage_url_justification,
        'Unmet', current_just, url
      )
    end
  end

  def check_all_criteria(checker, current, project)
    seen = Set.new
    Criteria.each_value do |level_criteria|
      level_criteria.each_value do |criterion|
        next if PREREQUISITE_CRITERIA.include?(criterion.name)
        next if seen.include?(criterion.name)

        seen.add(criterion.name)
        check_criterion(checker, criterion, current, project)
      end
    end
  end

  # rubocop:disable-next Metrics/MethodLength
  def check_criterion(checker, criterion, current, project)
    status_key = :"#{criterion.name}_status"
    just_key = :"#{criterion.name}_justification"
    justification = current.fetch(just_key) { project[just_key] }
    base_urls = base_urls_for_criterion(criterion.name, current)

    urls = (base_urls + LinkChecker.extract_urls_including_flagged(justification)).uniq
    statuses = urls.index_with { |url| checker.url_status(url) }
    broken_url = statuses.key(:broken)
    if broken_url
      handle_broken_link(
        status_key, just_key, failing_status_for(criterion), justification, broken_url
      )
    elsif statuses.values.all?(:ok)
      clean_marker_if_needed(just_key, justification)
    end
  end

  def base_urls_for_criterion(criterion_name, current)
    case criterion_name
    when :sites_https
      [current[:homepage_url]].compact_blank
    when :repo_public
      [current[:repo_url]].compact_blank
    else
      []
    end
  end

  # rubocop:disable-next Metrics/ParameterLists
  def handle_broken_link(status_key, just_key, fail_status, justification, broken_url)
    return if grace_warning_active_for?(justification, broken_url)

    if grace_period_expired_for?(justification, broken_url)
      @results[status_key] = { value: fail_status, confidence: 5 }
      @results[just_key] = {
        value: LinkChecker.format_broken_prefix(justification, broken_url),
        confidence: 5
      }
    else
      mark_grace_period(just_key, justification, broken_url)
    end
  end

  # A future detected date is not trusted (the marker is user-editable), so
  # it neither keeps a grace period active nor counts as expired; the grace
  # period restarts from today instead.
  def grace_period_expired_for?(justification, url)
    return true if @grace_days <= 0 || LinkChecker.broken_prefix_url(justification) == url

    detected_date = LinkChecker.grace_detected_date(justification)
    detected_date.present? && detected_date <= today &&
      LinkChecker.grace_warning_url(justification) == url
  end

  def grace_period_active?(justification)
    return false if @grace_days <= 0

    detected_date = LinkChecker.grace_detected_date(justification)
    return false if detected_date.nil? || detected_date > today

    (today - detected_date).to_i < @grace_days
  end

  def today
    @current_date || Time.now.utc.to_date
  end

  def grace_warning_active_for?(justification, url)
    grace_period_active?(justification) &&
      LinkChecker.grace_warning_url(justification) == url
  end

  def mark_grace_period(just_key, justification, broken_url)
    detected_date = today.iso8601
    @results[just_key] = {
      value: LinkChecker.format_grace_warning(
        justification, broken_url, detected_date
      ),
      confidence: 5
    }
  end

  def failing_status_for(criterion)
    criterion.suggested? ? CriterionStatus::UNKNOWN : CriterionStatus::UNMET
  end

  def flagged_with_broken_link?(text)
    return false if text.blank?

    LinkChecker::BROKEN_LINK_PREFIX_REGEX.match?(text) ||
      LinkChecker::BROKEN_LINK_GRACE_REGEX.match?(text)
  end

  def clean_marker_if_needed(just_key, justification)
    return unless flagged_with_broken_link?(justification)

    @results[just_key] = {
      value: LinkChecker.strip_broken_link_markers(justification),
      confidence: 5
    }
  end
end
# rubocop:enable Metrics/ClassLength
