# frozen_string_literal: true

require 'test_helper'
require 'open3'
require 'rbconfig'
require 'tmpdir'

# Uses DeployPin from the outside, the way a plain Ruby app does: the
# `deploy_pin` command, `rake` with DeployPin.load_tasks, and the generated
# spec. Each command runs in its own process, against test/dummy.
class DeployPin::PlainRubyAppTest < ActiveSupport::TestCase
  GEM_ROOT = File.expand_path('../..', __dir__)
  APP_ROOT = File.join(GEM_ROOT, 'test/dummy')
  DEPLOY_PIN = File.join(GEM_ROOT, 'exe/deploy_pin')

  setup do
    @app_files = []
  end

  teardown do
    @app_files.each { |file| FileUtils.rm_f(file) }
    FileUtils.rm_rf(File.join(APP_ROOT, 'spec/deploy_pin'))
  end

  test 'runs without Rails or an ORM' do
    Dir.mktmpdir do |dir|
      output = run!('ruby', File.join(GEM_ROOT, 'test/support/without_rails.rb'), dir)

      # One-off tasks run once, the recurring one on each of the two runs
      assert_match(/^ran: @ci Every Deploy, @ci Every Deploy, @ci First Task, @ci Second Task$/, output)
      assert_match(/^done: true$/, output)
      assert_match(/^progress: 2, 2$/, output)
      assert_match(/^loaded: $/, output)
    end
  end

  test 'rake deploy_pin:run runs the pending tasks of the app' do
    add_task_file 'task.rb'
    add_task_file 'task_different.rb'

    run! 'rake', "deploy_pin:run[#{identifier('task.rb')}]"

    refute_nil DeployPin::Storage.record_class.find_by(uuid: identifier('task.rb')).completed_at
    assert_nil DeployPin::Storage.record_class.find_by(uuid: identifier('task_different.rb'))

    run! 'rake', 'deploy_pin:run'

    refute_nil DeployPin::Storage.record_class.find_by(uuid: identifier('task_different.rb')).completed_at
  end

  test 'rake deploy_pin:list, short_list and mark_done' do
    add_task_file 'task.rb'

    run! 'rake', 'deploy_pin:list', 'deploy_pin:short_list'
    assert_nil DeployPin::Storage.record_class.find_by(uuid: identifier('task.rb'))

    run! 'rake', 'deploy_pin:mark_done[I]'
    refute_nil DeployPin::Storage.record_class.find_by(uuid: identifier('task.rb')).completed_at
  end

  test 'rake prints the summary outside of the test environment' do
    development = { 'APP_ENV' => 'development', 'RACK_ENV' => nil, 'RAILS_ENV' => nil }
    output = run!('rake', 'deploy_pin:short_list', env: development)

    assert_match 'Tasks number: 0', output
  end

  test 'deploy_pin task generates a task and a spec that passes' do
    output = run!('ruby', DEPLOY_PIN, 'task', 'say_hello', '-g', 'II', '--test-framework=rspec',
                  '--require', 'config/environment.rb', '--author', 'jane')
    task_file = Dir[File.join(APP_ROOT, 'lib/deploy_pin/*_say_hello.rb')].first
    @app_files << task_file
    spec_file = Dir[File.join(APP_ROOT, 'spec/deploy_pin/*_say_hello_spec.rb')].first

    assert_match 'create', output
    refute_nil task_file, output
    assert_match '# task_title: @jane Say Hello', File.read(task_file)
    refute_nil spec_file, output
    assert_match "require 'spec_helper'", File.read(spec_file)

    output = run!('rspec', spec_file.delete_prefix("#{APP_ROOT}/"))
    assert_match '2 examples, 0 failures', output
  end

  test 'deploy_pin install generates the configuration and the migration' do
    Dir.mktmpdir do |dir|
      run!('ruby', DEPLOY_PIN, 'install', chdir: dir)

      assert_path_exists File.join(dir, 'config/deploy_pin.rb')
      assert_equal 1, Dir[File.join(dir, 'db/migrate/*_create_deploy_pins.rb')].size
    end
  end

  test 'deploy_pin exits with an error status on errors' do
    output, status = Open3.capture2e(env, 'bundle', 'exec', 'ruby', DEPLOY_PIN, 'task', 'x', '-g', 'nope',
                                     '--require', 'config/environment.rb', chdir: APP_ROOT)

    refute_predicate status, :success?
    assert_match "Group 'nope' is not defined in DeployPin.groups", output
  end

  private

    def env(overrides = {})
      { 'BUNDLE_GEMFILE' => File.join(GEM_ROOT, 'Gemfile'), 'APP_ENV' => 'test' }.merge(overrides)
    end

    def run!(*command, env: {}, chdir: APP_ROOT)
      output, status = Open3.capture2e(self.env(env), 'bundle', 'exec', *command, chdir:)
      assert_predicate status, :success?, "#{command.join(' ')} failed:\n#{output}"
      output
    end

    def add_task_file(fixture)
      path = File.join(APP_ROOT, 'lib/deploy_pin', fixture)
      FileUtils.mkdir_p(File.dirname(path))
      FileUtils.cp(File.join(GEM_ROOT, 'test/support/files', fixture), path)
      @app_files << path
    end

    def identifier(fixture)
      File.read(File.join(GEM_ROOT, 'test/support/files', fixture))[/^# (\d+):/, 1]
    end
end
