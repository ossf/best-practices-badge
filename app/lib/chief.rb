# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# A 'chief' instance analyzes project data.  It does this by calling
# 'Detectives' (analyzers) in the right order, each of which have
# access to the evidence accumulated so far.

# Only the 'chief' decides when to update the proposed changes.
# Currently it just runs sequentially, but the plan is for it to use
# the Detective INPUTS and OUTPUTS to determine what order to run, and
# run them in parallel in an appropriate order.

# rubocop:disable Metrics/ClassLength
class Chief
  # Confidence scale: integers in 1..MAX_CONFIDENCE.
  # At CONFIDENCE_OVERRIDE or above, automation overrides human-entered values.
  # Below CONFIDENCE_OVERRIDE, automation only fills blank/unknown fields.
  MAX_CONFIDENCE = 5
  CONFIDENCE_OVERRIDE = 4

  # TODO: Identify classes automatically and do topological sort.
  # Automatically discover all Detective subclasses from app/lib/*_detective.rb
  # This prevents the footgun of forgetting to register new detectives.
  def self.discover_detectives
    # Load all detective files from app/lib (not test/)
    detective_files = Rails.root.glob('app/lib/*_detective.rb')
    detective_files.each { |file| require file }

    # Get all Detective subclasses
    all_detectives = Detective.descendants

    # Filter to only classes defined in app/lib files (not test fixtures)
    # Check if the class is defined in a file under app/lib
    result =
      all_detectives.select do |detective_class|
        # Get the source location of the class
        source_file = Object.const_source_location(detective_class.name)&.first
        next false unless source_file

        # Only include if defined in app/lib
        source_file.include?('/app/lib/') &&
          # Exclude Test* detectives unless in test environment
          (Rails.env.test? || !detective_class.name.start_with?('Test'))
      end

    result
  end

  ALL_DETECTIVES = discover_detectives.freeze

  # List fields allowed to be written into Project (an ActiveRecord).
  ALLOWED_FIELDS = Project::PROJECT_PERMITTED_FIELDS.to_set.freeze

  # rubocop:disable Style/ConditionalAssignment
  def initialize(project, client_factory, entry_locale: nil, detectives: ALL_DETECTIVES)
    @evidence = Evidence.new(project)
    @client_factory = client_factory
    @entry_locale = entry_locale || project.entry_locale
    @detectives = detectives

    # Determine what exceptions to intercept - if we're in
    # test or development, we will only intercept an exception we don't use.
    current_environment = (ENV['RAILS_ENV'] || 'development').to_sym
    if %i[test development].include?(current_environment)
      @intercept_exception = NoSuchException
    else
      @intercept_exception = StandardError
    end
  end
  # rubocop:enable Style/ConditionalAssignment

  # Given two changesets, produce merged "best" version
  # When confidence is the same, c1 wins.
  # Adds a :forced flag based on confidence level (internal detail not exposed)
  def merge_changeset(c1, c2)
    result = c1.dup
    c2.each do |field, data|
      next if result.key?(field) &&
              (data[:confidence] <= result[field][:confidence])

      # Add forced flag based on confidence (hide confidence from callers)
      enhanced_data = data.dup
      enhanced_data[:forced] =
        data[:confidence].present? && data[:confidence] >= CONFIDENCE_OVERRIDE
      result[field] = enhanced_data
    end
    result
  end

  # Should we should update a project's value for 'key'?
  # changeset_data is hash with :value, :confidence, :explanation
  def update_value?(project, key, changeset_data)
    if changeset_data.blank?
      false
    elsif !project.attribute_present?(key) || project[key].blank? ||
          project[key] == CriterionStatus::UNKNOWN
      true
    else
      changeset_data[:confidence].present? &&
        changeset_data[:confidence] >= CONFIDENCE_OVERRIDE
    end
  end

  # Return the best estimates for fields, given project & current proposal.
  # Current proposal is a hash, keys are symbols of what that might be changed.
  def compute_current(fields, project, current_proposal)
    result = {}
    fields.each do |f|
      if update_value?(project, f, current_proposal[f])
        result[f] = current_proposal[f][:value]
      elsif project.attribute_present?(f)
        result[f] = project[f]
      end
    end
    result
  end

  def log_detective_failure(source, e, detective, proposal, data)
    Rails.logger.error do
      'ERROR:: ' \
        "In method #{source}, exception #{e} on #{detective.class.name}, " \
        "current_proposal= #{proposal}, current_data= #{data}"
    end
  end

  # Execute a block with I18n.locale temporarily set to the project's entry_locale.
  # This ensures detective explanations are generated in the project's language.
  # @yield Block to execute with project locale set
  # @return Result of the block
  def with_project_locale
    original_locale = I18n.locale
    I18n.locale = @entry_locale&.to_sym || :en
    yield
  ensure
    I18n.locale = original_locale
  end

  # Invoke one "Detective", which will
  # analyze the project and reply with an updated changeset in the form
  # { fieldname1: { value: value, confidence: 1..5, explanation: text}, ...}
  # rubocop:disable Metrics/MethodLength
  def propose_one_change(detective, current_proposal)
    begin
      current_data = compute_current(
        detective.class::INPUTS, @evidence.project, current_proposal
      )
      result = detective.analyze(@evidence, current_data)
      current_proposal = merge_changeset(current_proposal, result)
    # If we're in production, ignore exceptions from detectives.
    # That way we just autofill less, instead of completely failing.
    rescue @intercept_exception => e
      log_detective_failure(
        'propose_one_change', e, detective, current_proposal, current_data
      )
    end
    current_proposal
  end
  # rubocop:enable Metrics/MethodLength

  # Like propose_one_change but for MappingDetective subclasses.
  # Passes the full current_proposal as a third argument to analyze so the
  # detective can distinguish user-entered source values (YAML confidence used
  # as-is) from auto-detected ones (confidence scaled by source confidence).
  def propose_mapping_change(detective, current_proposal)
    begin
      current_data = compute_current(
        detective.class::INPUTS, @evidence.project, current_proposal
      )
      result = detective.analyze(@evidence, current_data, current_proposal)
      current_proposal = merge_changeset(current_proposal, result)
    rescue @intercept_exception => e
      log_detective_failure(
        'propose_mapping_change', e, detective, current_proposal, current_data
      )
    end
    current_proposal
  end

  # Determine which detectives are needed to produce the requested outputs.
  # Uses backward search from needed_outputs through detective dependency graph.
  # @param needed_outputs [Set] Set of field symbols we want to produce
  # @param pool [Array<Class>] Detective classes to search (default ALL_DETECTIVES)
  # @return [Array<Class>] Array of detective classes needed
  # rubocop:disable Metrics/MethodLength
  def filter_needed_detectives(needed_outputs, pool = ALL_DETECTIVES)
    return pool if needed_outputs.blank?

    required_detectives = Set.new
    required_outputs = needed_outputs.dup
    changed = true

    # Backward search: keep adding detectives whose outputs we need
    while changed
      changed = false
      pool.each do |detective_class|
        next if required_detectives.include?(detective_class)

        # If this detective provides any output we need, include it
        # Use set intersection to check overlap
        next unless detective_class::OUTPUTS.to_set.intersect?(required_outputs)

        required_detectives.add(detective_class)
        # Now we also need its inputs
        required_outputs.merge(detective_class::INPUTS)
        changed = true
      end
    end

    required_detectives.to_a
  end
  # rubocop:enable Metrics/MethodLength

  # Sort detectives in topological order based on their INPUTS/OUTPUTS.
  # Uses Kahn's algorithm for topological sort.
  # @param detectives [Array<Class>] Detective classes to sort
  # @return [Array<Class>] Sorted detective classes
  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def topological_sort_detectives(detectives)
    # Build dependency graph: detective => Set of detectives it depends on
    dependencies = {}
    detectives.each do |detective_class|
      dependencies[detective_class] = Set.new

      # For each detective, find which other detectives it depends on
      inputs_needed = detective_class::INPUTS.to_set
      detectives.each do |other_detective|
        next if detective_class == other_detective

        # If other_detective provides outputs that detective_class needs as inputs
        outputs_provided = other_detective::OUTPUTS.to_set
        if outputs_provided.intersect?(inputs_needed)
          dependencies[detective_class].add(other_detective)
        end
      end
    end

    # Kahn's algorithm for topological sort
    sorted = []
    no_dependencies = detectives.select { |d| dependencies[d].empty? }

    until no_dependencies.empty?
      detective = no_dependencies.shift
      sorted << detective

      # Remove this detective from all dependency lists
      dependencies.each do |dependent, deps|
        deps.delete(detective)
        if deps.empty? && !sorted.include?(dependent) &&
           !no_dependencies.include?(dependent)
          no_dependencies << dependent
        end
      end
    end

    # If not all detectives are sorted, there's a circular dependency
    # Fall back to original order for safety
    sorted.size == detectives.size ? sorted : detectives
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  # Determine which detective outputs are needed.
  # The caller supplies the set of fields relevant to the current section;
  # Chief intersects that with detective OUTPUTS to decide what to run.
  # @param needed_fields [Set<Symbol>, nil] Fields the caller wants filled,
  #   or nil to request all detective outputs (e.g. cron job scenario)
  # @param changed_fields [Array<Symbol>, nil] Additional fields to include
  # @return [Set<Symbol>] Set of output field symbols needed
  def needed_outputs(needed_fields, changed_fields = nil)
    needed = Set.new

    if needed_fields.nil?
      # nil means "everything" (cron job / full-autofill scenario)
      @detectives.each { |d| needed.merge(d::OUTPUTS) }
    else
      # Keep only detective outputs that the caller actually wants
      @detectives.each do |detective_class|
        detective_class::OUTPUTS.each do |output|
          needed.add(output) if needed_fields.include?(output)
        end
      end
    end

    # Add any explicitly changed fields (for save scenario)
    needed.merge(changed_fields) if changed_fields

    needed
  end

  # Analyze project and reply with a changeset in the form
  # { fieldname1: { value: value, confidence: 1..5, explanation: text}, ...}
  # Do this by determining the right order and way to invoke "detectives"
  # for this project, invoke them, and process their results.
  # @param needed_fields [Set<Symbol>, nil] Fields the caller wants filled
  #   (nil = all detective outputs, e.g. cron job)
  # @param changed_fields [Array<Symbol>, nil] Fields that were explicitly changed
  # @param only_consider_overrides [Boolean] Whether to only run detectives that
  #   can force overrides (confidence >= CONFIDENCE_OVERRIDE). Default false.
  #   Set to true for "save and exit" to skip unnecessary work.
  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def propose_changes(needed_fields: nil, changed_fields: nil, only_consider_overrides: false)
    with_project_locale do
      current_proposal = {} # Current best changeset.

      # Determine what outputs we need
      needed = needed_outputs(needed_fields, changed_fields)

      # Partition MappingDetective subclasses out of the normal pool and select
      # exactly one based on direction (metal→baseline or baseline→metal).
      # This prevents a dependency cycle in the backward search: if both were
      # in the pool, each one's INPUTS would pull the other in transitively.
      pool, mapping_detective_class = partition_mapping_detective(needed)

      # If a mapping detective was selected, add its INPUTS to the needed set
      # so the backward search in filter_needed_detectives pulls in any
      # detectives that produce those source fields (e.g. SubdirFileContentsDetective
      # produces documentation_basics_status, which would otherwise be missed on
      # a baseline-only page since it outputs no baseline fields directly).
      needed.merge(mapping_detective_class::INPUTS) if mapping_detective_class

      # Filter to only needed detectives (subset varies per request)
      detectives_to_run = filter_needed_detectives(needed, pool)

      # Sort that specific subset in dependency order
      detectives_to_run = topological_sort_detectives(detectives_to_run)

      # Run each detective in the sorted order
      detectives_to_run.each do |detective_class|
        detective = detective_class.new
        detective.octokit_client_factory = @client_factory
        current_proposal = propose_one_change(detective, current_proposal)
      end

      # Run the selected mapping detective after the normal pipeline so it sees
      # all accumulated proposals (auto-detected values from prior detectives).
      # Uses propose_mapping_change (not propose_one_change) so the full
      # current_proposal is passed to analyze for confidence scaling and
      # explanation text when the source value came from a prior detective.
      # Skip on save-exit (only_consider_overrides) since mapping confidence is
      # always <= 3 and can never force an override.
      if !only_consider_overrides && mapping_detective_class
        mapping_detective = mapping_detective_class.new
        mapping_detective.octokit_client_factory = @client_factory
        current_proposal = propose_mapping_change(mapping_detective, current_proposal)
      end

      # Run RepoJsonDetective last as a final overlay of project
      # self-declarations.
      # We only run this if non-overridable results might be used
      # (initial edit or save-continue). We skip this on
      # save-exit since these self-declarations can never force an override.
      if !only_consider_overrides && repo_files_available?
        repo_json_detective = RepoJsonDetective.new
        repo_json_detective.octokit_client_factory = @client_factory
        current_proposal = propose_one_change(repo_json_detective, current_proposal)
      end

      current_proposal
    end
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  # Given project data, return it with the proposed changeset applied.
  # Note: This should probably be class-level
  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def apply_changes(project, changes)
    changes.each do |key, data|
      next if ALLOWED_FIELDS.exclude?(key)
      next unless update_value?(project, key, data)

      old_value = project.attribute_present?(key) ? project[key] : nil
      project[key] = data[:value]
      # Set justification if the status actually changed, or if the
      # justification is empty. If the status is unchanged and there's
      # already a justification, leave it alone — the user's rationale
      # should not be modified when no status change occurred.
      next unless key.to_s.end_with?('_status') && data.key?(:explanation)

      status_changed = old_value != data[:value]
      justification_key = (key.to_s.chomp('_status') + '_justification').to_sym
      existing = project.attribute_present?(justification_key) &&
                 project[justification_key]
      next if !status_changed && existing.present?

      project[justification_key] = data[:explanation]
    end
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity

  # Given form data about a project, return an improved version.
  # @param needed_fields [Set<Symbol>, nil] Fields the caller wants filled
  #   (nil = all detective outputs)
  # @param changed_fields [Array<Symbol>, nil] Fields that were explicitly changed
  # @param only_consider_overrides [Boolean] Whether to only run detectives that
  #   can force overrides. Set true for "save and exit" optimization.
  def autofill(needed_fields: nil, changed_fields: nil, only_consider_overrides: false)
    my_proposed_changes = propose_changes(
      needed_fields: needed_fields,
      changed_fields: changed_fields,
      only_consider_overrides: only_consider_overrides
    )
    apply_changes(@evidence.project, my_proposed_changes)
  end

  private

  # Partition MappingDetective subclasses out of the normal detective pool
  # and select exactly one based on the direction needed.
  # This prevents circularity: if both mapping detectives were in the pool,
  # each one's INPUTS would pull the other in transitively during the
  # backward search in filter_needed_detectives.
  # @param needed [Set<Symbol>] output fields needed (nil means all)
  # @return [Array(Array<Class>, Class, nil)] [pool, selected_mapping_class]
  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength
  def partition_mapping_detective(needed)
    pool = []
    candidates = []
    @detectives.each do |d|
      (d < MappingDetective && d::OUTPUTS.any? ? candidates : pool) << d
    end
    return [pool, nil] if candidates.empty?

    filling_baseline = needed.nil? ||
                       needed.any? { |f| f.to_s.start_with?('osps_') }
    selected =
      candidates.find do |d|
        d::OUTPUTS.any? { |f| f.to_s.start_with?('osps_') } == filling_baseline
      end
    [pool, selected]
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength

  # Check if repo_files is available (HowAccessRepoFilesDetective ran)
  def repo_files_available?
    @evidence.project.repo_url.present?
  end
end
# rubocop:enable Metrics/ClassLength
