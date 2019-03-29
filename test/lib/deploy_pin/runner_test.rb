require 'test_helper'

class DeployPin::Runner::Test < ActiveSupport::TestCase
  DeployPin.setup do
    tasks_path './'
    groups ["I", "II", "III"]
    fallback_group "I"
  end

  DeployPin::Record.delete_all
  FileUtils.cp 'test/support/files/task.rb', "#{DeployPin.tasks_path}/task.rb"

  test "sumary" do
    assert_nothing_raised do
      DeployPin::Runner.summary(groups: [DeployPin.fallback_group])
    end
  end

  test "run" do
    assert_nothing_raised do
      DeployPin::Runner.run(groups: [DeployPin.fallback_group])
    end
  end

  test "list" do
    assert_nothing_raised do
      DeployPin::Runner.list(groups: [DeployPin.fallback_group])
    end
  end
end
