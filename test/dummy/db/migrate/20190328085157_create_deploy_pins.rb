# frozen_string_literal: true

class CreateDeployPins < ActiveRecord::Migration[7.0]
  def change
    create_table :deploy_pins do |t|
      t.string :uuid
      t.timestamps
    end
  end
end
