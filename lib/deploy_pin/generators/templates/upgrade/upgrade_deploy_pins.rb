# frozen_string_literal: true

class UpgradeDeployPins < ActiveRecord::Migration[7.0]
  def change
    add_column :deploy_pins, :progress, :integer, default: 0, if_not_exists: true
    add_column :deploy_pins, :completed_at, :datetime, default: nil, if_not_exists: true

    # set completed_at to created_at for all completed deploy_pins
    DeployPin::Record.update_all('completed_at = created_at')
  end
end
