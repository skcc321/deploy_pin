class CreateDeployPins < ActiveRecord::Migration[5.2]
  def change
    create_table :deploy_pins do |t|
      t.string :uuid
      t.timestamps
    end
  end
end
