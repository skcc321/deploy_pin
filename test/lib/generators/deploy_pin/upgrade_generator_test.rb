# frozen_string_literal: true

require 'test_helper'
require 'generators/deploy_pin/upgrade/upgrade_generator'

class DeployPin::UpgradeGeneratorTest < Rails::Generators::TestCase
  tests DeployPin::UpgradeGenerator
  destination Rails.root.join('tmp/generators')
  setup :prepare_destination

  test 'generator runs without errors' do
    assert_nothing_raised do
      run_generator ['I']
    end
  end
end
