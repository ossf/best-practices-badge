# frozen_string_literal: true

# Copyright OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

class CreateBadPasswords < ActiveRecord::Migration[5.2]
  def change
    create_table(:bad_passwords, id: false) do |t|
      t.string :forbidden
      t.index :forbidden
      # t.timestamps not included - not needed here
    end
  end
end
