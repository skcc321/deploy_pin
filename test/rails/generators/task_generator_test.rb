# frozen_string_literal: true

require 'test_helper'
require 'generators/deploy_pin/task/task_generator'

class DeployPin::TaskGeneratorTest < Rails::Generators::TestCase
  tests DeployPin::TaskGenerator
  destination Rails.root.join('tmp/generators')
  setup :prepare_destination
  setup { DeployPin.test_framework false }

  test 'creates the task file' do
    run_generator %w[backfill_users -g II -a jane]

    task_file = Dir[File.join(destination_root, 'tmp/*_backfill_users.rb')].first
    assert task_file
    content = File.read(task_file)
    assert_match(/^# \d{14}:II$/, content)
    assert_match '# task_title: @jane Backfill Users', content
  end

  test 'takes the options of the DeployPin generator' do
    options = DeployPin::TaskGenerator.class_options.keys.map(&:to_s)
    DeployPin::Generators::Task.class_options.each_key { |option| assert_includes options, option.to_s }
    assert_equal ['-g'], DeployPin::TaskGenerator.class_options[:group].aliases
    assert_equal ['title'], DeployPin::TaskGenerator.arguments.map(&:name)
  end

  test 'uses the fallback group from the initializer' do
    DeployPin.fallback_group 'III'
    run_generator %w[backfill_users]

    assert_match(/^# \d{14}:III$/, File.read(Dir[File.join(destination_root, 'tmp/*.rb')].first))
  end

  test 'creates a parallel task with --parallel' do
    run_generator %w[backfill_users -g I --parallel]

    assert_match 'parallel task code', File.read(Dir[File.join(destination_root, 'tmp/*.rb')].first)
  end

  test 'creates a recurring task' do
    run_generator %w[warm_caches -g I --recurring --identifier 5]

    assert_file 'tmp/r_5_warm_caches.rb', /# 5:I:recurring/
  end

  test 'prints an error if group is missing' do
    DeployPin.instance_variable_set(:@fallback_group, nil)

    error = capture(:stderr) { run_generator %w[title] }

    assert_match 'Missing required option: --group', error
    assert_empty Dir[File.join(destination_root, '**/*.rb')]
  end

  test 'prints an error if group is not present in allowed group' do
    error = capture(:stderr) { run_generator %w[title -g D] }

    assert_match "Group 'D' is not defined in DeployPin.groups", error
  end

  test 'prints an error if the title is missing' do
    error = capture(:stderr) { run_generator %w[-g I] }

    assert_match "No value provided for required arguments 'title'", error
  end

  test 'rails destroy removes the task' do
    run_generator %w[warm_caches -g I --recurring --identifier 5]
    run_generator %w[warm_caches -g I --recurring --identifier 5], behavior: :revoke

    assert_no_file 'tmp/r_5_warm_caches.rb'
  end
end
