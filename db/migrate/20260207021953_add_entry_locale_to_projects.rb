# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

class AddEntryLocaleToProjects < ActiveRecord::Migration[8.1]
  def up
    add_column :projects, :entry_locale, :string,
               limit: 7, default: 'en', null: false,
               comment: 'Locale of project description and justification text'
  end

  def down
    remove_column :projects, :entry_locale
  end
end
