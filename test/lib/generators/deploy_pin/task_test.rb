# frozen_string_literal: true

require 'test_helper'

class DeployPin::Generators::TaskTest < DeployPin::GeneratorTestCase
  setup { DeployPin.test_framework :rspec }

  test 'creates the task file with its header' do
    run_generator DeployPin::Generators::Task, %w[backfill_users --group II --author jane --skip-test]

    files = generated('tmp/*_backfill_users.rb')
    assert_equal 1, files.size
    assert_match %r{\Atmp/\d{14}_backfill_users\.rb\z}, files.first

    task = DeployPin::Task.new(File.join(destination, files.first))
    task.parse
    assert_equal File.basename(files.first).to_i, task.identifier
    assert_equal 'II', task.group
    assert_equal '@jane Backfill Users', task.title
    assert_nil task.recurring
    assert_match 'ProgressBar.create', task.script
  end

  test 'titleizes camel case titles' do
    run_generator DeployPin::Generators::Task, %w[BackfillUserNames -g I -a jane --skip-test]

    assert_match '# task_title: @jane Backfill User Names', read(generated('tmp/*.rb').first)
  end

  test 'uses $USER as the author by default' do
    user = ENV.fetch('USER', nil)
    ENV['USER'] = 'joe'
    run_generator DeployPin::Generators::Task, %w[backfill_users -g I --skip-test]

    assert_match '# task_title: @joe Backfill Users', read(generated('tmp/*.rb').first)
  ensure
    ENV['USER'] = user
  end

  test 'creates a parallel task with --parallel' do
    run_generator DeployPin::Generators::Task, %w[backfill_users -g I --parallel --skip-test]

    assert_match '=== parallel task code goes down here ===', read(generated('tmp/*.rb').first)
  end

  test 'creates a recurring task with --recurring' do
    run_generator DeployPin::Generators::Task, %w[warm_caches -g III --recurring --identifier 5 --skip-test]

    assert_equal ['tmp/r_5_warm_caches.rb'], generated('tmp/*.rb')
    assert_match '# 5:III:recurring', read('tmp/r_5_warm_caches.rb')
  end

  test 'uses the fallback group when --group is not given' do
    DeployPin.fallback_group 'III'
    run_generator DeployPin::Generators::Task, %w[backfill_users --skip-test]

    assert_match(/\A# \d{14}:III$/, read(generated('tmp/*.rb').first).lines[2])
  end

  test 'raises error if group is missing' do
    DeployPin.instance_variable_set(:@fallback_group, nil)

    error = assert_raises(Thor::Error) { build_generator(DeployPin::Generators::Task, %w[title]) }
    assert_match 'Missing required option: --group', error.message
  end

  test 'raises error if the title is missing' do
    assert_raises(Thor::RequiredArgumentMissingError) { build_generator(DeployPin::Generators::Task, %w[-g I]) }
  end

  test 'raises error if group is not present in allowed groups' do
    error = assert_raises(Thor::Error) { build_generator(DeployPin::Generators::Task, %w[title -g D]) }
    assert_match "Group 'D' is not defined in DeployPin.groups", error.message
  end

  test 'exits with an error from the command line' do
    _, error = capture_io do
      assert_raises(SystemExit) { DeployPin::Generators::Task.start(%w[title -g D], destination_root: destination) }
    end

    assert_match "Group 'D' is not defined", error
    assert_empty generated('**/*.rb')
  end

  test 'revoke removes the task' do
    run_generator DeployPin::Generators::Task, %w[warm_caches -g I --recurring --identifier 5]
    run_generator DeployPin::Generators::Task, %w[warm_caches -g I --recurring --identifier 5], behavior: :revoke

    assert_empty generated('**/*.rb')
  end

  # Tests generated next to the task

  test 'generates an RSpec test for the task by default' do
    run_generator DeployPin::Generators::Task, %w[backfill_users --group I]

    task_name = File.basename(generated('tmp/*_backfill_users.rb').first, '.rb')
    identifier = task_name.split('_').first

    spec = read("spec/deploy_pin/#{task_name}_spec.rb")
    assert_match "require 'spec_helper'", spec
    assert_match "RSpec.describe 'DeployPin task #{task_name}'", spec
    assert_match 'DeployPin.load_tasks unless', spec
    assert_no_match 'Rails', spec
    assert_match "Rake::Task['deploy_pin:run'].invoke('#{identifier}')", spec
    assert_match "find_by(uuid: #{identifier})", spec
    assert_match 'is marked as done', spec
  end

  test 'requires rails_helper when the app has spec/rails_helper.rb' do
    write 'spec/rails_helper.rb'

    run_generator DeployPin::Generators::Task, %w[backfill_users --group I]

    spec = read(generated('spec/deploy_pin/*_spec.rb').first)
    assert_match "require 'rails_helper'", spec
    assert_match 'Rails.application.load_tasks unless', spec
  end

  test 'generates the test for a recurring task' do
    run_generator DeployPin::Generators::Task, %w[warm_caches --group I --recurring --identifier 5]

    spec = read('spec/deploy_pin/r_5_warm_caches_spec.rb')
    assert_match "Rake::Task['deploy_pin:run'].invoke('5')", spec
    assert_no_match 'is marked as done', spec # recurring tasks are never marked done
  end

  test 'accepts --test-framework=rspec' do
    DeployPin.test_framework false
    run_generator DeployPin::Generators::Task, %w[backfill_users --group I --test-framework=rspec]

    assert_equal 1, generated('spec/deploy_pin/*_backfill_users_spec.rb').size
  end

  test 'skips the test with --skip-test' do
    run_generator DeployPin::Generators::Task, %w[backfill_users --group I --skip-test]

    assert_equal 1, generated('tmp/*_backfill_users.rb').size
    assert_empty generated('spec/**/*_spec.rb')
  end

  test 'skips the test when test_framework is false' do
    DeployPin.test_framework false
    run_generator DeployPin::Generators::Task, %w[backfill_users --group I]

    assert_empty generated('spec/**/*_spec.rb')
  end

  test 'raises error for an unknown test framework' do
    error = assert_raises(Thor::Error) do
      build_generator(DeployPin::Generators::Task, %w[title -g I --test-framework minitest])
    end

    assert_match "Unknown test framework 'minitest'. Supported: rspec", error.message
  end

  test 'writes the test to tests_path from the configuration' do
    DeployPin.tests_path 'spec/data_migrations'
    run_generator DeployPin::Generators::Task, %w[backfill_users --group I]

    assert_equal 1, generated('spec/data_migrations/*_backfill_users_spec.rb').size
    assert_empty generated('spec/deploy_pin/*_spec.rb')
  end

  test 'detects RSpec when the RSpec constant is loaded' do
    DeployPin.remove_instance_variable(:@test_framework)
    Object.const_set(:RSpec, Module.new)

    run_generator DeployPin::Generators::Task, %w[backfill_users --group I]

    assert_equal 1, generated('spec/deploy_pin/*_backfill_users_spec.rb').size
  ensure
    Object.send(:remove_const, :RSpec)
  end

  test 'skips the test with a note when RSpec is not loaded and nothing is configured' do
    DeployPin.remove_instance_variable(:@test_framework)
    refute defined?(::RSpec)

    output, = run_generator DeployPin::Generators::Task, %w[backfill_users --group I]

    assert_equal 1, generated('tmp/*_backfill_users.rb').size
    assert_empty generated('spec/**/*_spec.rb')
    assert_match 'no test framework detected', output
  end
end
