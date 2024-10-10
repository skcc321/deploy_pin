# frozen_string_literal: true

require 'test_helper'

class DeployPin::Task::Test < ActiveSupport::TestCase
  setup do
    @task = DeployPin::Task.new('test/support/files/task.rb')
  end

  test 'run' do
    assert_nothing_raised { @task.run }
  end

  test 'prepare' do
    assert_equal DeployPin::Record.where(uuid: @task.identifier).count, 0
    assert_nothing_raised { @task.prepare }
    assert_equal DeployPin::Record.where(uuid: @task.identifier).count, 1
  end

  test 'mark' do
    @task.prepare
    assert_nothing_raised { @task.mark }
  end

  test 'done?' do
    @task.prepare
    assert_nothing_raised { @task.done? }
    assert_equal @task.done?, false
    @task.mark
    assert_equal @task.done?, true
  end

  test 'increment_progress!' do
    @task.prepare
    assert_equal @task.progress, 0
    assert_nothing_raised { @task.increment_progress!(77) }
    assert_equal @task.progress, 77
  end

  test 'parse' do
    assert_nothing_raised { @task.parse }
  end

  test 'details' do
    assert_nothing_raised { @task.details }
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
