# frozen_string_literal: true

# Add first_achieved_at timestamps for baseline levels
class AddFirstAchievedBaselineFields < ActiveRecord::Migration[8.0]
  def change
    change_table :projects, bulk: true do |t|
      t.datetime :first_achieved_baseline_1_at,
                 comment: 'First time baseline-1 was achieved'
      t.datetime :first_achieved_baseline_2_at,
                 comment: 'First time baseline-2 was achieved'
      t.datetime :first_achieved_baseline_3_at,
                 comment: 'First time baseline-3 was achieved'
    end
  end
end
