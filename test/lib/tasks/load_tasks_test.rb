# frozen_string_literal: true

require 'test_helper'
require 'rake'

# DeployPin.load_tasks defines the deploy_pin:* tasks once per Rake application.
class DeployPin::LoadTasksTest < ActiveSupport::TestCase
  setup do
    @rake = Rake.application
    Rake.application = Rake::Application.new
    File.write("#{DeployPin.tasks_path}r_5_count.rb", "# 5:I:recurring\n# task_title: count\n\n$runs += 1\n")
    $runs = 0 # rubocop:disable Style/GlobalVars
  end

  teardown { Rake.application = @rake }

  test 'loading the tasks twice in one application defines their actions once' do
    2.times { DeployPin.load_tasks }

    %w[deploy_pin:run deploy_pin:list deploy_pin:short_list deploy_pin:mark_done deploy_pin:environment].each do |name|
      assert_equal 1, Rake::Task[name].actions.size, name
    end
    Rake::Task['deploy_pin:run'].invoke('I')
    assert_equal 1, $runs # rubocop:disable Style/GlobalVars
  end

  test 'a new Rake application gets the tasks again' do
    DeployPin.load_tasks
    Rake.application = Rake::Application.new
    refute Rake::Task.task_defined?('deploy_pin:run')

    DeployPin.load_tasks
    DeployPin.load_tasks

    assert_equal 1, Rake::Task['deploy_pin:run'].actions.size
    Rake::Task['deploy_pin:run'].invoke('I')
    assert_equal 1, $runs # rubocop:disable Style/GlobalVars
  end

  test 'the tasks are defined again after Rake::Task.clear' do
    DeployPin.load_tasks
    Rake::Task.clear
    DeployPin.load_tasks

    assert_equal 1, Rake::Task['deploy_pin:run'].actions.size
  end

  test 'a hook of the app on deploy_pin:run is kept' do
    DeployPin.load_tasks
    hook_ran = 0
    Rake::Task.define_task('deploy_pin:run') { hook_ran += 1 }
    DeployPin.load_tasks

    Rake::Task['deploy_pin:run'].invoke('I')

    assert_equal [1, 1], [$runs, hook_ran] # rubocop:disable Style/GlobalVars
  end
end
