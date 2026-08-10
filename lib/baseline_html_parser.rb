# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# This script runs standalone outside of Rails, so ActiveSupport extensions
# like String#exclude? are unavailable. Use String#include? instead.
# rubocop:disable Style/InvertibleUnlessCondition

require 'nokogiri'

# Parses an OpenSSF Baseline HTML page to extract OSPS criteria controls.
# Locates every <h4> whose HTML id begins with "osps-", reads the text
# content following each heading up to the next heading, and extracts the
# control's requirement, recommendation, category, and maturity level.
# Retired controls (those containing "Retired" text but no "Requirement:"
# section) are excluded from the results.
class BaselineHtmlParser
  # @return [Array<Hash>] parsed controls, each with keys:
  #   :original_id (String), :field_name (String), :category (String),
  #   :requirement (String, nil), :recommendation (String, nil),
  #   :maturity_level (Array<Integer>)
  attr_reader :controls

  # HTML element names to stop at when parsing control content
  STOP_ELEMENTS = %w[h3 h4].freeze

  # @param html_content [String] raw HTML of the OpenSSF Baseline spec page
  def initialize(html_content)
    @doc = Nokogiri::HTML(html_content)
    @controls = []
  end

  # Parses all <h4 id="osps-*"> control elements from the HTML and
  # populates {#controls}. Retired controls (those containing "Retired"
  # text but lacking a "Requirement:" section) are skipped.
  # @return [Array<Hash>] same as {#controls}
  def parse
    # Find all h4 elements with IDs starting with "osps-"
    @doc.css('h4[id^="osps-"]').each do |h4|
      control = parse_control(h4)
      @controls << control if control
    end
    @controls
  end

  private

  # rubocop:disable Metrics/MethodLength
  def parse_control(h4_element)
    original_id = h4_element.text.strip
    return if original_id.empty?

    # Get all content until next h4 or h3
    content_elements = []
    current = h4_element.next_element
    while current && !STOP_ELEMENTS.include?(current.name)
      content_elements << current
      current = current.next_element
    end

    # Skip retired criteria — upstream marks them "Retired in ..." with no
    # Requirement text. Returning nil excludes the control so the extraction
    # script's obsolete-detection logic flags it correctly.
    return if retired?(content_elements)

    # Extract requirement, recommendation, and other details
    requirement = extract_requirement(content_elements)
    recommendation = extract_recommendation(content_elements)
    category = extract_category(h4_element)
    maturity_level = extract_maturity_level(content_elements)

    {
      original_id: original_id,
      field_name: id_to_field_name(original_id),
      category: category,
      requirement: requirement,
      recommendation: recommendation,
      maturity_level: maturity_level
    }
  end
  # rubocop:enable Metrics/MethodLength

  def extract_requirement(elements)
    elements.each do |el|
      next unless el.text.include?('Requirement:')

      # Extract text after "Requirement:" removing the bold tag
      text = el.text.sub(/.*Requirement:\s*/, '').strip
      return clean_text(text)
    end
    nil
  end

  def extract_recommendation(elements)
    elements.each do |el|
      if el.text.include?('Recommendation:')
        text = el.text.sub(/.*Recommendation:\s*/, '').strip
        return clean_text(text)
      end
    end
    nil
  end

  def extract_category(h4_element)
    # Look for parent section to determine category
    parent_section = h4_element.ancestors('h2, h3').first
    return 'General' unless parent_section

    parent_section.text.strip
  end

  def extract_maturity_level(elements)
    # Look for "Control applies to:" and find maturity level
    elements.each do |el|
      next unless el.text.include?('Control applies to:')

      # Look at next element which typically has the level list
      next_el = el.next_element
      next unless next_el&.name == 'ul'

      # Extract maturity levels from list items
      levels =
        next_el.css('li').filter_map do |li|
          text = li.text
          ::Regexp.last_match(1).to_i if text =~ /Maturity Level (\d+)/
        end
      return levels unless levels.empty?
    end
    [1] # Default to level 1
  end

  def retired?(elements)
    elements.none? { |el| el.text.include?('Requirement:') } &&
      elements.any? { |el| el.text.match?(/Retired/i) }
  end

  def id_to_field_name(original_id)
    # Transform OSPS-GV-03.01 to osps_gv_03_01
    original_id
      .downcase
      .tr('-', '_')
      .tr('.', '_')
  end

  def clean_text(text)
    # Remove extra whitespace, normalize line breaks
    text
      .gsub(/\s+/, ' ')
      .squeeze("\n")
      .strip
  end
end
# rubocop:enable Style/InvertibleUnlessCondition
