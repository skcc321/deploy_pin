require 'test_helper'

class DeployPin::TaskCriteria::Test < ActiveSupport::TestCase
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
    ::FileUtils.cp 'test/support/files/task.rb', "#{DeployPin.tasks_path}1_task.rb"
    ::FileUtils.cp 'test/support/files/other_task.rb', "#{DeployPin.tasks_path}2_task.rb"
    ::FileUtils.cp 'test/support/files/task_different.rb', "#{DeployPin.tasks_path}3_task.rb"

    # create two record
    DeployPin::Record.create(uuid: '75371573753751')
    DeployPin::Record.create(uuid: '75371573753754')

    @task_1 = DeployPin::Task.new("#{DeployPin.tasks_path}1_task.rb")
    @task_2 = DeployPin::Task.new("#{DeployPin.tasks_path}2_task.rb")
    @task_3 = DeployPin::Task.new("#{DeployPin.tasks_path}3_task.rb")
    @task_1.parse_file
    @task_2.parse_file
    @task_3.parse_file
    @criteria = DeployPin::TaskCriteria.new(identifiers: ['I', 'II', '75371573753754!', '-75371573753752'])
  end

  teardown do
    # clean
    DeployPin::Record.delete_all
    ::FileUtils.rm_rf(DeployPin.tasks_path, secure: true)
  end

  test "suitable?" do
    assert_equal(true, @criteria.suitable?(@task_2))
  end

  test "not suitable?" do
    assert_equal(false, @criteria.suitable?(@task_3))
    assert_equal(false, @criteria.suitable?(@task_1))
  end
end
