# frozen_string_literal: true

require 'test_helper'
require 'rake'
require 'tmpdir'

# DeployPin.load_config and DeployPin.load_tasks, which plain Ruby apps use
# instead of the Rails initializer and engine.
class DeployPin::ConfigurationTest < ActiveSupport::TestCase
  setup do
    @root = Dir.mktmpdir('deploy_pin_app')
    @rake = Rake.application
    Rake.application = Rake::Application.new
    $loaded_configs = [] # rubocop:disable Style/GlobalVars
  end

  teardown do
    Rake.application = @rake
    FileUtils.rm_rf(@root)
  end

  test 'load_config loads config/deploy_pin.rb' do
    write_config 'config/deploy_pin.rb'
    write_config 'config/initializers/deploy_pin.rb'

    assert_equal [path('config/deploy_pin.rb')], DeployPin.load_config(nil, root: @root)
    assert_equal ['config/deploy_pin.rb'], loaded_configs
  end

  test 'load_config falls back to the Rails initializer' do
    write_config 'config/initializers/deploy_pin.rb'

    DeployPin.load_config(nil, root: @root)

    assert_equal ['config/initializers/deploy_pin.rb'], loaded_configs
  end

  test 'load_config loads nothing when there is no configuration file' do
    assert_empty DeployPin.load_config(nil, root: @root)
  end

  test 'load_config loads the given files, and only them' do
    write_config 'config/deploy_pin.rb'
    write_config 'config/environment.rb'
    write_config 'config/other.rb'

    DeployPin.load_config(%w[config/environment.rb config/other.rb], root: @root)

    assert_equal %w[config/environment.rb config/other.rb], loaded_configs
  end

  test 'load_config raises on a missing file' do
    error = assert_raises(ArgumentError) { DeployPin.load_config('config/missing.rb', root: @root) }

    assert_match "No such file: #{path('config/missing.rb')}", error.message
  end

  test 'load_config is relative to the working directory by default' do
    write_config 'config/deploy_pin.rb'

    Dir.chdir(@root) { DeployPin.load_config }

    assert_equal ['config/deploy_pin.rb'], loaded_configs
  end

  test 'load_tasks defines the deploy_pin tasks' do
    DeployPin.load_tasks

    %w[run list short_list mark_done environment].each do |name|
      assert Rake::Task.task_defined?("deploy_pin:#{name}"), "deploy_pin:#{name} is not defined"
    end
  end

  test 'the tasks run the app environment task when it is defined' do
    DeployPin.load_tasks
    environment_loaded = false
    Rake::Task.define_task(:environment) { environment_loaded = true }

    Rake::Task['deploy_pin:run'].invoke

    assert environment_loaded
  end

  test 'the tasks load the configuration when there is no environment task' do
    write_config 'config/deploy_pin.rb', "DeployPin.setup { groups %w[I] }\n"
    DeployPin.instance_variable_set(:@groups, nil)
    DeployPin.load_tasks

    Dir.chdir(@root) { Rake::Task['deploy_pin:short_list'].invoke }

    assert_equal ['config/deploy_pin.rb'], loaded_configs
    assert_equal %w[I], DeployPin.groups
  end

  test 'the tasks do not reload a loaded configuration' do
    write_config 'config/deploy_pin.rb'
    DeployPin.load_tasks

    Dir.chdir(@root) { Rake::Task['deploy_pin:list'].invoke }

    assert_empty loaded_configs
  end

  test 'deploy_pin:run runs the tasks of the given identifiers' do
    ::FileUtils.cp 'test/support/files/task.rb', "#{DeployPin.tasks_path}1_task.rb"
    ::FileUtils.cp 'test/support/files/task_different.rb', "#{DeployPin.tasks_path}2_task.rb"
    DeployPin.load_tasks

    Rake::Task['deploy_pin:run'].invoke('75371573753751, II')

    refute_nil DeployPin::Storage.record_class.find_by(uuid: '75371573753751').completed_at
    refute_nil DeployPin::Storage.record_class.find_by(uuid: '75371573753752').completed_at
  end

  test 'deploy_pin:mark_done marks the tasks as done' do
    ::FileUtils.cp 'test/support/files/task.rb', "#{DeployPin.tasks_path}1_task.rb"
    DeployPin.load_tasks

    Rake::Task['deploy_pin:mark_done'].invoke('I')

    refute_nil DeployPin::Storage.record_class.find_by(uuid: '75371573753751').completed_at
  end

  private

    def path(file)
      File.join(@root, file)
    end

    def write_config(file, content = '')
      FileUtils.mkdir_p(File.dirname(path(file)))
      File.write(path(file), "$loaded_configs << #{file.inspect}\n#{content}")
    end

    def loaded_configs
      $loaded_configs # rubocop:disable Style/GlobalVars
    end
end
