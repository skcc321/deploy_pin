require 'test_helper'

class DeployPin::Collector::Test < ActiveSupport::TestCase
  DeployPin.setup do
    tasks_path 'tmp/deploy_pin/'
    groups ["I", "II", "III"]
    fallback_group "I"
  end

  collector = DeployPin::Collector.new(groups: [DeployPin.fallback_group])

  test "files" do
    assert_nothing_raised do
      collector.files
    end
  end

  test "tasks" do
    assert_nothing_raised do
      collector.tasks
    end
  end

  test "run" do
    assert_nothing_raised do
      collector.run
    end
  end

  test "list" do
    assert_nothing_raised do
      collector.list
    end
  end
end
