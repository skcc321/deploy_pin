# frozen_string_literal: true

require 'test_helper'
require 'generators/deploy_pin/task/task_generator'

# The test that `rails g deploy_pin:task` creates next to each task.
class DeployPin::TaskGeneratorTestFileTest < Rails::Generators::TestCase
  tests DeployPin::TaskGenerator
  destination Rails.root.join('tmp/generators')
  setup :prepare_destination
  setup { DeployPin.test_framework :rspec }

  test 'generates an RSpec test for the task by default' do
    run_generator %w[backfill_users --group I]

    task_file = generated('tmp/*_backfill_users.rb').first
    task_name = File.basename(task_file, '.rb')
    identifier = task_name.split('_').first

    assert_file "spec/deploy_pin/#{task_name}_spec.rb" do |spec|
      assert_match "require 'rails_helper'", spec
      assert_match 'DeployPin.load_tasks', spec
      assert_match "RSpec.describe 'DeployPin task #{task_name}'", spec
      assert_match "Rake::Task['deploy_pin:run'].invoke('#{identifier}')", spec
      assert_match "find_by(uuid: #{identifier})", spec
    end
  end

  test 'generates the test for a recurring task' do
    run_generator %w[warm_caches --group I --recurring --identifier 5]

    assert_file 'tmp/r_5_warm_caches.rb'
    assert_file 'spec/deploy_pin/r_5_warm_caches_spec.rb' do |spec|
      assert_match "Rake::Task['deploy_pin:run'].invoke('5')", spec
      assert_no_match 'is marked as done', spec # recurring tasks are never marked done
    end
  end

  test 'accepts --test-framework=rspec' do
    run_generator %w[backfill_users --group I --test-framework=rspec]

    assert_equal 1, generated('spec/deploy_pin/*_backfill_users_spec.rb').size
  end

  test 'skips the test with --skip-test' do
    run_generator %w[backfill_users --group I --skip-test]

    assert_equal 1, generated('tmp/*_backfill_users.rb').size
    assert_empty generated('spec/**/*_spec.rb')
  end

  test 'skips the test when test_framework is false' do
    DeployPin.test_framework false
    run_generator %w[backfill_users --group I]

    assert_empty generated('spec/**/*_spec.rb')
  end

  test 'prints an error for an unknown test framework' do
    error = capture(:stderr) { run_generator %w[title --group I --test-framework=minitest] }

    assert_match "Unknown test framework 'minitest'. Supported: rspec", error
  end

  test 'creates spec/deploy_pin when it does not exist' do
    refute_path_exists File.join(destination_root, 'spec')

    run_generator %w[backfill_users --group I]

    assert_path_exists File.join(destination_root, 'spec/deploy_pin')
  end

  test 'writes the test to tests_path from the initializer' do
    DeployPin.tests_path 'spec/data_migrations'
    run_generator %w[backfill_users --group I]

    assert_equal 1, generated('spec/data_migrations/*_backfill_users_spec.rb').size
    assert_empty generated('spec/deploy_pin/*_spec.rb')
  end

  test 'detects RSpec when the RSpec constant is loaded' do
    DeployPin.remove_instance_variable(:@test_framework)
    Object.const_set(:RSpec, Module.new)

    run_generator %w[backfill_users --group I]

    assert_equal 1, generated('spec/deploy_pin/*_backfill_users_spec.rb').size
  ensure
    Object.send(:remove_const, :RSpec)
  end

  test 'skips the test with a note when RSpec is not loaded and nothing is configured' do
    DeployPin.remove_instance_variable(:@test_framework)
    refute defined?(::RSpec)

    output = run_generator %w[backfill_users --group I]

    assert_equal 1, generated('tmp/*_backfill_users.rb').size
    assert_empty generated('spec/**/*_spec.rb')
    assert_match 'no test framework detected', output
  end

  private

    def generated(pattern)
      Dir[File.join(destination_root, pattern)]
    end
end
