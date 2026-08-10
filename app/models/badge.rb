# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

class Badge
  ACCEPTABLE_PERCENTAGES = (0..99).to_a.freeze

  # Metal series levels: %w[passing silver gold]
  ACCEPTABLE_LEVELS = Sections::METAL_LEVEL_NAMES

  # Baseline series levels: %w[baseline-1 baseline-2 baseline-3]
  ACCEPTABLE_BASELINE_LEVELS = Sections::BASELINE_LEVEL_NAMES

  # Baseline percentage badges: 'baseline-pct-0' through 'baseline-pct-99'
  ACCEPTABLE_BASELINE_PERCENTAGES =
    (0..99).map { |n| "baseline-pct-#{n}" }
           .freeze

  # Make this a set so we can quickly determine if an input is "valid?"
  ACCEPTABLE_INPUTS = (
    ACCEPTABLE_PERCENTAGES + ACCEPTABLE_LEVELS +
    ACCEPTABLE_BASELINE_LEVELS + ACCEPTABLE_BASELINE_PERCENTAGES
  ).to_set.freeze

  # Regex to extract width from SVG content
  SVG_WIDTH_REGEX = /\Awidth="(\d+)"/

  # Directory containing badge SVG files
  BADGE_DIR = 'app/assets/images'

  attr_accessor :svg

  class << self
    # Class methods
    include Enumerable

    # Returns the width of a badge for the given level.
    # Widths are automatically extracted from SVG files on first access.
    # @param level [String, Integer] the badge level
    # @return [Integer, nil] the badge width in pixels, or nil if not found
    def width(level)
      badge_widths[level.to_s]
    end

    # Returns all badge widths, extracting them from SVG files if needed.
    # Results are cached for performance.
    # @return [Hash<String, Integer>] mapping of badge level to width
    def badge_widths
      @badge_widths ||= build_badge_widths
    end

    # Creates and caches Badge instances for the given level.
    # @param level [String, Integer] the badge level (percentage 0-99 or level name)
    # @return [Badge] the badge instance for the specified level
    # @raise [ArgumentError] if level is not valid
    def [](level)
      raise ArgumentError unless valid?(level)

      @badges ||= {}
      @badges[level] ||= new(level)
    end

    # Returns all badge instances for all acceptable levels.
    # Creates badges if they don't exist yet.
    # @return [Array<Badge>] array of all badge instances
    def all
      # 100 percentages + 3 metal + 3 baseline levels + 100 baseline percentages = 206
      create_all unless @badges&.length == 206
      ACCEPTABLE_INPUTS.map { |level| self[level] }
    end

    # Creates badge instances for all acceptable levels.
    # Initializes the internal badges cache.
    # @return [void]
    def create_all
      @badges = {}
      ACCEPTABLE_INPUTS.each { |level| @badges[level] = new(level) }
    end

    # Iterates over all badge instances.
    # Implements Enumerable interface.
    # @yield [Badge] each badge instance
    # @return [Badge] self for method chaining
    def each
      all.each { |badge| yield badge }
      self
    end

    # Checks if the given level is valid for badge creation.
    # @param level [String, Integer] the level to validate
    # @return [Boolean] true if level is acceptable
    def valid?(level)
      ACCEPTABLE_INPUTS.include?(level)
    end

    # Resets cached badge widths. Useful after regenerating badge images.
    # @return [void]
    def reset_widths!
      @badge_widths = nil
    end

    # Returns the file path for a badge level.
    # @param level [String, Integer] the badge level
    # @return [String] the file path
    def svg_path(level)
      level_str = level.to_s
      if level_str.start_with?('baseline-pct-')
        "#{BADGE_DIR}/badge_baseline_pct_#{level_str[13..]}.svg"
      elsif level_str.start_with?('baseline')
        "#{BADGE_DIR}/badge_#{level_str.tr('-', '_')}.svg"
      else
        "#{BADGE_DIR}/badge_static_#{level}.svg"
      end
    end

    private

    # Builds the badge widths hash by reading all SVG files.
    # @return [Hash<String, Integer>] mapping of badge level to width
    def build_badge_widths
      widths = {}
      ACCEPTABLE_INPUTS.each do |level|
        svg_content = read_svg_file(level)
        width = extract_width(svg_content)
        widths[level.to_s] = width if width
      end
      widths.freeze
    end

    # Reads SVG file content for the given level.
    # @param level [String, Integer] the badge level
    # @return [String] the SVG file content
    def read_svg_file(level)
      File.read(svg_path(level))
    rescue Errno::ENOENT
      ''
    end

    # Extracts the width attribute from SVG content.
    # @param svg_content [String] the SVG file content
    # @return [Integer, nil] the width in pixels, or nil if not found
    def extract_width(svg_content)
      # Look for width="NNN" near the start of the SVG
      # Skip the <?xml and <svg opening to find the width attribute
      match = svg_content.match(/width="(\d+)"/)
      match ? match[1].to_i : nil
    end
  end

  # Creates a new Badge instance for the specified level.
  # Loads the corresponding SVG content from static files.
  # @param level [String, Integer] the badge level
  # @raise [ArgumentError] if level is not valid
  def initialize(level)
    raise ArgumentError unless self.class.valid?(level)

    @svg = load_svg(level)
  end

  # Returns the SVG content as a string.
  # @return [String] the badge SVG content
  def to_s
    svg
  end

  private

  # Loads SVG content from the corresponding static file.
  # @param level [String, Integer] the badge level
  # @return [String] the SVG file content or empty string if invalid
  def load_svg(level)
    # Defensive programming: only allow valid levels.
    # This was checked earlier, but we re-check here so we're sure *and*
    # that static analysis tools will know we've checked it.
    return '' unless self.class.valid?(level)

    File.read(self.class.svg_path(level))
  end
end
