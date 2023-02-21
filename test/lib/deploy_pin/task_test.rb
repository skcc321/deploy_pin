# frozen_string_literal: true

require 'test_helper'

class DeployPin::Task::Test < ActiveSupport::TestCase
  setup do
    @task = DeployPin::Task.new('test/support/files/task.rb')
  end

  test 'run' do
    assert_nothing_raised do
      @task.run
    end
  end

  test 'mark' do
    assert_nothing_raised do
      @task.mark
    end
  end

  test 'done?' do
    assert_nothing_raised do
      @task.done?
    end
  end

  test 'parse' do
    assert_nothing_raised do
      @task.parse
    end
  end

  test 'details' do
    assert_nothing_raised do
      @task.details
    end
  end

  test 'eql?' do
    assert_nothing_raised do
      @task.eql?(DeployPin::Task.new('test/support/files/task.rb'))
    end
  end

  test 'explicit_timeout?' do
    @task.parse
    assert_equal @task.send(:explicit_timeout?), false

    task_with_timeout = DeployPin::Task.new('test/support/files/task_with_timeout.rb')
    task_with_timeout.parse
    assert_equal task_with_timeout.send(:explicit_timeout?), true
  end

  test 'under_timeout?' do
    @task.parse
    assert_equal @task.under_timeout?, true

    task_with_timeout = DeployPin::Task.new('test/support/files/task_with_timeout.rb')
    task_with_timeout.parse
    assert_equal task_with_timeout.under_timeout?, false

    parallel_task = DeployPin::Task.new('test/support/files/parallel_task.rb')
    parallel_task.parse
    assert_equal parallel_task.under_timeout?, false
  end

  test 'group_index' do
    assert_nothing_raised do
      @task.send(:group_index)
    end
  end

  test '<=>' do
    assert_nothing_raised do
      @task.send(:<=>, DeployPin::Task.new('test/support/files/task.rb'))
    end
  end
end
