# frozen_string_literal: true

require 'test_helper'
require 'generators/deploy_pin/upgrade/upgrade_generator'

class DeployPin::UpgradeGeneratorTest < Rails::Generators::TestCase
  tests DeployPin::UpgradeGenerator
  destination Rails.root.join('tmp/generators')
  setup :prepare_destination
  setup { skip 'requires ActiveRecord' unless DeployPin::Database.available? }

  test 'creates the upgrade migration' do
    run_generator

    assert_migration 'db/migrate/upgrade_deploy_pins.rb', /add_column :deploy_pins, :progress/
  end

  test 'uses sequential migration numbers when timestamped migrations are off' do
    ActiveRecord.stub(:timestamped_migrations, false) { run_generator }

    assert_file 'db/migrate/001_upgrade_deploy_pins.rb'
  end

  test 'rails destroy removes the migration' do
    run_generator
    run_generator [], behavior: :revoke

    assert_no_migration 'db/migrate/upgrade_deploy_pins.rb'
  end
end
