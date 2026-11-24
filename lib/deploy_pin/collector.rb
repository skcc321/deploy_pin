# frozen_string_literal: true

module DeployPin
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

      def init_tasks
        [*DeployPin.deployment_tasks_code, *files].map do |file|
          task = DeployPin::Task.new(file)
          task.parse

          # check if task is suitable
          task if task_criteria.suitable?(task)
        end.compact.sort # sort by group position in config
      end

      def task_criteria
        @task_criteria ||= DeployPin::TaskCriteria.new(identifiers:)
      end

      # :reek:UtilityFunction and :reek:ControlParameter
      def run_with_timeout(task, &block)
        return yield unless task.under_timeout? && DeployPin::Database.available?

        DeployPin::Database.execute_with_timeout(DeployPin.statement_timeout, **{}, &block)
      end

      def execution_duration
        start_time = Time.now

        yield

        Time.now - start_time
      end
  end
end
