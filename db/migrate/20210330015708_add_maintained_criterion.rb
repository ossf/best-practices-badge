# frozen_string_literal: true

# Copyright OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

class AddMaintainedCriterion < ActiveRecord::Migration[6.1]
  def change
    # This "status" has the *very* unusual default value 'Met'.
    # We assume that, barring any other information, a project that is
    # working to earn a badge is being maintained (since it is actively
    # thinking about improvement), and thus it is Met by default.
    add_column :projects, :maintained_status, :string,
               null: false, default: 'Met'
    add_column :projects, :maintained_justification, :text

    # We have a different number of passing criteria, so we need to
    # recalculate all project percentages at that level.
    # This takes about 1 minute 36 seconds on my development machine.
    Project.update_all_badge_percentages(['0'])
  end
end
