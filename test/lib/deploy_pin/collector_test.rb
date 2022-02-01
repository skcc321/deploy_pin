# frozen_string_literal: true

require 'test_helper'

class DeployPin::Collector::Test < ActiveSupport::TestCase
  setup do
    DeployPin.setup do
      tasks_path './tmp/'
      groups %w[I II III]
      fallback_group 'I'
    end

    # clean
    DeployPin::Record.delete_all
    ::FileUtils.rm_rf(DeployPin.tasks_path, secure: true)
    ::FileUtils.mkdir(DeployPin.tasks_path)

    # copy files
    ::FileUtils.cp 'test/support/files/task.rb', "#{DeployPin.tasks_path}1_task.rb"
    ::FileUtils.cp 'test/support/files/task_different.rb', "#{DeployPin.tasks_path}2_task.rb"
    ::FileUtils.cp 'test/support/files/task_same.rb', "#{DeployPin.tasks_path}3_task.rb"
    ::FileUtils.cp 'test/support/files/other_task.rb', "#{DeployPin.tasks_path}4_task.rb"

    # create one record
    DeployPin::Record.create(uuid: '75371573753754')

    @collector = DeployPin::Collector.new(identifiers: DeployPin.groups)
    @ids_collector = DeployPin::Collector.new(identifiers: ['75371573753753', '75371573753754!'])
  end

  teardown do
    # clean
    DeployPin::Record.delete_all
    ::FileUtils.rm_rf(DeployPin.tasks_path, secure: true)
  end

  test 'exacutable wiht ids' do
    assert_equal(2, @ids_collector.exacutable.count)
  end

  test 'exacutable wiht group' do
    assert_equal(2, @collector.exacutable.count)
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

  test 'tasks' do
    assert_nothing_raised do
      @collector.send(:tasks)
    end
  end

  test 'run' do
    assert_nothing_raised do
      @collector.run { |x| }
    end
  end

  test 'list' do
    assert_nothing_raised do
      @collector.list { |x| }
    end
  end
end
