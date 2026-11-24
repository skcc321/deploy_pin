# frozen_string_literal: true

# Upgrades a deploy_pins table created before DeployPin 1.7 (resumable tasks).
# On a table that already has the 1.7 columns it changes nothing.
class UpgradeDeployPins < ActiveRecord::Migration[7.0]
  def up
    add_column :deploy_pins, :progress, :integer, default: 0 unless column_exists?(:deploy_pins, :progress)
    return if column_exists?(:deploy_pins, :completed_at)

    add_column :deploy_pins, :completed_at, :datetime, default: nil
    # Before 1.7 a record was only created when its task completed.
    execute "UPDATE #{quote_table_name(:deploy_pins)} SET completed_at = created_at"
  end

  def down
    remove_column :deploy_pins, :completed_at, if_exists: true
    remove_column :deploy_pins, :progress, if_exists: true
  end
end
