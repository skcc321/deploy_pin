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
      _tasks = tasks
      _tasks.each_with_index do |task, index|
        DeployPin.task_wrapper.call(task, -> { process(_tasks, task, index) })
      end
    end
    # :reek:TooManyStatements

    def list
      _tasks = tasks
      _tasks.each_with_index do |task, index|
        DeployPin.list_formatter.call(index, task)
      end
    end

    def executable
      # cache tasks
      _tasks = tasks
      _tasks.map.with_index do |task, index|
        task if _tasks[0..index].none? { |_task| task.eql?(_task) }
      end.compact
    end

    def tasks_count
      tasks.count
    end

    private

      # :reek:FeatureEnvy
      # :reek:TooManyStatements
      def process(cached_tasks, task, index)
        # run only uniq tasks
        executable = cached_tasks[0..index].none? { |_task| task.eql?(_task) }

        DeployPin.run_formatter.call(index, cached_tasks.count, task, executable, true)

        # run if executable
        if executable
          duration = execution_duration { run_with_timeout(task) { task.run } }
          DeployPin.run_formatter.call(index, cached_tasks.count, task, executable, false, duration)
        end

        # mark each task as done
        task.mark unless task.done?
      end
      # :reek:TooManyStatements
      # :reek:FeatureEnvy

      # :reek:UtilityFunction
      def files
        Dir["#{DeployPin.tasks_path}/*.rb"]
      end

      def tasks
        files.map do |file|
          task = DeployPin::Task.new(file)
          task.parse_file

          # check if task is suitable
          task if task_criteria.suitable?(task)
        end.compact.sort # sort by group position in config
      end

      def task_criteria
        @task_criteria ||= DeployPin::TaskCriteria.new(identifiers: identifiers)
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
