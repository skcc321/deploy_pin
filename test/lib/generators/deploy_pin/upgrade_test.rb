# frozen_string_literal: true

require 'test_helper'

class DeployPin::Generators::UpgradeTest < DeployPin::GeneratorTestCase
  test 'creates the upgrade migration' do
    run_generator DeployPin::Generators::Upgrade

    migrations = generated('db/migrate/*_upgrade_deploy_pins.rb')
    assert_equal 1, migrations.size
    assert_match 'class UpgradeDeployPins < ActiveRecord::Migration', read(migrations.first)
    assert_match 'add_column :deploy_pins, :progress', read(migrations.first)
  end

  test 'writes the migration to --migrations-path' do
    run_generator DeployPin::Generators::Upgrade, ['--migrations-path=db/migrations']

    assert_equal 1, generated('db/migrations/*_upgrade_deploy_pins.rb').size
  end

  test 'revoke removes the migration' do
    run_generator DeployPin::Generators::Upgrade
    run_generator DeployPin::Generators::Upgrade, [], behavior: :revoke

    assert_empty generated('db/migrate/*.rb')
  end
end
