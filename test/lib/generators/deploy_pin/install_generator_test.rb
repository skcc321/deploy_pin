require 'test_helper'
require 'generators/deploy_pin/install/install_generator'

class DeployPin::InstallGeneratorTest < Rails::Generators::TestCase
  tests DeployPin::InstallGenerator
  destination Rails.root.join('tmp/generators')
  setup :prepare_destination

  test "generator runs without errors" do
    assert_nothing_raised do
      run_generator ["I"]
    end
  end
end
