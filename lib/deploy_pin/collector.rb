# frozen_string_literal: true

# executes tasks
module DeployPin
  class Collector
    attr_reader :groups

    def initialize(groups:)
      @groups = groups
    end

    def files
      Dir["#{DeployPin.tasks_path}/*.rb"]
    end

    def tasks
      files.map do |file|
        task = DeployPin::Task.new(file)
        task.parse_file

        next if task.done?  # task is done
        next unless groups.include?(task.group) # group mismatch

        task
      end.compact.sort # sort by group position in config
    end

    def run
      count = tasks.count

      tasks.each_with_index do |task, index|
        yield(index, count, task)

        # run only uniq tasks
        # task.run if tasks.none? { |_task| task.eql?(_task) }
        task.run

        # mark each task as done
        task.mark
      end
    end

    def list
      count = tasks.count

      tasks.each_with_index do |task, index|
        yield(index, count, task)
      end
    end
  end
end
