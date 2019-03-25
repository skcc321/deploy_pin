class CreateDoubleDouble < ActiveRecord::Migration[5.2]
  def change
    create_table :deploy_pins do |t|
      t.uuid
      t.timestamps
    end
  end
end
