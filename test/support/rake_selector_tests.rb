# frozen_string_literal: true

require 'rake'

# Tests of the task selectors given on the rake command line, e.g.
# `rake 'deploy_pin:run[I, !75371573753799]'`. They go through Rake's own
# parsing (Rake.application.invoke_task), which splits the argument on commas.
# Included in the plain Ruby and in the Rails suite, which load the tasks.
module RakeSelectorTests
  extend ActiveSupport::Concern

  # Fixtures copied to the tasks directory, by identifier.
  TASK_FILES = {
    '75371573753751' => 'task.rb',          # group I
    '75371573753799' => 'failing_task.rb',  # group I, raises when it runs
    '75371573753752' => 'task_different.rb' # group II
  }.freeze

  included do
    setup do
      TASK_FILES.each_value.with_index(1) do |file, index|
        FileUtils.cp("test/support/files/#{file}", "#{DeployPin.tasks_path}#{index}_#{file}")
      end
      Rake::Task.tasks.each(&:reenable)
    end

    test 'run[I, !id] skips the excluded task within the selected group' do
      rake 'deploy_pin:run[I, !75371573753799]'

      assert_equal %w[75371573753751], done_identifiers
    end

    test 'run[I, II, !id] runs every selector' do
      rake 'deploy_pin:run[I, II, !75371573753799]'

      assert_equal %w[75371573753751 75371573753752], done_identifiers
    end

    test 'run with an excluded group' do
      rake 'deploy_pin:run[75371573753751, II, !I]'

      assert_equal %w[75371573753752], done_identifiers
    end

    test 'run[id!] runs a done task again' do
      DeployPin::Storage.record_class.create(uuid: '75371573753751', completed_at: 1.day.ago)
      ran = []
      DeployPin.task_wrapper(->(task, runner) { ran << task.identifier.to_s && runner.call })

      rake 'deploy_pin:run[75371573753751!, 75371573753752]'

      assert_equal %w[75371573753751 75371573753752], ran
    end

    test 'run without selectors runs all groups and raises on the failing task' do
      assert_raises(RuntimeError) { rake 'deploy_pin:run' }
    end

    test 'mark_done[I, !id] marks the selected tasks only' do
      rake 'deploy_pin:mark_done[I, !75371573753751]'

      assert_equal %w[75371573753799], done_identifiers
    end

    test 'list[I, !id] lists the selected tasks only' do
      listed = []
      DeployPin.list_formatter(->(_index, task) { listed << task.identifier.to_s })

      rake 'deploy_pin:list[I, !75371573753799]'

      assert_equal %w[75371573753751], listed
    end

    test 'short_list[II, id] lists the selected tasks by group' do
      listed = {}
      DeployPin.short_list_formatter(->(group, tasks, _start) { listed[group] = tasks.map { _1.identifier.to_s } })

      rake 'deploy_pin:short_list[II, 75371573753751]'

      assert_equal({ 'I' => %w[75371573753751], 'II' => %w[75371573753752] }, listed)
    end

    test 'an array argument, from Ruby, selects each of its groups and identifiers' do
      Rake::Task['deploy_pin:mark_done'].invoke(%w[I II])

      assert_equal TASK_FILES.keys, done_identifiers
    end

    test 'an array argument with an exclusion, from Ruby' do
      Rake::Task['deploy_pin:run'].invoke(%w[I !75371573753799])

      assert_equal %w[75371573753751], done_identifiers
    end

    test 'array arguments for list and short_list, from Ruby' do
      listed = []
      DeployPin.list_formatter(->(_index, task) { listed << task.identifier.to_s })
      DeployPin.short_list_formatter(->(group, _tasks, _start) { listed << group })

      capture_io do
        Rake::Task['deploy_pin:list'].invoke(%w[II 75371573753751])
        Rake::Task['deploy_pin:short_list'].invoke(%w[II])
      end

      assert_equal %w[75371573753751 75371573753752 II], listed
    end

    test 'integer identifiers, from Ruby' do
      Rake::Task['deploy_pin:run'].invoke(75_371_573_753_751, 75_371_573_753_752)

      assert_equal %w[75371573753751 75371573753752], done_identifiers
    end

    test 'a single argument with commas, from Ruby, is split too' do
      Rake::Task['deploy_pin:run'].invoke('I, !75371573753799')

      assert_equal %w[75371573753751], done_identifiers
    end
  end

  private

    def rake(command)
      capture_io { Rake.application.invoke_task(command) }
    end

    def done_identifiers
      TASK_FILES.keys.select { |uuid| DeployPin::Storage.record_class.find_by(uuid:)&.completed_at }
    end
end
