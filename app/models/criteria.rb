# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# rubocop:disable Metrics/ClassLength
class Criteria
  include ActiveModel::Model
  include LevelConversion # Shared level name/number conversion

  ACCESSORS = %i[
    name category level future obsolete
    rationale autofill
    met_suppress na_suppress unmet_suppress
    met_justification_required met_url_required met_url
    na_allowed na_justification_required
    major minor unmet
  ].freeze

  LOCALE_ACCESSORS = %i[
    description details met_placeholder unmet_placeholder na_placeholder
  ].freeze

  FIELDS_TO_OMIT = %w[description details rationale autofill].freeze

  attr_accessor(*ACCESSORS)

  class << self
    # Class methods
    include Enumerable

    # Retrieves criteria for a specific level.
    # @param key [String, Symbol] the criteria level key
    # @return [Hash] criteria hash for the specified level
    def [](key)
      instantiate if @criteria.blank?
      @criteria[key]
    end

    # Returns active (non-future) criteria for a specific level.
    # @param level [String, Integer] the badge level
    # @return [Array<Criteria>] array of active criteria for the level
    def active(level)
      instantiate if @criteria.blank?
      @active ||= {}
      @active[level] ||=
        @criteria[level].values.reject { |c| c.future? || c.obsolete? }
    end

    # Returns all unique criteria names across all levels.
    # @return [Array<Symbol>] array of all criteria names
    def all
      instantiate if @criteria.blank?
      @criteria.values.map(&:keys).flatten.uniq
    end

    # Iterates over each [level, criteria_hash] pair.
    # @yield [Array(String, Hash)] level key and its criteria hash
    # @return [void]
    def each
      instantiate if @criteria.blank?
      @criteria.each { |level| yield level }
    end

    # Iterates over each level's criteria hash.
    # @yield [Hash] criteria hash for one level
    # @return [void]
    def each_value
      instantiate if @criteria.blank?
      @criteria.each_value { |level_data| yield level_data }
    end

    # No longer needed. Instead use "Project::LEVEL_IDS.each"
    # def each_key
    #   instantiate if @criteria.blank?
    #   @criteria.each_key { |level_key| yield level_key }
    # end

    # Returns all levels where a particular criterion is present.
    # @param criterion [String, Symbol] the criterion name
    # @return [Array<String>] array of levels containing this criterion
    def get_levels(criterion)
      instantiate if @criteria.blank?
      @criteria_levels[criterion]
    end

    # Creates class instances from CriteriaHash on first use.
    # Populates @criteria and @criteria_levels class variables.
    # @return [void]
    def instantiate
      # Creates class instances on first use and after reload! in rails console
      CriteriaHash.each do |level, level_hash|
        level_hash.each do |criterion|
          name = criterion.first.to_sym
          ((@criteria ||= {})[level] ||= {})[name] =
            new({ name: name, level: level }.merge(criterion[1]))
          ((@criteria_levels ||= {})[name] ||= []).append(level)
        end
      end
    end

    # Returns all level keys defined in the criteria.
    # @return [Array<String>] level keys, e.g. ['passing', 'silver', 'gold']
    def keys
      instantiate if @criteria.blank?
      @criteria.keys
    end

    # Returns the raw CriteriaHash used to populate criteria instances.
    # @return [Hash] the underlying criteria data hash
    def to_h
      CriteriaHash
    end

    # Returns criteria data formatted for JavaScript consumption,
    # with locale-keyed translations merged into each criterion's fields.
    # @return [Hash] criteria hash with translated fields per available locale
    # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    def for_js
      CriteriaHash.deep_dup.each do |level, criteria_set|
        criteria_set.each do |criterion, fields|
          fields.delete_if { |k, _v| k.in? FIELDS_TO_OMIT }
          translations = {}
          I18n.available_locales.each do |locale|
            # Get criterion keys; works with flat and nested I18n backends
            criterion_keys = get_criterion_keys(level, criterion, locale)
            criterion_keys.each do |k|
              next if k.to_s.in? FIELDS_TO_OMIT

              translations[k.to_s] = {} unless translations.key?(k.to_s)
              translations[k.to_s][locale.to_s] =
                I18n.t(".criteria.#{level}.#{criterion}.#{k}", locale: locale)
            end
          end
          fields.update(translations)
        end
      end
    end
    # rubocop:enable Metrics/AbcSize,Metrics/MethodLength

    # Get list of field keys for a criterion.
    # Works with both nested and flat backends.
    # @param level [String] the criteria level
    # @param criterion [String] the criterion name
    # @param locale [Symbol] the locale to query
    # @return [Array<Symbol>] list of field keys
    def get_criterion_keys(level, criterion, locale = :en)
      path = "criteria.#{level}.#{criterion}"
      # Try traditional nested backend approach first
      result = I18n.t(".#{path}", locale: locale, default: nil)
      return result.keys if result.is_a?(Hash)

      # For flat backends, use the backend's nested_hash method
      backend = I18n.backend
      return [] unless backend.respond_to?(:nested_hash)

      nested = backend.nested_hash(locale, path)
      nested ? nested.keys.sort : []
    end
  end

  # Returns the localized description for this criterion.
  # @return [String, nil] HTML-safe description text or nil if not found
  def description
    key = "criteria.#{level}.#{name}.description"
    return unless I18n.exists?(key)

    # Descriptions only come from trusted data source, so we can safely disable
    # rubocop:disable Rails/OutputSafety
    I18n.t(key).html_safe
    # rubocop:enable Rails/OutputSafety
  end

  # Returns the localized details for this criterion.
  # @return [String, nil] HTML-safe details text or nil if not found
  def details
    get_text_if_exists(:details)
  end

  delegate :present?, to: :details, prefix: true

  # Checks if this criterion is marked as future (not yet active).
  # @return [Boolean] true if criterion is for future implementation
  def future?
    future == true
  end

  # Checks if this criterion is marked as obsolete (retired from upstream).
  # @return [Boolean] true if criterion has been retired
  def obsolete?
    obsolete == true
  end

  # Creates a new Criteria instance and freezes it for immutability.
  # @param parameters [Array] initialization parameters
  def initialize(*parameters)
    super
    # Precompute symbol names before freezing (performance optimization)
    @status_symbol = :"#{name}_status"
    @justification_symbol = :"#{name}_justification"
    # Precompute string representation to avoid repeated allocations
    @to_s = name.to_s.freeze
    freeze
  end

  # Checks if a URL is required in the justification for 'Met' status.
  # @return [Boolean] true if URL is required for Met justification
  def met_url_required?
    met_url_required == true
  end

  # Checks if justification text is required for 'Met' status.
  # @return [Boolean] true if justification is required for Met status
  def met_justification_required?
    met_justification_required == true
  end

  # Checks if Met status requires either justification text or a URL.
  # @return [Boolean] true if justification or URL is required for Met status
  def met_justification_or_url_required?
    met_justification_required? || met_url_required?
  end

  # Checks if this criterion has MUST-level obligation.
  # @return [Boolean] true if category is 'MUST'
  def must?
    category == 'MUST'
  end

  # Checks if N/A is a permitted status for this criterion.
  # @return [Boolean] true if N/A status is allowed
  def na_allowed?
    na_allowed == true
  end

  # Checks if justification text is required when status is N/A.
  # @return [Boolean] true if justification is required for N/A status
  def na_justification_required?
    na_justification_required == true
  end

  # Checks if this criterion has SHOULD-level obligation.
  # @return [Boolean] true if category is 'SHOULD'
  def should?
    category == 'SHOULD'
  end

  # Checks if this criterion has SUGGESTED-level obligation.
  # @return [Boolean] true if category is 'SUGGESTED'
  def suggested?
    category == 'SUGGESTED'
  end

  # Returns the database field symbol for this criterion's status
  # Precomputed at initialization to avoid per-render string concatenation
  # @return [Symbol] e.g., :description_good_status
  attr_reader :status_symbol

  # Returns the database field symbol for this criterion's justification
  # Precomputed at initialization to avoid per-render string concatenation
  # @return [Symbol] e.g., :description_good_justification
  attr_reader :justification_symbol

  # Returns the string representation of this criterion's name
  # Precomputed during initialization to avoid repeated allocations
  # @return [String] frozen string representation
  attr_reader :to_s

  private

  # This method is used to grab text that is the same regardless of
  # criteria level. For example details of a criterion is almost always the
  # same across criteria levels.  This routine searches the current level
  # and all lower levels for a given text snippet until it is found.  If
  # it doesn't exist, nil is returned.
  def get_text_if_exists(field)
    return unless field.in? LOCALE_ACCESSORS

    Criteria.get_levels(name).reverse_each do |l|
      # Compare levels using mapping, not .to_i
      next if level_higher?(l, level)

      t_key = "criteria.#{l}.#{name}.#{field}"
      # Disable HTML output safety. I18n translations are internal data
      # and are considered a trusted source.
      # rubocop:disable Rails/OutputSafety
      return I18n.t(t_key).html_safe if I18n.exists?(t_key)
      # rubocop:enable Rails/OutputSafety
    end
    nil
  end

  # Returns true if level1 is higher than level2
  def level_higher?(level1, level2)
    level_num1 = level_to_number(level1)
    level_num2 = level_to_number(level2)
    level_num1 > level_num2
  end
end
# rubocop:enable Metrics/ClassLength
