# frozen_string_literal: true

# executes tasks
module DeployPin
  class Collector
    attr_reader :identifiers, :formatter

    def initialize(identifiers:)
      @identifiers = identifiers
    end

    # :reek:TooManyStatements
    def run
      # cache tasks
      tasks = init_tasks
      tasks.each_with_index do |task, index|
        DeployPin.task_wrapper.call(task, -> { process(tasks, task, index) })
      end
    end
    # :reek:TooManyStatements

    def list
      tasks = init_tasks
      tasks.each_with_index do |task, index|
        DeployPin.list_formatter.call(index, task)
      end
    end

    def short_list
      groups_tasks = init_tasks.group_by(&:group).to_a
      groups_tasks.inject(0) do |offset, (group, tasks)|
        DeployPin.short_list_formatter.call(group, tasks, offset)
        offset + tasks.count
      end
    end

    def executable
      # cache tasks
      tasks = init_tasks
      tasks.map.with_index do |task, index|
        task if tasks[0..index].none? { |other_task| task.eql?(other_task) }
      end.compact
    end

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
          duration = execution_duration { run_with_timeout(task) { task.run } }
          DeployPin.run_formatter.call(index, tasks.count, task, executable, false, duration)
        end

        task.mark # mark each task as done
      end
      # :reek:TooManyStatements
      # :reek:FeatureEnvy

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
        return yield unless task.under_timeout?

        DeployPin::Database.execute_with_timeout(DeployPin.statement_timeout, **{}, &block)
      end

      def execution_duration
        start_time = Time.now

        yield

        Time.now - start_time
      end
  end
end
