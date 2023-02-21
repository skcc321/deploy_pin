# frozen_string_literal: true

# executes tasks
module DeployPin
  class Collector
    include ActionView::Helpers::DateHelper

    attr_reader :identifiers, :formatter

    def initialize(identifiers:, formatter: ->(*) {})
      @identifiers = identifiers
      @formatter = formatter
    end

    def run
      # cache tasks
      _tasks = tasks
      _tasks.each_with_index do |task, index|
        # run only uniq tasks
        executable = _tasks[0..index].none? { |_task| task.eql?(_task) }

        formatter.call(index, _tasks.count, task, executable, true)

        # run if executable
        if executable
          time = execution_time do
            run_with_timeout(task) { task.run }
          end

          formatter.call(index, _tasks.count, task, executable, false, time)
        end

        # mark each task as done
        task.mark unless task.done?
      end
    end

    def list
      _tasks = tasks
      _tasks.each_with_index do |task, index|
        formatter.call(index, _tasks.count, task)
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
        return yield unless under_timeout(task)

        DeployPin::Database.execute_with_timeout(DeployPin.statement_timeout, **{}, &block)
      end

      def under_timeout(task)
        !task.explicit_timeout? && !task.parallel?
      end

      def execution_time
        start_time = Time.now

        yield

        time_ago_in_words(start_time)
      end
  end
end
