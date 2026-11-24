# frozen_string_literal: true

require 'test_helper'

# Tasks must still run when a statement timeout can't be applied: on databases
# without one (e.g. SQLite) or when no statement_timeout is configured.
class DeployPin::UnsupportedTimeoutTest < ActiveSupport::TestCase
  setup { skip 'requires ActiveRecord' unless DeployPin::Database.available? }

  teardown do
    DeployPin::Database.instance_variable_set(:@unsupported_engine_warned, nil)
    DeployPin.statement_timeout 0.2.second
  end

  test 'runs the block without a timeout and warns once on a database without statement timeouts' do
    DeployPin::Database.stub(:db_engine, nil) do
      assert_output(nil, /Statement timeouts are not supported for the \w+ adapter; running without a timeout/) do
        assert_equal :done, DeployPin::Database.execute_with_timeout(1.second) { :done }
      end

      assert_output(nil, '') do
        assert_equal :again, DeployPin::Database.execute_with_timeout(1.second) { :again }
      end
    end
  end

  test 'runs a task on a database without statement timeouts' do
    ::FileUtils.cp 'test/support/files/task.rb', "#{DeployPin.tasks_path}1_task.rb"

    DeployPin::Database.stub(:db_engine, nil) do
      capture_io { DeployPin::Collector.new(identifiers: DeployPin.groups).run }
    end

    assert_predicate DeployPin::Storage.record_class.find_by(uuid: '75371573753751').completed_at, :present?
  end

  test 'runs a task without a timeout when statement_timeout is not set' do
    DeployPin.remove_instance_variable(:@statement_timeout)
    ::FileUtils.cp 'test/support/files/task.rb', "#{DeployPin.tasks_path}1_task.rb"

    DeployPin::Collector.new(identifiers: DeployPin.groups).run

    assert_predicate DeployPin::Storage.record_class.find_by(uuid: '75371573753751').completed_at, :present?
  end

  test 'runs parallel blocks without a timeout when statement_timeout is not set' do
    DeployPin.remove_instance_variable(:@statement_timeout)
    runner = DeployPin::ParallelWrapper::ParallelRunner.new(:parallel_map, [1, 2], in_threads: 2) { |i| i * 10 }

    assert_equal [10, 20], runner.run
  end
end
