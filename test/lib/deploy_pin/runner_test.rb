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
    assert_equal(uuids.count - 1, DeployPin::Record.where(uuid: uuids).count)
    assert_equal(DeployPin::Record.where(uuid: uuids).all? { |record| !record.completed_at.nil? }, true)
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
