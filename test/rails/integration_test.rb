# frozen_string_literal: true

require 'test_helper'
require 'open3'

# Uses DeployPin from the outside, the way a Rails app does: `bin/rails
# generate`, `bin/rails destroy`, `bin/rails deploy_pin:run` and the generated
# spec. Each command runs in its own process, in test/rails/dummy.
class DeployPin::RailsIntegrationTest < ActiveSupport::TestCase
  GEM_ROOT = File.expand_path('../..', __dir__)
  APP_ROOT = File.expand_path('dummy', __dir__)

  # The commands run in other processes, so they must see the records this test commits.
  self.use_transactional_tests = false if respond_to?(:use_transactional_tests=)

  teardown do
    FileUtils.rm_rf(File.join(APP_ROOT, 'lib/deploy_pin'))
    FileUtils.rm_rf(File.join(APP_ROOT, 'spec/deploy_pin'))
  end

  test 'rails generate deploy_pin:task creates a task and a spec that passes' do
    output = run!('bin/rails', 'generate', 'deploy_pin:task', 'say_hello', '-g', 'II', '-a', 'jane',
                  '--test-framework=rspec')
    task_file = Dir[File.join(APP_ROOT, 'lib/deploy_pin/*_say_hello.rb')].first
    spec_file = Dir[File.join(APP_ROOT, 'spec/deploy_pin/*_say_hello_spec.rb')].first

    refute_nil task_file, output
    assert_match '# task_title: @jane Say Hello', File.read(task_file)
    refute_nil spec_file, output
    assert_match "require 'rails_helper'", File.read(spec_file)

    hook_file = File.join(APP_ROOT, 'tmp/deploy_pin_hook_ran')
    FileUtils.mkdir_p(File.dirname(hook_file)) # tmp/ is not in git
    FileUtils.rm_f(hook_file)
    output = run!('rspec', spec_file.delete_prefix("#{APP_ROOT}/"), env: { 'DEPLOY_PIN_HOOK_FILE' => hook_file })
    assert_match '2 examples, 0 failures', output
    # The spec loads the app's rake files too (Rails.application.load_tasks): its hook on deploy_pin:run ran
    assert_equal 'hook ran', File.read(hook_file)
  ensure
    FileUtils.rm_f(hook_file) if hook_file
  end

  test 'rails destroy deploy_pin:task removes the task' do
    run!('bin/rails', 'generate', 'deploy_pin:task', 'warm_caches', '-g', 'I', '--recurring', '--identifier', '5',
         '--skip-test')
    assert_path_exists File.join(APP_ROOT, 'lib/deploy_pin/r_5_warm_caches.rb')

    run!('bin/rails', 'destroy', 'deploy_pin:task', 'warm_caches', '-g', 'I', '--recurring', '--identifier', '5',
         '--skip-test')
    refute_path_exists File.join(APP_ROOT, 'lib/deploy_pin/r_5_warm_caches.rb')
  end

  test 'rails generate deploy_pin:task fails on an unknown group' do
    output, status = Open3.capture2e(env, 'bundle', 'exec', 'bin/rails', 'generate', 'deploy_pin:task', 'x', '-g',
                                     'nope', chdir: APP_ROOT)

    assert_match "Group 'nope' is not defined in DeployPin.groups", output, status
    assert_empty Dir[File.join(APP_ROOT, 'lib/deploy_pin/*.rb')]
  end

  test 'rails generate deploy_pin:task --help shows the usage and the options' do
    output = run!('bin/rails', 'generate', 'deploy_pin:task', '--help')

    assert_match 'rails generate deploy_pin:task some_name_of_task -a author -g I', output
    assert_match '--group', output
    assert_match '--skip-test', output
  end

  test 'bin/rails deploy_pin:run runs the pending tasks' do
    FileUtils.mkdir_p(File.join(APP_ROOT, 'lib/deploy_pin'))
    FileUtils.cp(File.join(GEM_ROOT, 'test/support/files/task.rb'), File.join(APP_ROOT, 'lib/deploy_pin/1_task.rb'))

    run!('bin/rails', 'deploy_pin:run[I]')

    refute_nil DeployPin::Storage.record_class.find_by(uuid: '75371573753751').completed_at
  end

  test "bin/rails 'deploy_pin:run[I, !id]' skips the excluded task" do
    FileUtils.mkdir_p(File.join(APP_ROOT, 'lib/deploy_pin'))
    %w[task.rb failing_task.rb].each do |file|
      FileUtils.cp(File.join(GEM_ROOT, 'test/support/files', file), File.join(APP_ROOT, 'lib/deploy_pin', file))
    end

    run!('bin/rails', 'deploy_pin:run[I, !75371573753799]')

    refute_nil DeployPin::Storage.record_class.find_by(uuid: '75371573753751').completed_at
    assert_nil DeployPin::Storage.record_class.find_by(uuid: '75371573753799')
  end

  test 'bin/rails deploy_pin:cleanup removes old task files' do
    directory = File.join(APP_ROOT, 'lib/deploy_pin')
    FileUtils.mkdir_p(directory)
    old, recent = [31.days.ago, 1.day.ago].map do |time|
      identifier = time.strftime('%Y%m%d%H%M%S')
      File.join(directory, "#{identifier}_task.rb").tap do |path|
        File.write(path, "# #{identifier}:I\n\n# === task code goes down here ===\n:ok\n")
      end
    end

    run!('bin/rails', 'deploy_pin:cleanup')

    refute_path_exists old
    assert_path_exists recent
  end

  test 'the deploy_pin command also works in a Rails app' do
    run!('ruby', File.join(GEM_ROOT, 'exe/deploy_pin'), 'task', 'from_cli', '-g', 'III', '--skip-test',
         '--require', 'config/environment.rb')

    assert_equal 1, Dir[File.join(APP_ROOT, 'lib/deploy_pin/*_from_cli.rb')].size
  end

  private

    def env
      { 'BUNDLE_GEMFILE' => ENV.fetch('BUNDLE_GEMFILE', File.join(GEM_ROOT, 'Gemfile')), 'RAILS_ENV' => 'test' }
    end

    def run!(*command, env: {})
      output, status = Open3.capture2e(self.env.merge(env), 'bundle', 'exec', *command, chdir: APP_ROOT)
      assert_predicate status, :success?, "#{command.join(' ')} failed:\n#{output}"
      output
    end
end
