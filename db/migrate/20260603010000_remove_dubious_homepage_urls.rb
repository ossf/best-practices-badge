# frozen_string_literal: true

# Copyright the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'security_utils'

class RemoveDubiousHomepageUrls < ActiveRecord::Migration[8.1]
  # This migration identifies and clears 'dubious' homepage URLs (e.g. IPs)
  # while preserving them in the project description.
  # This ensures data quality and aligns with the new 'Domain Only' policy.
  # It only clears the homepage_url if a repo_url is also present.

  def up
    say_with_time 'Removing dubious homepage URLs' do
      count = 0
      Project.find_each do |project|
        homepage = project.homepage_url
        repo = project.repo_url

        # We only clear homepage if BOTH are present and homepage is dubious
        next unless homepage.present? && repo.present?
        next unless SecurityUtils.dubious_url?(homepage)

        # Preserve the old URL in the description
        new_description = project.description || ''
        new_description += "\n\nOld homepage_url: #{homepage}"

        # Use update_columns to bypass validations and callbacks for existing data
        project.update_columns(
          homepage_url: '',
          description: new_description
        )
        count += 1
      end
      say "Cleared #{count} dubious homepage URLs", :subitem
    end
  end

  def down
    # Do not want to raise ActiveRecord::IrreversibleMigration
    nil # intentionally do nothing
  end
end
