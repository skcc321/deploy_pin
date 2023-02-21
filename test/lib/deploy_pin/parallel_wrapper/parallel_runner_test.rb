# frozen_string_literal: true

require 'minitest/autorun'
require 'test_helper'

class DeployPin::ParallelWrapper::ParallelRunner::Test < ActiveSupport::TestCase
  test 'run with no args for parallel' do
    runner = DeployPin::ParallelWrapper::ParallelRunner.new(:each)

    error = assert_raises(RuntimeError) do
      runner.run
    end

    assert_match('You must provide at least one argument for parallel methods', error.message)
  end

  test 'run with single args' do
    args = [1..2]

    args_checker = lambda do |*parallel_args|
      assert_equal args.size, parallel_args.size
      assert_equal args.first, parallel_args.first
    end

    Parallel.stub :each, args_checker do
      runner = DeployPin::ParallelWrapper::ParallelRunner.new(:each, *args)
      runner.run
    end
  end

  test 'run with parallel extra arguments' do
    args = [1..2, { in_processes: 2 }]

    args_checker = lambda do |*parallel_args|
      assert_equal args.size, parallel_args.size
      assert_equal args.first, parallel_args.first
      assert_equal args.last, parallel_args.last
    end

    Parallel.stub :each, args_checker do
      runner = DeployPin::ParallelWrapper::ParallelRunner.new(:each, *args)
      runner.run
    end
  end

  test 'run with parallel extra arguments and timeouts' do
    parallel_args = [1..2, { in_processes: 2 }]
    statement_timeout_args = [timeout: 0.3.seconds]
    args = parallel_args + statement_timeout_args

    args_checker = lambda do |*parallel_each_args|
      assert_equal parallel_args.size, parallel_each_args.size
      assert_equal parallel_args.first, parallel_each_args.first
      assert_equal parallel_args.last, parallel_each_args.last
    end

    Parallel.stub :each, args_checker do
      runner = DeployPin::ParallelWrapper::ParallelRunner.new(:each, *args)
      runner.run
    end
  end
end
