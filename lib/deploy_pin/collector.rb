# frozen_string_literal: true

module DeployPin
  # Raised when two one-off task files have the same identifier: they would
  # share one completion record.
  class DuplicateIdentifierError < StandardError
    # Raises if one-off tasks share an identifier, naming their files.
    #
    # @param tasks [Array<Task>] parsed tasks
    # @return [void]
    # @raise [DuplicateIdentifierError]
    def self.check!(tasks)
      duplicates = tasks.reject(&:recurring).group_by(&:identifier).select do |identifier, same|
        identifier && same.size > 1
      end
      raise self, message(duplicates) if duplicates.any?
    end

    # @param duplicates [Hash{Integer => Array<Task>}] tasks by shared identifier
    # @return [String]
    def self.message(duplicates)
      messages = duplicates.map do |identifier, same|
        "Tasks #{same.map(&:file).sort.join(' and ')} have the same identifier #{identifier}."
      end
      [*messages, 'Give all but the one that already ran a new identifier, e.g. by generating them again.'].join(' ')
    end
  end

  # Raised by `rake deploy_pin:cleanup` when {DeployPin.cleanup_safe_time_window}
  # is not set: cleanup removes nothing until a window is chosen.
  class CleanupWindowNotSetError < StandardError
    # @return [String]
    def message
      'Set DeployPin.cleanup_safe_time_window to choose how long after its creation a task can be ' \
        'removed, e.g. `cleanup_safe_time_window 6.months` in DeployPin.setup.'
    end
  end

  # Loads the task files and the deployment state tasks, selects the ones
  # matching the identifiers, sorts them by group and identifier, and runs or
  # lists them.
  class Collector
    # @return [Array<String, Integer>] the identifiers tasks are selected by
    attr_reader :identifiers
    # @return [nil] always nil; kept for backward compatibility
    attr_reader :formatter

    # @param identifiers [Array<String, Integer>] groups and task identifiers to select;
    #   see {TaskCriteria} for the `!` prefix and suffix syntax
    def initialize(identifiers:)
      @identifiers = identifiers
    end

    # Runs the selected tasks through {DeployPin.task_wrapper}. A task whose
    # script duplicates an earlier one is marked done but not run.
    #
    # @return [void]
    # @raise [StandardError] a task's error, unless {DeployPin.continue_on_error} is set
    # @raise [DuplicateIdentifierError] if two one-off tasks have the same identifier
    # :reek:TooManyStatements
    def run
      tasks = init_tasks
      tasks.each_with_index do |task, index|
        DeployPin.task_wrapper.call(task, -> { process(tasks, task, index) })
      end
    end
    # :reek:TooManyStatements

    # Prints each selected task with {DeployPin.list_formatter}.
    #
    # @return [void]
    def list
      tasks = init_tasks
      tasks.each_with_index do |task, index|
        DeployPin.list_formatter.call(index, task)
      end
    end

    # Prints the selected tasks group by group with {DeployPin.short_list_formatter}.
    #
    # @return [void]
    def short_list
      groups_tasks = init_tasks.group_by(&:group).to_a
      groups_tasks.inject(0) do |offset, (group, tasks)|
        DeployPin.short_list_formatter.call(group, tasks, offset)
        offset + tasks.count
      end
    end

    # Marks the selected tasks as done without running them.
    #
    # @return [void]
    # :reek:FeatureEnvy
    def mark_done
      tasks = init_tasks
      tasks.each do |task|
        task.prepare
        task.mark
      end
    end
    # :reek:FeatureEnvy

    # Removes the source files and the tests of the one-off tasks created
    # (see {Task#created_at}) more than {DeployPin.cleanup_safe_time_window}
    # ago, whatever the selected identifiers. Recurring and built-in tasks are
    # kept. Only files are removed: the stored records are neither read nor
    # changed, so a removed file that comes back is not run again where it ran.
    #
    # @param dry_run [Boolean] only return the files, without removing them
    # @return [Array<String>] the removed (or, on a dry run, removable) files,
    #   relative to the current directory when they are in it
    # @raise [CleanupWindowNotSetError] if {DeployPin.cleanup_safe_time_window} is not set
    # @raise [DuplicateIdentifierError] if two one-off tasks have the same identifier
    # :reek:BooleanParameter, :reek:ControlParameter and :reek:TooManyStatements
    def cleanup(dry_run: false)
      window = DeployPin.cleanup_safe_time_window
      raise CleanupWindowNotSetError unless window

      before = Time.current - window
      paths = all_tasks.sort.select { |task| task.cleanable?(before:) }.flat_map do |task|
        [task.file, *task.test_files]
      end
      FileUtils.rm_f(paths) unless dry_run
      paths.map { |path| relative_path(path) }
    end

    # The selected tasks without duplicates (tasks whose script is the same as an earlier task's).
    #
    # @return [Array<Task>]
    def executable
      tasks = init_tasks
      tasks.map.with_index do |task, index|
        task if tasks[0..index].none? { |other_task| task.eql?(other_task) }
      end.compact
    end

    # @return [Integer] number of selected tasks
    def tasks_count
      init_tasks.count
    end

    private

      # :reek:FeatureEnvy
      # :reek:TooManyStatements
      def process(tasks, task, index)
        # run only uniq tasks
        executable = tasks[0..index].none? { |other_task| task.eql?(other_task) }

        DeployPin.run_formatter.call(index, tasks.count, task, executable, true)

        task.prepare

        # run if executable
        if executable
          duration = execution_duration { run_task_safely(task) }
          DeployPin.run_formatter.call(index, tasks.count, task, executable, false, duration)
        end

        task.mark # mark each task as done
      end
      # :reek:TooManyStatements
      # :reek:FeatureEnvy

      def run_task_safely(task)
        run_with_timeout(task) { task.run }
      rescue StandardError => e
        raise unless DeployPin.continue_on_error

        DeployPin::Runner.print("[DeployPin] Task #{task.identifier} failed: #{e.message}".red)
        DeployPin::Runner.print('[DeployPin] Continuing due to continue_on_error configuration'.yellow)
      end

      # :reek:UtilityFunction
      def files
        Dir["#{DeployPin.tasks_path}/*.rb"]
      end

      # All the tasks, parsed, before selecting.
      def all_tasks
        tasks = [*DeployPin.deployment_tasks_code, *files].map do |file|
          DeployPin::Task.new(file).tap(&:parse)
        end
        # One-off tasks that share an identifier share their completion record. Checked
        # before selecting: a collision must not hide behind an unselected group.
        DuplicateIdentifierError.check!(tasks)
        tasks
      end

      def init_tasks
        # check if task is suitable
        all_tasks.select { |task| task_criteria.suitable?(task) }.sort # sort by group position in config
      end

      # :reek:UtilityFunction
      def relative_path(path)
        absolute = File.expand_path(path)
        root = "#{Dir.pwd}/"
        absolute.start_with?(root) ? absolute.delete_prefix(root) : path
      end

      def task_criteria
        @task_criteria ||= DeployPin::TaskCriteria.new(identifiers:)
      end

      # :reek:UtilityFunction and :reek:ControlParameter
      def run_with_timeout(task, &block)
        timeout = DeployPin.statement_timeout
        return yield unless timeout && task.under_timeout? && DeployPin::Database.available?

        DeployPin::Database.execute_with_timeout(timeout, **{}, &block)
      end

      def execution_duration
        start_time = Time.now

        yield

        Time.now - start_time
      end
  end
end
