# frozen_string_literal: true

class AddCrmFieldsToCandidates < ActiveRecord::Migration[7.1]
  def change
    add_column :candidates, :in_crm, :boolean, default: false, null: false
    add_column :candidates, :resume_text, :text

    add_index :candidates, :in_crm
  end
end
