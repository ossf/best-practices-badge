# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

module SymbolRefinements
  refine Symbol do
    # Returns the status field symbol for this criterion name.
    # @return [Symbol] e.g. :description_good_status
    def status
      :"#{self}_status"
    end

    # Returns the justification field symbol for this criterion name.
    # @return [Symbol] e.g. :description_good_justification
    def justification
      :"#{self}_justification"
    end
  end
end
