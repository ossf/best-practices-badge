# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Helper module providing projects view functionality.
# rubocop:disable Metrics/ModuleLength
module ProjectsHelper
  NO_REPOS = [[], []].freeze # No forks and no originals
  EMPTY_ARRAY = [].freeze # Memory optimization for empty header returns

  # Regex for stripping invalid characters from section IDs
  # Only allow lowercase letters, digits, underscore, and hyphen
  SECTION_ID_INVALID_CHARS = /[^a-z0-9_-]/

  # Invoke markdown processor, which is in its own module.
  # @param content [String] the content to render as Markdown
  # @return [String] rendered HTML
  def markdown(content)
    MarkdownProcessor.render(content)
  end

  # Hash of automated fields for O(1) lookup via Hash#include?.
  # Returns empty hash when @automated_fields is nil.
  # @return [Hash] automated field names set
  def automated_field_set
    @automated_fields || {}
  end

  # Hash of overridden fields for O(1) lookup via Hash#[].
  # Returns empty hash when @overridden_fields is nil.
  # @return [Hash] overridden fields; values are
  #   {old_value:, new_value:, explanation:}
  def overridden_field_set
    @overridden_fields || {}
  end

  # Hash of divergent fields for O(1) lookup via Hash#[].
  # Returns empty hash when @divergent_fields is nil.
  # @return [Hash] divergent fields; values are
  #   {proposed_status: Integer, proposed_justification: String, nil}
  def divergent_field_set
    @divergent_fields || {}
  end

  # Builds a full-width ⚠️ override disclosure block.
  # Used by non_criteria_automation_display and _status_chooser.html.erb.
  # @param detail_body [String] Translated body text
  # @param extra_class [String, nil] Additional CSS class
  # @return [ActiveSupport::SafeBuffer] HTML for the disclosure block
  # rubocop:disable Rails/OutputSafety
  def override_detail_block(detail_body, extra_class: nil)
    css = ['override-detail-block', extra_class].compact.join(' ')
    content_tag(:details, class: css) do
      content_tag(:summary,
                  '⚠️'.html_safe,
                  title: t('projects.edit.automation.overridden_tooltip'),
                  'aria-label': t('projects.edit.automation.aria_overridden')) +
        content_tag(:div, detail_body, class: 'override-detail-body')
    end
  end
  # rubocop:enable Rails/OutputSafety

  # Builds a full-width ≠ divergent disclosure block.
  # Used by non_criteria_automation_display and _status_chooser.html.erb.
  # @param detail_body [String] Translated body text
  # @param extra_class [String, nil] Additional CSS class
  # @return [ActiveSupport::SafeBuffer] HTML for the disclosure block
  # rubocop:disable Rails/OutputSafety
  def divergent_detail_block(detail_body, extra_class: nil)
    css = ['divergent-detail-block', extra_class].compact.join(' ')
    content_tag(:details, class: css) do
      content_tag(:summary,
                  '≠'.html_safe,
                  title: t('projects.edit.automation.aria_divergent'),
                  'aria-label': t('projects.edit.automation.aria_divergent')) +
        content_tag(:div, detail_body, class: 'divergent-detail-body')
    end
  end
  # rubocop:enable Rails/OutputSafety

  # Returns [highlight_css_class, icon_html] for a non-criteria field.
  # Used by _form_basics to show yellow (automated), orange (overridden),
  # or ≠ (divergent).
  # Returns [nil, nil] when the field was not touched by automation.
  # @param field_sym [Symbol] Non-criteria field symbol (e.g., :name, :license)
  # @return [Array(String?, ActiveSupport::SafeBuffer?)] [css_class, icon_html]
  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def non_criteria_automation_display(field_sym)
    if (override_data = overridden_field_set[field_sym])
      old_justification_part =
        if override_data[:old_justification].present?
          t('projects.edit.automation.overridden_old_justification_part',
            old_justification: override_data[:old_justification])
        else
          ''
        end
      explanation_part =
        if override_data[:explanation].present?
          t('projects.edit.automation.overridden_explanation_part',
            explanation: override_data[:explanation])
        else
          ''
        end
      detail_body = t('projects.edit.automation.overridden_detail',
                      old_status: override_data[:old_value].to_s,
                      old_justification_part: old_justification_part,
                      explanation_part: explanation_part)
      [
        ApplicationHelper::HIGHLIGHT_OVERRIDDEN_CLASS,
        override_detail_block(detail_body)
      ]
    elsif automated_field_set.include?(field_sym)
      [
        ApplicationHelper::HIGHLIGHT_AUTOMATED_CLASS,
        ApplicationHelper::ROBOT_EMOJI_SAFE
      ]
    elsif (divergent_data = divergent_field_set[field_sym])
      justification_part =
        if divergent_data[:proposed_justification].present?
          t('projects.edit.automation.divergent_justification_part',
            justification: divergent_data[:proposed_justification])
        else
          ''
        end
      detail_body = t('projects.edit.automation.divergent_detail',
                      status: divergent_data[:proposed_value].to_s,
                      justification_part: justification_part)
      [
        ApplicationHelper::HIGHLIGHT_DIVERGENT_CLASS,
        divergent_detail_block(detail_body)
      ]
    else
      [nil, nil]
    end
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  # Convert a status integer value to its string representation.
  # @param value [Integer] Status value (0-3)
  # @return [String] String representation ('?', 'Unmet', 'N/A', 'Met')
  # @return [nil] if value is nil or out of range
  #
  # This method converts database status values to their
  # external API string representations for backward compatibility.
  #
  # Handles both pre-migration strings and post-migration integers
  # for graceful deployment during the enum optimization rollout.
  # This defensive approach prevents crashes if any cached/serialized
  # string values exist.
  #
  # Examples:
  #   status_to_string(0) # => '?'
  #   status_to_string(1) # => 'Unmet'
  #   status_to_string(2) # => 'N/A'
  #   status_to_string(3) # => 'Met'
  #   status_to_string('Met') # => 'Met' (pre-migration compatibility)
  #   status_to_string(nil) # => nil
  def status_to_string(value)
    return if value.nil?
    return value if value.is_a?(String) # Pre-migration: already a string

    CriterionStatus::STATUS_VALUES[value]
  end

  # Splits repo data into forks and originals.
  # @param retrieved_repo_data [Array, nil] repository data from GitHub API
  # @return [Array(Array, Array)] [forks, originals]
  def fork_and_original(retrieved_repo_data)
    if retrieved_repo_data.blank?
      NO_REPOS
    else
      retrieved_repo_data.partition { |repo| repo[1] }
    end
  end

  # Build grouped options for GitHub repo selector (for select_tag).
  # Returns nil if GitHub token is stale (triggers reconnect prompt),
  # or an array suitable for grouped_options_for_select with originals first.
  # @return [Array, nil] Array of [group_label, options_array] tuples, or nil
  def github_repo_select_groups
    retrieved_repo_data = repo_data
    return if retrieved_repo_data.nil?

    build_repo_select_groups(
      retrieved_repo_data, t('.original_repos'), t('.fork_repos')
    )
  end

  # Pure function to build grouped options from repo data.
  # @param retrieved_repo_data [Array] Repository data from GitHub API
  # @param original_label [String] Label for original repos group
  # @param fork_label [String] Label for forked repos group
  # @return [Array] Array of [group_label, options_array] tuples
  def build_repo_select_groups(retrieved_repo_data, original_label, fork_label)
    return [] if retrieved_repo_data.blank?

    fork_repos, original_repos = fork_and_original(retrieved_repo_data)
    groups = []
    if original_repos.present?
      groups << [original_label, original_repos.map { |r| [r.first, r[3]] }]
    end
    if fork_repos.present?
      groups << [fork_label, fork_repos.map { |r| [r.first, r[3]] }]
    end
    groups
  end

  # Renders the status_chooser partial for one criterion.
  # @param criterion [Symbol] the criterion key
  # @param f [ActionView::Helpers::FormBuilder] the form builder
  # @param project [Project] the project being edited
  # @param criteria_level [String] e.g. 'passing', 'silver', 'gold'
  # @param view_only [Boolean] true to render in read-only mode
  # @param is_last [Boolean] true if last criterion in the section
  # @return [String] rendered HTML partial
  # rubocop:disable Metrics/ParameterLists
  def render_status(
    criterion, f, project, criteria_level, view_only, is_last = false
  )
    render(
      partial: 'status_chooser',
      locals: {
        f: f, project: project, criteria_level: criteria_level,
        view_only: view_only, is_last: is_last,
        criterion: Criteria[criteria_level][criterion.to_sym]
      }
    )
  end

  # Generate HTML for minor heading
  # @param minor [Object] the minor heading text
  # @return [ActiveSupport::SafeBuffer] HTML list item containing h3
  # rubocop:enable Metrics/ParameterLists
  def minor_header_html(minor)
    # rubocop:disable Rails/OutputSafety
    # Section ids: section_ + lowercase letters, digits, _ for spaces.
    # We strip out everything else.
    # Use string interpolation to avoid intermediate string allocation
    normalized = minor.downcase.tr(' ', '_')
                      .gsub(SECTION_ID_INVALID_CHARS, '')
    section_id = "section_#{normalized}"

    safe_join(
      [
        '<li class="list-group-item"><h3 id="'.html_safe,
        section_id,
        '">'.html_safe,
        t(minor, scope: [:headings]),
        '</h3>'.html_safe
      ]
    )
    # rubocop:enable Rails/OutputSafety
  end

  # Renders all status_choosers in the given minor criteria section.
  # @param criteria_level [String] e.g. 'passing', 'silver', 'gold'
  # @param major [String] the major section name
  # @param minor [String] the minor section name
  # @param f [ActionView::Helpers::FormBuilder] the form builder
  # @param project [Project] the project being edited
  # @param view_only [Boolean] true to render in read-only mode
  # @param wrapped [Boolean] true to include list-item wrapper HTML
  # @return [ActionView::OutputBuffer] rendered HTML for the section
  # @raise [NameError] if the minor section has no criteria
  # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
  # rubocop:disable Metrics/ParameterLists
  def render_minor_status(
    criteria_level, major, minor, f, project, view_only, wrapped = true
  )
    minor_criteria = FullCriteriaHash[criteria_level][major][minor].keys
    raise NameError if minor_criteria.empty? # Should always be true

    results = ActionView::OutputBuffer.new
    results << minor_header_html(minor) if wrapped
    minor_criteria.each do |criterion|
      results << render_status(
        criterion, f, project, criteria_level, view_only,
        criterion == minor_criteria.last
      )
    end
    # rubocop:disable Rails/OutputSafety
    results << safe_join(['</li>'.html_safe]) if wrapped
    # rubocop:enable Rails/OutputSafety
    results
  end

  # Return HTML for a sortable header.
  # @param title [String] the title text for the sortable header
  # @param field_name [Object] the database field name for sorting
  # @return [ActiveSupport::SafeBuffer] HTML anchor tag
  # rubocop:enable Metrics/ParameterLists
  # rubocop:enable Metrics/MethodLength,Metrics/AbcSize
  def sortable_header(title, field_name)
    new_params = params.merge(sort: field_name)
                       .permit(ProjectsController::ALLOWED_QUERY_PARAMS)
    if params[:sort] == field_name && params[:sort_direction] != 'desc'
      new_params[:sort_direction] = 'desc'
    else
      new_params.delete(:sort_direction)
    end

    # The html_safe assertion here allows the HTML of
    # <a href...> to go through.  This *is* handled for security;
    # params.merge performs the URL encoding as required, and "title" is
    # trusted (it's provided by the code, not by a potential attacker).
    # We use "nofollow" to discourage search engines from following it
    # rubocop:disable Rails/OutputSafety
    "<a href=\"#{url_for(new_params)}\" rel=\"nofollow\">#{title}</a>".html_safe
    # rubocop:enable Rails/OutputSafety
  end

  # Given tiered percentage as integer value, return its string representation
  # @param value [Object] tiered percentage integer (0-300), or blank
  # @return [String, nil] localized progress string, or nil if blank
  # rubocop:disable Metrics/MethodLength
  def tiered_percent_as_string(value)
    return if value.blank?

    partial = value % 100
    if value < 100
      I18n.t 'projects.index.in_progress_next', percent: partial
    elsif value < 200
      I18n.t 'projects.index.passing_next', percent: partial
    elsif value < 300
      I18n.t 'projects.index.silver_next', percent: partial
    elsif value >= 300
      I18n.t 'projects.form_early.level.2'
    end
  end
  # rubocop:enable Metrics/MethodLength

  # We sometimes insert <wbr> after sequences of these characters.
  WORD_BREAK_DIVIDERS = /([,_\-.]+)/

  # This text is considered safe, so we can directly mark it as such.
  # rubocop:disable Rails/OutputSafety
  SAFE_WORD_BREAK = '<wbr>'.html_safe
  # rubocop:enable Rails/OutputSafety

  # Insert wbr (HTML word break) after _ etc. per WORD_BREAK_DIVIDERS.
  # The text is presumed to be unsafe; output is escaped HTML.
  # @param text [String] the text to insert word-break opportunities into
  # @return [ActiveSupport::SafeBuffer] escaped HTML with wbr tags inserted
  def word_breakdown(text)
    safe_join(
      text.split(WORD_BREAK_DIVIDERS).each_with_index.map do |fragment, i|
        i.even? ? fragment : h(fragment) + SAFE_WORD_BREAK
      end,
      ''
    )
  end

  # Module method: Computes display form for a baseline ID.
  # This is private and only used during constant initialization.
  # Internal: osps_ac_03_01 (lowercase, underscores)
  # Display: OSPS-AC-03.01 (uppercase, dashes, dot before last segment)
  # Also handles field names:
  # Internal: osps_ac_03_01_status
  # Display: OSPS-AC-03.01_status
  # @param id_str [String] baseline ID or field name in internal form
  # @return [String] baseline ID or field name in display form, or original
  # rubocop:disable Metrics/AbcSize
  def self.compute_baseline_display_name(id_str)
    # Only convert if it looks like a baseline ID (starts with osps_)
    return id_str unless id_str.start_with?('osps_')

    # Split on underscores: osps_ac_03_01 -> [osps, ac, 03, 01]
    # or osps_ac_03_01_status -> [osps, ac, 03, 01, status]
    parts = id_str.split('_')

    if parts.size == 4
      # Criterion ID: OSPS-AC-03.01
      "#{parts.first.upcase}-#{parts[1].upcase}-#{parts[2]}.#{parts[3]}"
    elsif parts.size == 5 && %w[status justification].include?(parts[4])
      # Field name: OSPS-AC-03.01_status
      prefix = [parts.first.upcase, parts[1].upcase, parts[2]].join('-')
      "#{prefix}.#{parts[3]}_#{parts[4]}"
    else
      id_str # Return original if not recognized format
    end
  end
  # rubocop:enable Metrics/AbcSize
  private_class_method :compute_baseline_display_name

  # Module method: Computes internal form for a baseline ID in display form.
  # This is private and only used during constant initialization.
  # Display: OSPS-AC-03.01 (uppercase, dashes, dot)
  # Internal: osps_ac_03_01 (lowercase, underscores)
  # @param id_str [String] baseline ID in display form
  # @return [String] baseline ID in internal form, or original if not baseline
  def self.compute_baseline_internal_name(id_str)
    # Only convert if it looks like a baseline ID (starts with OSPS-)
    return id_str unless id_str.match?(/^OSPS-/i)

    # Convert to lowercase and replace dashes/dots with underscores
    # OSPS-AC-03.01 -> osps_ac_03_01
    id_str.downcase.tr('-.', '__')
  end
  private_class_method :compute_baseline_internal_name

  # Precomputed mapping: Project field names from internal to display form.
  # Computed once at load time, eliminating repeated transformations and GC.
  # Only includes fields that need transformation (baseline fields).
  BASELINE_FIELD_DISPLAY_NAME_MAP =
    Project.column_names.each_with_object({}) do |name, hash|
      transformed = compute_baseline_display_name(name)
      hash[name] = transformed if transformed != name
    end
  BASELINE_FIELD_DISPLAY_NAME_MAP.freeze

  # We currently don't use this mapping of external->internal names,
  # we instead use internal names and occasionally translate them to
  # external names for display. However, it's conceivable that we might
  # want to do that (e.g., accept JSON files with external display keys),
  # so here's how to compute that.
  # Precomputed mapping: Baseline display names to internal field names.
  # Computed once at load time, eliminating repeated transformations and GC.
  # BASELINE_DISPLAY_TO_INTERNAL_NAME_MAP =
  #   BASELINE_FIELD_DISPLAY_NAME_MAP
  #     .each_with_object({}) do |(internal, display), hash|
  #     hash[display] = internal
  #   end
  # BASELINE_DISPLAY_TO_INTERNAL_NAME_MAP.freeze

  # Instance method: Converts baseline ID from internal form to display form.
  # Uses precomputed map for database fields (O(1), no allocations).
  # Falls back to computation for non-field IDs (e.g., criterion IDs).
  # @param id [String, Symbol] baseline ID or field name in internal form
  # @return [String] baseline ID or field name in display form, or original
  def baseline_id_to_display(id)
    id_str = id.to_s
    # Fast path: Use precomputed map for database fields
    return BASELINE_FIELD_DISPLAY_NAME_MAP[id_str] if
      BASELINE_FIELD_DISPLAY_NAME_MAP.key?(id_str)

    # Fallback: Compute for criterion IDs not in database
    return id_str unless id_str.start_with?('osps_')

    parts = id_str.split('_')
    if parts.size == 4
      "#{parts.first.upcase}-#{parts[1].upcase}-#{parts[2]}.#{parts[3]}"
    else
      id_str
    end
  end

  # We currently don't use this mapping of external->internal names, but
  # here's a way to do that.
  # Instance method: Converts baseline ID from display form to internal form.
  # Uses precomputed map for database fields (O(1), no allocations).
  # Falls back to computation for non-field IDs (e.g., criterion IDs).
  # @param id [String] baseline ID in display form
  # @return [String] baseline ID in internal form, or original if not baseline
  # def baseline_id_to_internal(id)
  #   id_str = id.to_s
  #   # Fast path: Use precomputed map for database fields
  #   return BASELINE_DISPLAY_TO_INTERNAL_NAME_MAP[id_str] if
  #     BASELINE_DISPLAY_TO_INTERNAL_NAME_MAP.key?(id_str)
  #   # Fallback: Compute for criterion IDs not in database
  #   return id_str unless id_str.match?(/^OSPS-/i)
  #   id_str.downcase.tr('-.', '__')
  # end

  # Generates a radio button, handling integer↔string conversion.
  # Status integers are stored in DB, displayed as strings in forms.
  # Reads the integer value, converts to string for comparison,
  # then generates the appropriate HTML radio button.
  #
  # @param form [ActionView::Helpers::FormBuilder] the form builder
  # @param project [Project] the project instance
  # @param status_field [Symbol] e.g. :description_good_status
  # @param string_value [String] radio value e.g. 'Met', 'Unmet'
  # @param ** [Hash] extra keyword args (label:, disabled:, etc.)
  # @return [String] HTML for the radio button
  def status_radio_button(form, project, status_field, string_value, **)
    # Read the raw integer value from the database and convert to string
    current_string = status_to_string(project[status_field])

    # Determine if this radio button should be checked
    checked = (current_string == string_value)

    # Generate the radio button using bootstrap_form's radio_button helper
    # Pass the string value; the controller converts it to integer
    form.radio_button(status_field, string_value, checked: checked, **)
  end
end
# rubocop:enable Metrics/ModuleLength
