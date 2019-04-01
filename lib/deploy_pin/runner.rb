# frozen_string_literal: true

# executes tasks
module DeployPin
  module Runner
    def self.run(groups:)
      DeployPin::Collector.new(groups: groups).run do |index, count, task, executable|
        self.print("[#{index + 1}/#{count}] Task #{task.title} #{task.uuid}##{task.group} (#{executable ? 'run' : 'skip'})")
      end
    end

    def self.list(groups:)
      DeployPin::Collector.new(groups: groups).list do |index, count, task|
        self.print("======= Task ##{index} ========".white)

        # print details
        task.details.each do |key, value|
          self.print("#{key}:\t\t#{value}")
        end

        self.print("")
        self.print("<<<")
        self.print task.script.strip.green
        self.print(">>>")
        self.print("")
      end
    end

    def self.summary(groups:)
      # print summary
      self.print("======= Summary ========")
      self.print("tasks number: #{DeployPin::Collector.new(groups: groups).tasks.count}")
    end

    def self.print(msg)
      puts(msg) unless Rails.env.test?
    end
  end
end
