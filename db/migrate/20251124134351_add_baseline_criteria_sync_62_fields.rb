# frozen_string_literal: true

# Auto-generated migration from baseline criteria sync
# Generated at: 2025-11-24T13:43:51-05:00
# Source: criteria/baseline_criteria.yml
# Mapping: config/baseline_field_mapping.json

class AddBaselineCriteriaSync62Fields < ActiveRecord::Migration[8.0]
  def change

    # baseline-1 criteria (24 criteria)
    add_column :projects, :osps_ac_01_01_status, :string, default: '?'
    add_column :projects, :osps_ac_01_01_justification, :text
    add_column :projects, :osps_ac_02_01_status, :string, default: '?'
    add_column :projects, :osps_ac_02_01_justification, :text
    add_column :projects, :osps_ac_03_01_status, :string, default: '?'
    add_column :projects, :osps_ac_03_01_justification, :text
    add_column :projects, :osps_ac_03_02_status, :string, default: '?'
    add_column :projects, :osps_ac_03_02_justification, :text
    add_column :projects, :osps_br_01_01_status, :string, default: '?'
    add_column :projects, :osps_br_01_01_justification, :text
    add_column :projects, :osps_br_01_02_status, :string, default: '?'
    add_column :projects, :osps_br_01_02_justification, :text
    add_column :projects, :osps_br_03_01_status, :string, default: '?'
    add_column :projects, :osps_br_03_01_justification, :text
    add_column :projects, :osps_br_03_02_status, :string, default: '?'
    add_column :projects, :osps_br_03_02_justification, :text
    add_column :projects, :osps_br_07_01_status, :string, default: '?'
    add_column :projects, :osps_br_07_01_justification, :text
    add_column :projects, :osps_do_01_01_status, :string, default: '?'
    add_column :projects, :osps_do_01_01_justification, :text
    add_column :projects, :osps_do_02_01_status, :string, default: '?'
    add_column :projects, :osps_do_02_01_justification, :text
    add_column :projects, :osps_gv_02_01_status, :string, default: '?'
    add_column :projects, :osps_gv_02_01_justification, :text
    add_column :projects, :osps_gv_03_01_status, :string, default: '?'
    add_column :projects, :osps_gv_03_01_justification, :text
    add_column :projects, :osps_le_02_01_status, :string, default: '?'
    add_column :projects, :osps_le_02_01_justification, :text
    add_column :projects, :osps_le_02_02_status, :string, default: '?'
    add_column :projects, :osps_le_02_02_justification, :text
    add_column :projects, :osps_le_03_01_status, :string, default: '?'
    add_column :projects, :osps_le_03_01_justification, :text
    add_column :projects, :osps_le_03_02_status, :string, default: '?'
    add_column :projects, :osps_le_03_02_justification, :text
    add_column :projects, :osps_qa_01_01_status, :string, default: '?'
    add_column :projects, :osps_qa_01_01_justification, :text
    add_column :projects, :osps_qa_01_02_status, :string, default: '?'
    add_column :projects, :osps_qa_01_02_justification, :text
    add_column :projects, :osps_qa_02_01_status, :string, default: '?'
    add_column :projects, :osps_qa_02_01_justification, :text
    add_column :projects, :osps_qa_04_01_status, :string, default: '?'
    add_column :projects, :osps_qa_04_01_justification, :text
    add_column :projects, :osps_qa_05_01_status, :string, default: '?'
    add_column :projects, :osps_qa_05_01_justification, :text
    add_column :projects, :osps_qa_05_02_status, :string, default: '?'
    add_column :projects, :osps_qa_05_02_justification, :text
    add_column :projects, :osps_vm_02_01_status, :string, default: '?'
    add_column :projects, :osps_vm_02_01_justification, :text

    # baseline-2 criteria (18 criteria)
    add_column :projects, :osps_ac_04_01_status, :string, default: '?'
    add_column :projects, :osps_ac_04_01_justification, :text
    add_column :projects, :osps_br_02_01_status, :string, default: '?'
    add_column :projects, :osps_br_02_01_justification, :text
    add_column :projects, :osps_br_04_01_status, :string, default: '?'
    add_column :projects, :osps_br_04_01_justification, :text
    add_column :projects, :osps_br_05_01_status, :string, default: '?'
    add_column :projects, :osps_br_05_01_justification, :text
    add_column :projects, :osps_br_06_01_status, :string, default: '?'
    add_column :projects, :osps_br_06_01_justification, :text
    add_column :projects, :osps_do_06_01_status, :string, default: '?'
    add_column :projects, :osps_do_06_01_justification, :text
    add_column :projects, :osps_gv_01_01_status, :string, default: '?'
    add_column :projects, :osps_gv_01_01_justification, :text
    add_column :projects, :osps_gv_01_02_status, :string, default: '?'
    add_column :projects, :osps_gv_01_02_justification, :text
    add_column :projects, :osps_gv_03_02_status, :string, default: '?'
    add_column :projects, :osps_gv_03_02_justification, :text
    add_column :projects, :osps_le_01_01_status, :string, default: '?'
    add_column :projects, :osps_le_01_01_justification, :text
    add_column :projects, :osps_qa_03_01_status, :string, default: '?'
    add_column :projects, :osps_qa_03_01_justification, :text
    add_column :projects, :osps_qa_06_01_status, :string, default: '?'
    add_column :projects, :osps_qa_06_01_justification, :text
    add_column :projects, :osps_sa_01_01_status, :string, default: '?'
    add_column :projects, :osps_sa_01_01_justification, :text
    add_column :projects, :osps_sa_02_01_status, :string, default: '?'
    add_column :projects, :osps_sa_02_01_justification, :text
    add_column :projects, :osps_sa_03_01_status, :string, default: '?'
    add_column :projects, :osps_sa_03_01_justification, :text
    add_column :projects, :osps_vm_01_01_status, :string, default: '?'
    add_column :projects, :osps_vm_01_01_justification, :text
    add_column :projects, :osps_vm_03_01_status, :string, default: '?'
    add_column :projects, :osps_vm_03_01_justification, :text
    add_column :projects, :osps_vm_04_01_status, :string, default: '?'
    add_column :projects, :osps_vm_04_01_justification, :text

    # baseline-3 criteria (20 criteria)
    add_column :projects, :osps_ac_04_02_status, :string, default: '?'
    add_column :projects, :osps_ac_04_02_justification, :text
    add_column :projects, :osps_br_02_02_status, :string, default: '?'
    add_column :projects, :osps_br_02_02_justification, :text
    add_column :projects, :osps_br_07_02_status, :string, default: '?'
    add_column :projects, :osps_br_07_02_justification, :text
    add_column :projects, :osps_do_03_01_status, :string, default: '?'
    add_column :projects, :osps_do_03_01_justification, :text
    add_column :projects, :osps_do_03_02_status, :string, default: '?'
    add_column :projects, :osps_do_03_02_justification, :text
    add_column :projects, :osps_do_04_01_status, :string, default: '?'
    add_column :projects, :osps_do_04_01_justification, :text
    add_column :projects, :osps_do_05_01_status, :string, default: '?'
    add_column :projects, :osps_do_05_01_justification, :text
    add_column :projects, :osps_gv_04_01_status, :string, default: '?'
    add_column :projects, :osps_gv_04_01_justification, :text
    add_column :projects, :osps_qa_02_02_status, :string, default: '?'
    add_column :projects, :osps_qa_02_02_justification, :text
    add_column :projects, :osps_qa_04_02_status, :string, default: '?'
    add_column :projects, :osps_qa_04_02_justification, :text
    add_column :projects, :osps_qa_06_02_status, :string, default: '?'
    add_column :projects, :osps_qa_06_02_justification, :text
    add_column :projects, :osps_qa_06_03_status, :string, default: '?'
    add_column :projects, :osps_qa_06_03_justification, :text
    add_column :projects, :osps_qa_07_01_status, :string, default: '?'
    add_column :projects, :osps_qa_07_01_justification, :text
    add_column :projects, :osps_sa_03_02_status, :string, default: '?'
    add_column :projects, :osps_sa_03_02_justification, :text
    add_column :projects, :osps_vm_04_02_status, :string, default: '?'
    add_column :projects, :osps_vm_04_02_justification, :text
    add_column :projects, :osps_vm_05_01_status, :string, default: '?'
    add_column :projects, :osps_vm_05_01_justification, :text
    add_column :projects, :osps_vm_05_02_status, :string, default: '?'
    add_column :projects, :osps_vm_05_02_justification, :text
    add_column :projects, :osps_vm_05_03_status, :string, default: '?'
    add_column :projects, :osps_vm_05_03_justification, :text
    add_column :projects, :osps_vm_06_01_status, :string, default: '?'
    add_column :projects, :osps_vm_06_01_justification, :text
    add_column :projects, :osps_vm_06_02_status, :string, default: '?'
    add_column :projects, :osps_vm_06_02_justification, :text
  end
end
