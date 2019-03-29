require 'test_helper'
require 'generators/deploy_pin/task/task_generator'

class DeployPin::TaskGeneratorTest < Rails::Generators::TestCase
  DeployPin.setup do
    tasks_path 'tmp/deploy_pin/'
    groups ["I", "II", "III"]
    fallback_group "I"
  end

  tests DeployPin::TaskGenerator
  destination Rails.root.join('tmp/generators')
  setup :prepare_destination

  test "generator runs without errors" do
    assert_nothing_raised do
      run_generator ["I"]
    end
  end
end
