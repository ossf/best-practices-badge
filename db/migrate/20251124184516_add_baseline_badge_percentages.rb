class AddBaselineBadgePercentages < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :badge_percentage_baseline_1, :integer
    add_column :projects, :badge_percentage_baseline_2, :integer
    add_column :projects, :badge_percentage_baseline_3, :integer
    add_column :projects, :achieved_baseline_1_at, :datetime
    add_column :projects, :achieved_baseline_2_at, :datetime
    add_column :projects, :achieved_baseline_3_at, :datetime
    add_column :projects, :lost_baseline_1_at, :datetime
    add_column :projects, :lost_baseline_2_at, :datetime
    add_column :projects, :lost_baseline_3_at, :datetime
  end
end
