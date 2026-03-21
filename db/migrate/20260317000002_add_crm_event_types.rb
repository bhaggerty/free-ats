# frozen_string_literal: true

class AddCrmEventTypes < ActiveRecord::Migration[7.1]
  # PostgreSQL enum changes cannot run inside a transaction
  disable_ddl_transaction!

  def up
    execute "ALTER TYPE event_type ADD VALUE IF NOT EXISTS 'candidate_added_to_crm'"
    execute "ALTER TYPE event_type ADD VALUE IF NOT EXISTS 'candidate_removed_from_crm'"
  end

  def down
    # PostgreSQL does not support removing enum values without recreating the type
  end
end
