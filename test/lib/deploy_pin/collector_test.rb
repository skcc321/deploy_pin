require 'test_helper'

class DeployPin::Collector::Test < ActiveSupport::TestCase
  setup do
    DeployPin.setup do
      tasks_path './tmp/'
      groups ["I", "II", "III"]
      fallback_group "I"
    end

    # clean
    DeployPin::Record.delete_all
    ::FileUtils.rm_rf(DeployPin.tasks_path, secure: true)
    ::FileUtils.mkdir(DeployPin.tasks_path)

    # copy files
    ::FileUtils.cp 'test/support/files/task.rb', "#{DeployPin.tasks_path}taska.rb"
    ::FileUtils.cp 'test/support/files/task_different.rb', "#{DeployPin.tasks_path}taskb.rb"
    ::FileUtils.cp 'test/support/files/task_same.rb', "#{DeployPin.tasks_path}taskc.rb"

    @collector = DeployPin::Collector.new(groups: DeployPin.groups)
  end

  teardown do
    # clean
    DeployPin::Record.delete_all
    ::FileUtils.rm_rf(DeployPin.tasks_path, secure: true)
  end

  test "exacutable" do
    assert_equal(@collector.exacutable.count, 2)
  end

  test "files" do
    assert_nothing_raised do
      @collector.files
    end
  end

  test "tasks" do
    assert_nothing_raised do
      @collector.tasks
    end
  end

  test "run" do
    assert_nothing_raised do
      @collector.run {|x| }
    end
  end

  test "list" do
    assert_nothing_raised do
      @collector.list {|x| }
    end
  end
end
