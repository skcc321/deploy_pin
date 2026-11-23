# frozen_string_literal: true

require 'test_helper'
require 'generators/deploy_pin/install/install_generator'

class DeployPin::InstallGeneratorTest < Rails::Generators::TestCase
  tests DeployPin::InstallGenerator
  destination Rails.root.join('tmp/generators')
  setup :prepare_destination

  test 'generator runs without errors' do
    skip 'requires ActiveRecord' unless DeployPin::Database.available?

    assert_nothing_raised do
      run_generator ['I']
    end

    assert_migration 'db/migrate/create_deploy_pins.rb'
    assert_file 'config/initializers/deploy_pin.rb' do |content|
      assert_no_match(/storage/, content)
    end
  end

  test 'generator with mongoid storage skips the migration' do
    run_generator ['--storage=mongoid']

    assert_no_migration 'db/migrate/create_deploy_pins.rb'
    assert_file 'config/initializers/deploy_pin.rb', /storage :mongoid/
  end
end
