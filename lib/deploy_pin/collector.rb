# frozen_string_literal: true

# executes tasks
module DeployPin
  class Collector
    attr_reader :identifiers

    def initialize(identifiers:)
      @identifiers = identifiers
    end

    def run
      # cache tasks
      _tasks = tasks
      _tasks.each_with_index do |task, index|
        # run only uniq tasks
        executable = _tasks[0..index].none? { |_task| task.eql?(_task) }

        yield(index, _tasks.count, task, executable)

        # run if executable
        if executable
          run_with_timeout(!task.explicit_timeout? && !task.parallel?) do
            task.run
          end
        end

        # mark each task as done
        task.mark unless task.done?
      end
    end

    def list
      _tasks = tasks
      _tasks.each_with_index do |task, index|
        yield(index, _tasks.count, task)
      end
    end

    def exacutable
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
      def run_with_timeout(under_timeout, &block)
        return yield unless under_timeout

        DeployPin::Database.execute_with_timeout(DeployPin.statement_timeout, **{}, &block)
      end
  end
end
