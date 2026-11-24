# frozen_string_literal: true

require 'test_helper'
require 'generators/deploy_pin/install/install_generator'

class DeployPin::InstallGeneratorTest < Rails::Generators::TestCase
  tests DeployPin::InstallGenerator
  destination Rails.root.join('tmp/generators')
  setup :prepare_destination

  test 'creates the initializer and the migration' do
    run_generator

    assert_migration 'db/migrate/create_deploy_pins.rb', /class CreateDeployPins < ActiveRecord::Migration\[\d+\.\d+\]/
    assert_file 'config/initializers/deploy_pin.rb' do |content|
      assert_no_match(/storage/, content)
      assert_match 'statement_timeout 10.minutes', content
    end
    assert_no_file 'config/deploy_pin.rb'
  end

  test 'generator with mongoid storage skips the migration' do
    output = run_generator ['--storage=mongoid']

    assert_no_migration 'db/migrate/create_deploy_pins.rb'
    assert_file 'config/initializers/deploy_pin.rb', /storage :mongoid/
    assert_match 'rails db:mongoid:create_indexes', output
  end

  test 'takes the options of the DeployPin generator' do
    run_generator %w[--config-path=config/deploy_pin.rb --migrations-path=db/other]

    assert_file 'config/deploy_pin.rb'
    assert_migration 'db/other/create_deploy_pins.rb'
  end

  test 'fails when the migration exists, unless --skip or --force' do
    run_generator

    error = capture(:stderr) { run_generator }
    assert_match 'Another migration is already named create_deploy_pins', error

    run_generator ['--force']
    assert_equal 1, Dir[File.join(destination_root, 'db/migrate/*_create_deploy_pins.rb')].size
  end

  test 'rails destroy removes the initializer and the migration' do
    run_generator
    run_generator [], behavior: :revoke

    assert_no_migration 'db/migrate/create_deploy_pins.rb'
    assert_no_file 'config/initializers/deploy_pin.rb'
  end

  test 'its help comes from USAGE' do
    assert_match 'rails generate deploy_pin:install', DeployPin::InstallGenerator.desc
  end
end
