# frozen_string_literal: true

require 'test_helper'
require 'rake'

# The engine and Rails.application.load_tasks define the deploy_pin:* tasks
# once per Rake application, next to the app's own hooks.
class DeployPin::RailsLoadTasksTest < ActiveSupport::TestCase
  HOOK_FILE = File.expand_path('dummy/tmp/load_tasks_hook_ran', __dir__)

  setup do
    @rake = Rake.application
    Rake.application = Rake::Application.new
    FileUtils.mkdir_p(File.dirname(HOOK_FILE))
    FileUtils.rm_f(HOOK_FILE)
    File.write("#{DeployPin.tasks_path}r_5_count.rb", "# 5:I:recurring\n# task_title: count\n\n$runs += 1\n")
    $runs = 0 # rubocop:disable Style/GlobalVars
  end

  teardown do
    Rake.application = @rake
    FileUtils.rm_f(HOOK_FILE)
  end

  test 'loading the app tasks twice runs a recurring task once, and the app hook' do
    with_hook_file do
      Rails.application.load_tasks
      Rails.application.load_tasks
    end
    DeployPin.load_tasks

    Rake::Task[:environment].stub(:invoke, nil) { Rake::Task['deploy_pin:run'].invoke('I') }

    assert_equal 1, $runs # rubocop:disable Style/GlobalVars
    assert_equal 'hook ran', File.read(HOOK_FILE)
  end

  test 'a new Rake application gets the tasks from the engine' do
    Rails.application.load_tasks
    Rake.application = Rake::Application.new
    Rails.application.load_tasks

    assert Rake::Task.task_defined?('deploy_pin:run')
    Rake::Task[:environment].stub(:invoke, nil) { Rake::Task['deploy_pin:run'].invoke('I') }
    assert_equal 1, $runs # rubocop:disable Style/GlobalVars
  end

  private

    def with_hook_file
      ENV['DEPLOY_PIN_HOOK_FILE'] = HOOK_FILE
      yield
    ensure
      ENV.delete('DEPLOY_PIN_HOOK_FILE')
    end
end
