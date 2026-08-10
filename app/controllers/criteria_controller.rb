# frozen_string_literal: true

# Copyright 2020-, the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Controller for criteria functionality.
#
class CriteriaController < ApplicationController
  # Cache these "unchanging" pages on the CDN for anonymous users (output does
  # not change until the next deploy). index/show only read URL-derived params
  # (no mutable DB state) and issue no internal redirect. Query-string variants
  # (?details=, etc.) are distinct cache objects under Fastly's URL-based key
  # and all share UNCHANGING_SURROGATE_KEY.
  # See docs/cdn-cache-not-logged-in.md Section 10.
  before_action :cache_unchanging_page_on_cdn, only: %i[index show]

  # Displays list of resources.
  # @return [void]
  def index
    set_params
  end

  # Displays individual resource details.
  # @return [void]
  def show
    set_criteria_level
    set_params
  end

  private

  # Sets criteria_level value.
  # @return [void]
  def set_criteria_level
    level_param = params[:criteria_level] || '0'
    @criteria_level = normalize_criteria_level(level_param)
  end

  # Set user-provided parameters (other than criteria_level)
  def set_params
    @details = boolean_param(:details, false)
    @rationale = boolean_param(:rationale, false)
    @autofill = boolean_param(:autofill, false)
  end

  # Convert user-provided parameter "name" into true/false.
  # This is untrusted input, be cautious with it. scalar_param yields the
  # default (nil here) for an absent, bare, or non-scalar value (e.g.
  # ?details[]=1, which Rails parses into an Array); without that guard,
  # calling casecmp? on a non-String would raise, turning a crafted query
  # string into an unhandled 500 on this public, unauthenticated page.
  # @param name [Symbol] The parameter name to read
  # @param default_value [Object] The value to use when the param is absent
  #   or is not a simple string
  # @return [Boolean]
  def boolean_param(name, default_value = true)
    value = scalar_param(name)
    return default_value if value.nil?

    value.casecmp?('true') || value == '1'
  end
end
