# frozen_string_literal: true

require 'test_helper'
require 'generators/deploy_pin/install/install_generator'
require 'deploy_pin/generators/install'
require 'tmpdir'

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

  test 'uses timestamped migration numbers by default' do
    run_generator

    migration = File.basename(migration_file_name('db/migrate/create_deploy_pins.rb'))

    assert_match(/\A\d{14}_create_deploy_pins\.rb\z/, migration)
  end

  test 'uses sequential migration numbers when timestamped migrations are off' do
    ActiveRecord.stub(:timestamped_migrations, false) { run_generator }

    assert_file 'db/migrate/001_create_deploy_pins.rb'
  end

  test 'a second run reports the migration as identical' do
    run_generator
    output = run_generator

    assert_match(%r{identical\s+db/migrate/\d+_create_deploy_pins\.rb}, output)
    assert_equal 1, Dir[File.join(destination_root, 'db/migrate/*_create_deploy_pins.rb')].size
  end

  test 'generator with mongoid storage skips the migration' do
    output = run_generator ['--storage=mongoid']

    assert_no_migration 'db/migrate/create_deploy_pins.rb'
    assert_file 'config/initializers/deploy_pin.rb', /storage :mongoid/
    assert_match 'rails db:mongoid:create_indexes', output
  end

  test 'rails destroy removes the initializer and the migration' do
    run_generator
    run_generator [], behavior: :revoke

    assert_no_migration 'db/migrate/create_deploy_pins.rb'
    assert_no_file 'config/initializers/deploy_pin.rb'
  end

  test 'renders the same files as deploy_pin install' do
    run_generator
    Dir.mktmpdir do |cli_root|
      capture(:stdout) { DeployPin::Generators::Install.start([], destination_root: cli_root) }

      assert_equal File.read(File.join(cli_root, 'config/deploy_pin.rb')),
                   File.read(File.join(destination_root, 'config/initializers/deploy_pin.rb'))
      assert_equal File.read(Dir[File.join(cli_root, 'db/migrate/*_create_deploy_pins.rb')].first),
                   File.read(migration_file_name('db/migrate/create_deploy_pins.rb'))
    end
  end
end
