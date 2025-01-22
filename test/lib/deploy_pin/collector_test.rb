# frozen_string_literal: true

require 'test_helper'

class DeployPin::Collector::Test < ActiveSupport::TestCase
  setup do
    # copy files
    ::FileUtils.cp 'test/support/files/task.rb', "#{DeployPin.tasks_path}1_task.rb"
    ::FileUtils.cp 'test/support/files/task_different.rb', "#{DeployPin.tasks_path}2_task.rb"
    ::FileUtils.cp 'test/support/files/task_same.rb', "#{DeployPin.tasks_path}3_task.rb"
    ::FileUtils.cp 'test/support/files/other_task.rb', "#{DeployPin.tasks_path}4_task.rb"

    @completed_record =
      DeployPin::Record.create(uuid: '75371573753754', completed_at: Time.current)

    @collector = DeployPin::Collector.new(identifiers: DeployPin.groups)
    @ids_collector = DeployPin::Collector.new(identifiers: ['75371573753753', '75371573753754!'])
  end

  test 'executable with ids' do
    assert_equal(2, @ids_collector.executable.count)
  end

  test 'executable with group' do
    assert_equal(2, @collector.executable.count)
  end

  test 'tasks_count' do
    assert_nothing_raised do
      @collector.tasks_count
    end
  end

  test 'files' do
    assert_nothing_raised do
      @collector.send(:files)
    end
  end

  test 'init_tasks' do
    assert_nothing_raised do
      @collector.send(:init_tasks)
    end
  end

  test 'run' do
    assert_nothing_raised do
      @collector.run
    end
  end

  test 'list' do
    assert_nothing_raised do
      @collector.list
    end
  end

  test 'cleanup' do
    assert_no_difference 'DeployPin::Record.count' do
      @collector.cleanup
    end

    assert File.exist?("#{DeployPin.tasks_path}4_task.rb")

    assert_difference 'DeployPin::Record.count', -1 do
      @collector.cleanup
    end

    refute File.exist?("#{DeployPin.tasks_path}4_task.rb")
  end

  test 'custom task wrapper' do
    DeployPin.setup do
      task_wrapper(
        lambda { |_task, task_runner|
          puts 'called'
          task_runner.call
        }
      )
    end

    assert_output(/called\ncalled\n/) { @collector.run }
  end
end
