# frozen_string_literal: true

require 'test_helper'

class DeployPin::Runner::Test < ActiveSupport::TestCase
  setup do
    # copy files
    ::FileUtils.cp 'test/support/files/task.rb', "#{DeployPin.tasks_path}1_task.rb"
    ::FileUtils.cp 'test/support/files/task_different.rb', "#{DeployPin.tasks_path}2_task.rb"
    ::FileUtils.cp 'test/support/files/task_same.rb', "#{DeployPin.tasks_path}3_task.rb"
  end

  test 'summary' do
    assert_nothing_raised do
      DeployPin::Runner.summary(identifiers: [DeployPin.fallback_group])
    end
  end

  test 'run' do
    assert_nothing_raised do
      DeployPin::Runner.run(identifiers: DeployPin.groups)
    end
  end

  test 'run with identifier' do
    assert_nothing_raised do
      DeployPin::Runner.run(identifiers: [75_371_573_753_751])
    end
  end

  test 'list' do
    assert_nothing_raised do
      DeployPin::Runner.list(identifiers: [DeployPin.fallback_group])
    end
  end

  test 'mark_done' do
    identifiers = %w[I II III]
    assert_nothing_raised do
      DeployPin::Runner.mark_done(identifiers: identifiers)
    end

    tasks = DeployPin::Collector.new(identifiers: identifiers).send(:init_tasks)
    uuids = tasks.map(&:identifier).reject(&:negative?)
    records = uuids.filter_map { |uuid| DeployPin::Storage.record_class.find_by(uuid:) }
    assert_equal(uuids.count - 1, records.count)
    assert_equal(records.all? { |record| !record.completed_at.nil? }, true)
  end

  test 'summary with empty identifiers' do
    assert_nothing_raised do
      DeployPin::Runner.summary(identifiers: [])
    end
  end

  test 'run with invalid identifier' do
    assert_nothing_raised do
      DeployPin::Runner.run(identifiers: ['invalid'])
    end
  end

  test 'mark_done with empty identifiers' do
    assert_nothing_raised do
      DeployPin::Runner.mark_done(identifiers: [])
    end
  end
end

# Runner.print is silent in the app's test environment.
class DeployPin::Runner::TestEnvTest < ActiveSupport::TestCase
  VARIABLES = DeployPin::Runner::ENV_VARIABLES

  test 'test_env? is true in the test environment of a plain Ruby app' do
    assert(with_env('APP_ENV' => 'test') { DeployPin::Runner.test_env? })
    assert(with_env('RACK_ENV' => 'test') { DeployPin::Runner.test_env? })
    assert(with_env('RAILS_ENV' => 'test') { DeployPin::Runner.test_env? })
  end

  test 'test_env? uses the first variable that is set' do
    refute(with_env('RAILS_ENV' => 'production', 'APP_ENV' => 'test') { DeployPin::Runner.test_env? })
    assert(with_env('RAILS_ENV' => '', 'APP_ENV' => 'test') { DeployPin::Runner.test_env? })
  end

  test 'test_env? is false without an environment' do
    refute(with_env({}) { DeployPin::Runner.test_env? })
  end

  test 'print prints outside of the test environment' do
    assert_output("hello\n") { with_env('APP_ENV' => 'production') { DeployPin::Runner.print('hello') } }
    assert_output('') { with_env('APP_ENV' => 'test') { DeployPin::Runner.print('hello') } }
  end

  private

    def with_env(values)
      saved = VARIABLES.to_h { |name| [name, ENV.fetch(name, nil)] }
      VARIABLES.each { |name| ENV[name] = values[name] }
      yield
    ensure
      saved.each { |name, value| ENV[name] = value }
    end
end
