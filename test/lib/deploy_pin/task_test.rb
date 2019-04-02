require 'test_helper'

class DeployPin::Task::Test < ActiveSupport::TestCase
  setup do
    DeployPin.setup do
      tasks_path './tmp/'
      groups ["I", "II", "III"]
      fallback_group "I"
    end

    @task = DeployPin::Task.new('test/support/files/task.rb')
  end

  test "run" do
    assert_nothing_raised do
      @task.run
    end
  end

  test "mark" do
    assert_nothing_raised do
      @task.mark
    end
  end

  test "done?" do
    assert_nothing_raised do
      @task.done?
    end
  end

  test "parse_file" do
    assert_nothing_raised do
      @task.parse_file
    end
  end

  test "details" do
    assert_nothing_raised do
      @task.details
    end
  end

  test "eql?" do
    assert_nothing_raised do
      @task.eql?(DeployPin::Task.new('test/support/files/task.rb'))
    end
  end

  test "group_index" do
    assert_nothing_raised do
      @task.send(:group_index)
    end
  end

  test "<=>" do
    assert_nothing_raised do
      @task.send(:<=>, DeployPin::Task.new('test/support/files/task.rb'))
    end
  end
end
