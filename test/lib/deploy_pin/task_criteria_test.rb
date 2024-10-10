# frozen_string_literal: true

require 'test_helper'

class DeployPin::TaskCriteria::Test < ActiveSupport::TestCase
  setup do
    # copy files
    ::FileUtils.cp 'test/support/files/task.rb', "#{DeployPin.tasks_path}1_task.rb"
    ::FileUtils.cp 'test/support/files/other_task.rb', "#{DeployPin.tasks_path}2_task.rb"
    ::FileUtils.cp 'test/support/files/task_different.rb', "#{DeployPin.tasks_path}3_task.rb"

    # create two record
    DeployPin::Record.create(uuid: '75371573753751', completed_at: Time.current)
    DeployPin::Record.create(uuid: '75371573753754')

    @task_1 = DeployPin::Task.new("#{DeployPin.tasks_path}1_task.rb")
    @task_2 = DeployPin::Task.new("#{DeployPin.tasks_path}2_task.rb")
    @task_3 = DeployPin::Task.new("#{DeployPin.tasks_path}3_task.rb")
    @task_1.parse
    @task_2.parse
    @task_3.parse
    @criteria = DeployPin::TaskCriteria.new(identifiers: ['I', 'II', '75371573753754!', '!75371573753752'])
  end

  test 'suitable?' do
    assert(@criteria.suitable?(@task_2))
  end

  test 'not suitable?' do
    refute(@criteria.suitable?(@task_3))
    refute(@criteria.suitable?(@task_1))
  end
end
