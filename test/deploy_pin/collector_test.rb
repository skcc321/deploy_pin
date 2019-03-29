require 'test_helper'

class DeployPin::Collector::Test < ActiveSupport::TestCase
  DeployPin.setup do
    tasks_path 'tmp/deploy_pin/'
    groups ["I", "II", "III"]
    fallback_group "I"
  end

  collector = DeployPin::Collector.new(groups: [DeployPin.fallback_group])

  test "files" do
    assert_not_nil collector.files
  end

  test "tasks" do
    assert_not_nil collector.tasks
  end

  test "run" do
    assert_not_nil collector.run
  end

  test "list" do
    assert_not_nil collector.list
  end
end
