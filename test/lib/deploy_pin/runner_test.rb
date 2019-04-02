require 'test_helper'

class DeployPin::Runner::Test < ActiveSupport::TestCase
  setup do
    DeployPin.setup do
      tasks_path './tmp/'
      groups ["I", "II", "III"]
      fallback_group "I"
    end

    # clean
    DeployPin::Record.delete_all
    FileUtils.rm_rf("#{DeployPin.tasks_path}/.", secure: true)

    # copy files
    FileUtils.cp 'test/support/files/task.rb', "#{DeployPin.tasks_path}taska.rb"
    FileUtils.cp 'test/support/files/task_different.rb', "#{DeployPin.tasks_path}taskb.rb"
    FileUtils.cp 'test/support/files/task_same.rb', "#{DeployPin.tasks_path}taskc.rb"
  end

  test "sumary" do
    assert_nothing_raised do
      DeployPin::Runner.summary(groups: [DeployPin.fallback_group])
    end
  end

  test "run" do
    assert_nothing_raised do
      DeployPin::Runner.run(groups: DeployPin.groups)
    end
  end

  test "list" do
    assert_nothing_raised do
      DeployPin::Runner.list(groups: [DeployPin.fallback_group])
    end
  end

  teardown do
    # clean
    DeployPin::Record.delete_all
    FileUtils.rm_rf("#{DeployPin.tasks_path}/.", secure: true)
  end
end
