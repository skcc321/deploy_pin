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

  # Identifiers

  test 'tasks generated within the same second get different identifiers and run independently' do
    travel_to Time.new(2026, 11, 24, 12, 0, 0) do
      run_generator DeployPin::Generators::Task, %w[first_task -g I -a ci --skip-test]
      run_generator DeployPin::Generators::Task, %w[second_task -g II -a ci --skip-test]
    end

    files = generated('tmp/*.rb').sort
    assert_equal %w[tmp/20261124120000_first_task.rb tmp/20261124120001_second_task.rb], files
    files.each do |file|
      write(file, "#{read(file).split('# === task code goes down here ===').first}\n$ran << title\n")
    end

    $ran = [] # rubocop:disable Style/GlobalVars
    DeployPin.tasks_path File.join(destination, 'tmp')
    capture_io { DeployPin::Runner.run(identifiers: %w[I]) }
    capture_io { DeployPin::Runner.run(identifiers: %w[I II]) }

    assert_equal ['@ci First Task', '@ci Second Task'], $ran # rubocop:disable Style/GlobalVars
    assert_predicate DeployPin::Storage.record_class.find_by(uuid: 20_261_124_120_000).completed_at, :present?
    assert_predicate DeployPin::Storage.record_class.find_by(uuid: 20_261_124_120_001).completed_at, :present?
  end

  test 'skips identifiers that existing task files use, by name or header' do
    write 'tmp/20261124120000_old.rb', "# 20261124120000:I\n"
    write 'tmp/renamed.rb', "# 20261124120001:II\n"

    travel_to Time.new(2026, 11, 24, 12, 0, 0) do
      run_generator DeployPin::Generators::Task, %w[new_task -g I --skip-test]
    end

    assert_equal ['tmp/20261124120002_new_task.rb'], generated('tmp/*_new_task.rb')
    assert_match(/^# 20261124120002:I$/, read('tmp/20261124120002_new_task.rb'))
  end

  # Recurring identifiers

  test 'a recurring task needs an identifier' do
    error = assert_raises(Thor::Error) { build_generator(DeployPin::Generators::Task, %w[warm -g I --recurring]) }

    assert_match 'Recurring tasks need an identifier: --identifier <integer>', error.message
  end

  test 'a recurring identifier must be an integer' do
    %w[4x 1.5 abc 5-].each do |identifier|
      error = assert_raises(Thor::Error, identifier) do
        build_generator(DeployPin::Generators::Task, %W[warm -g I --recurring --identifier #{identifier}])
      end

      assert_match "Invalid identifier '#{identifier}': use an integer", error.message
    end
  end

  test 'accepts negative and reserved recurring identifiers' do
    run_generator DeployPin::Generators::Task, %w[late -g I --recurring --identifier=-3 --skip-test]
    run_generator DeployPin::Generators::Task, %w[zero -g I --recurring --identifier 0 --skip-test]

    assert_match '# -3:I:recurring', read('tmp/r_-3_late.rb')
    assert_match '# 0:I:recurring', read('tmp/r_0_zero.rb')
  end

  test 'the deploy_pin command writes no task and no test for a missing or malformed recurring identifier' do
    [%w[--recurring], %w[--recurring --identifier], %w[--recurring --identifier 4x]].each do |flags|
      _, error = capture_io do
        assert_raises(SystemExit) do
          Dir.chdir(destination) { DeployPin::CLI.start(['task', 'warm', '-g', 'I', *flags]) }
        end
      end

      assert_match(/Recurring tasks need an identifier|Invalid identifier/, error, flags.join(' '))
      assert_empty generated('**/*.rb'), flags.join(' ')
    end
  end
end
