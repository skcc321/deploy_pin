# frozen_string_literal: true

class CreateDeployPins < ActiveRecord::Migration<%= migration_version %>
  def change
    create_table :deploy_pins do |t|
      t.string :uuid
      t.integer :progress, default: 0
      t.datetime :completed_at, default: nil
      t.timestamps
    end
  end
end
