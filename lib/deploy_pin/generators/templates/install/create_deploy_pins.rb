# frozen_string_literal: true

class CreateDeployPins < <%= activerecord_migration_class %>
  def change
    create_table :deploy_pins do |t|
      t.string :uuid
      t.integer :progress, default: 0
      t.datetime :completed_at, default: nil
      t.timestamps
    end
  end
end
