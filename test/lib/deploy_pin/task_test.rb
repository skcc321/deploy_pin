# frozen_string_literal: true

require 'test_helper'

class DeployPin::Task::Test < ActiveSupport::TestCase
  setup do
    @task_file = "#{DeployPin.tasks_path}1_task.rb"
    ::FileUtils.cp 'test/support/files/task.rb', @task_file
    @task = DeployPin::Task.new(@task_file)
  end

  test 'run' do
    assert_nothing_raised { @task.run }
  end

  test 'prepare' do
    assert_difference 'DeployPin::Record.count', 1 do
      assert_nothing_raised { @task.prepare }
    end
  end

  test 'mark' do
    @task.prepare
    assert_nothing_raised { @task.mark }
  end

  test 'done?' do
    @task.prepare
    assert_nothing_raised { @task.done? }
    refute @task.done?
    @task.mark
    assert @task.done?
  end

  test 'increment_progress!' do
    @task.prepare
    assert_equal @task.progress, 0
    assert_nothing_raised { @task.increment_progress!(77) }
    assert_equal @task.progress, 77
    assert_nothing_raised { @task.increment_progress!(13) }
    assert_equal @task.progress, 90
  end

  test 'save_progress!' do
    @task.prepare
    assert_equal @task.progress, 0
    assert_nothing_raised { @task.save_progress!(13) }
    assert_equal @task.progress, 13
    assert_nothing_raised { @task.save_progress!(1) }
    assert_equal @task.progress, 1
  end

  test 'remove' do
    @task.prepare

    assert_difference 'DeployPin::Record.count', -1 do
      assert_nothing_raised { @task.remove }
    end

    refute File.exist?(@task_file)
  end

  test 'parse' do
    assert_nothing_raised { @task.parse }
  end

  test 'details' do
    assert_nothing_raised { @task.details }
  end

  test 'eql?' do
    assert_nothing_raised do
      @task.eql?(DeployPin::Task.new(@task_file))
    end
  end

  test 'explicit_timeout?' do
    @task.parse
    refute @task.send(:explicit_timeout?)

    task_with_timeout = DeployPin::Task.new('test/support/files/task_with_timeout.rb')
    task_with_timeout.parse
    assert task_with_timeout.send(:explicit_timeout?)
  end

  test 'under_timeout?' do
    @task.parse
    assert @task.under_timeout?

    task_with_timeout = DeployPin::Task.new('test/support/files/task_with_timeout.rb')
    task_with_timeout.parse
    refute task_with_timeout.under_timeout?

    parallel_task = DeployPin::Task.new('test/support/files/parallel_task.rb')
    parallel_task.parse
    refute parallel_task.under_timeout?
  end

  test 'classified_for_cleanup?' do
    @task.prepare
    refute @task.classified_for_cleanup?

    @task.mark
    refute @task.classified_for_cleanup?

    @task.record.update(completed_at: (DeployPin.cleanup_safe_time_window.call + 1.day).ago)
    assert @task.classified_for_cleanup?
  end

  test 'group_index' do
    assert_nothing_raised do
      @task.send(:group_index)
    end
  end

  test '<=>' do
    assert_nothing_raised do
      @task.send(:<=>, DeployPin::Task.new(@task_file))
    end
  end
end
