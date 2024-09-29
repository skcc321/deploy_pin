# frozen_string_literal: true

require 'minitest/autorun'
require 'test_helper'

class DeployPin::ParallelWrapper::Test < ActiveSupport::TestCase
  test 'should throw exception when execution time is equal to the default timeout' do
    task_content = task_content_with_default_timeout(0.3.second)
    task = DeployPin::Task.new(task_content)

    File.stub :foreach, true, task_content do
      task.parse

      error = assert_raises(StandardError) do
        task.run
      end

      assert_match(/statement (timeout|execution)/, error.message)
    end
  end

  def task_content_with_default_timeout(sleep_in_sec)
    <<-FILE
    parallel_each(1..2, in_processes: 2) do |i|
      puts "Item: \#{i}, Worker: \#{Parallel.worker_number}"
      ActiveRecord::Base.connection.execute("#{sql_sleep(sleep_in_sec.to_f)}")
      puts "finished \#{i}"
    end
    FILE
  end

  def sql_sleep(duration_in_sec)
    if mysql? || mariadb?
      # Mysql `SELECT sleep(n);` doesn't throw exception when timeout exceeds, that's the reason of this query.
      "SELECT 1 WHERE sleep(#{duration_in_sec});"
    elsif pg?
      "SELECT pg_sleep(#{duration_in_sec});"
    end
  end

  def timeout_exception_klass
    return ActiveRecord::StatementTimeout if mysql? || mariadb?

    ActiveRecord::QueryCanceled if pg?
  end

  DeployPin::DatabaseEngine::DB_ENGINES_MAPPING.each_key do |engine|
    define_method "#{engine}?" do
      ENV['DB_ROLE'] == engine.to_s
    end
  end
end
