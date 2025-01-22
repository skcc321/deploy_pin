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

  test 'cleanup' do
    assert_nothing_raised do
      DeployPin::Runner.cleanup(identifiers: DeployPin.groups)
    end
  end
end
