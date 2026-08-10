# frozen_string_literal: true

# Auto-generated migration from baseline criteria sync
# Generated at: 2026-02-27T13:00:19-05:00
# Source: criteria/baseline_criteria.yml
# Mapping: config/baseline_field_mapping.json

class AddBaselineCriteriaSync3Fields < ActiveRecord::Migration[8.0]
  def change

    # baseline-1 criteria (1 criteria)
    add_column :projects, :osps_br_01_03_status, :smallint, default: 0, null: false
    add_column :projects, :osps_br_01_03_justification, :text

    # baseline-2 criteria (1 criteria)
    add_column :projects, :osps_do_07_01_status, :smallint, default: 0, null: false
    add_column :projects, :osps_do_07_01_justification, :text

    # baseline-3 criteria (1 criteria)
    add_column :projects, :osps_br_01_04_status, :smallint, default: 0, null: false
    add_column :projects, :osps_br_01_04_justification, :text
  end
end
