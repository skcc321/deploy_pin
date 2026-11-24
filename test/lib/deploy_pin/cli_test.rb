# frozen_string_literal: true

require 'test_helper'

# The `deploy_pin` command, run in-process in an app directory.
class DeployPin::CLITest < DeployPin::GeneratorTestCase
  CONFIG = <<~RUBY
    DeployPin.setup do
      tasks_path 'lib/tasks_from_config'
      groups %w[alpha beta]
      test_framework false
    end
  RUBY

  test 'install creates the configuration and the migration' do
    deploy_pin 'install'

    assert_equal ['config/deploy_pin.rb'], generated('config/*.rb')
    assert_equal 1, generated('db/migrate/*_create_deploy_pins.rb').size
  end

  test 'task loads config/deploy_pin.rb first' do
    write 'config/deploy_pin.rb', CONFIG

    deploy_pin 'task', 'backfill_users', '-g', 'beta'

    assert_equal %w[alpha beta], DeployPin.groups
    assert_equal 1, generated('lib/tasks_from_config/*_backfill_users.rb').size
  end

  test 'task loads the Rails initializer when there is no config/deploy_pin.rb' do
    write 'config/initializers/deploy_pin.rb', CONFIG

    deploy_pin 'task', 'backfill_users', '-g', 'alpha'

    assert_equal 1, generated('lib/tasks_from_config/*_backfill_users.rb').size
  end

  test 'task loads the files given with --require' do
    write 'config/environment.rb', CONFIG
    write 'config/other.rb', "DeployPin.setup { fallback_group 'beta' }"

    deploy_pin 'task', 'backfill_users', '--require', 'config/environment.rb', '--require=config/other.rb'

    task_file = generated('lib/tasks_from_config/*_backfill_users.rb').first
    assert_match(/^# \d{14}:beta$/, read(task_file))
  end

  test 'fails when a --require file does not exist' do
    error = deploy_pin_failing('task', 'backfill_users', '--require', 'missing.rb')

    assert_match 'No such file', error
    assert_match 'missing.rb', error
  end

  test 'fails on an unknown group' do
    write 'config/deploy_pin.rb', CONFIG

    error = deploy_pin_failing('task', 'backfill_users', '-g', 'gamma')

    assert_match "Group 'gamma' is not defined in DeployPin.groups", error
  end

  test 'upgrade creates the upgrade migration' do
    deploy_pin 'upgrade'

    assert_equal 1, generated('db/migrate/*_upgrade_deploy_pins.rb').size
  end

  test 'help lists the commands without loading the configuration' do
    write 'config/deploy_pin.rb', 'raise "loaded"'

    output = deploy_pin('help')

    ['install [--storage=mongoid]', 'task TITLE -g GROUP', 'upgrade', 'version'].each do |usage|
      assert_match usage, output
    end
  end

  test 'version prints the version' do
    assert_equal "#{DeployPin::VERSION}\n", deploy_pin('version')
  end

  test 'extract_required_files! removes the --require options' do
    args = %w[task x --require a.rb -g I --require=b.rb]

    assert_equal %w[a.rb b.rb], DeployPin::CLI.extract_required_files!(args)
    assert_equal %w[task x -g I], args
  end

  private

    def deploy_pin(*args)
      output, = Dir.chdir(destination) { capture_io { DeployPin::CLI.start(args) } }
      output
    end

    # Runs a command that fails, and returns what it printed to stderr.
    def deploy_pin_failing(*args)
      _, error = capture_io do
        exit_error = assert_raises(SystemExit) { Dir.chdir(destination) { DeployPin::CLI.start(args) } }
        refute_predicate exit_error, :success?
      end
      error
    end
end
