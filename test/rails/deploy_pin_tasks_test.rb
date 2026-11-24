# frozen_string_literal: true

require 'test_helper'
require 'rake'

class DeployPinTasksTest < ActiveSupport::TestCase
  Rails.application.load_tasks

  test "deploy_pin:list'" do
    assert_nothing_raised do
      Rake::Task['deploy_pin:list'].invoke
    end
  end

  test "deploy_pin:list[I]'" do
    assert_nothing_raised do
      Rake::Task['deploy_pin:list'].invoke('I')
    end
  end

  test "deploy_pin:short_list'" do
    assert_nothing_raised do
      Rake::Task['deploy_pin:short_list'].invoke
    end
  end

  test "deploy_pin:short_list[I]'" do
    assert_nothing_raised do
      Rake::Task['deploy_pin:short_list'].invoke('I')
    end
  end

  test "deploy_pin:run'" do
    assert_nothing_raised do
      Rake::Task['deploy_pin:run'].invoke
    end
  end

  test "deploy_pin:run[I]'" do
    assert_nothing_raised do
      Rake::Task['deploy_pin:run'].invoke('I')
    end
  end

  test "deploy_pin:run['75371573753751, 75371573753752']" do
    assert_nothing_raised do
      Rake::Task['deploy_pin:run'].invoke('75371573753751, 75371573753752')
    end
  end

  # With task files: the Rails app's environment task runs first.

  setup do
    Rake::Task.tasks.each(&:reenable)
    ::FileUtils.cp 'test/support/files/task.rb', "#{DeployPin.tasks_path}1_task.rb"
    ::FileUtils.cp 'test/support/files/task_different.rb', "#{DeployPin.tasks_path}2_task.rb"
  end

  test 'deploy_pin:run runs the tasks after the Rails environment task' do
    assert_empty Rake::Task['deploy_pin:environment'].prerequisites
    environment_ran = false
    Rake::Task[:environment].stub(:invoke, -> { environment_ran = true }) do
      Rake::Task['deploy_pin:run'].invoke('I')
    end

    assert environment_ran
    refute_nil DeployPin::Storage.record_class.find_by(uuid: '75371573753751').completed_at
    assert_nil DeployPin::Storage.record_class.find_by(uuid: '75371573753752')
  end

  test 'deploy_pin:list[I] and short_list[I] with tasks' do
    assert_nothing_raised do
      Rake::Task['deploy_pin:list'].invoke('I')
      Rake::Task['deploy_pin:short_list'].invoke('I, II')
    end
  end

  test 'deploy_pin:mark_done[I] marks the tasks of group I as done' do
    Rake::Task['deploy_pin:mark_done'].invoke('I')

    refute_nil DeployPin::Storage.record_class.find_by(uuid: '75371573753751').completed_at
    assert_nil DeployPin::Storage.record_class.find_by(uuid: '75371573753752')
  end
end
