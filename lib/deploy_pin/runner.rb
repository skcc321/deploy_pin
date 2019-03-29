# frozen_string_literal: true

# executes tasks
module DeployPin
  module Runner
    def self.run(groups:)
      DeployPin::Collector.new(groups: groups).run do |index, count, task|
        puts("[#{index + 1}/#{count}] Task #{task.title} #{task.uuid}##{task.group}")
      end
    end

    def self.list(groups:)
      DeployPin::Collector.new(groups: groups).list do |index, count, task|
        puts("======= Task ##{index} ========".white)

        # print details
        task.details.each do |key, value|
          puts "#{key}:\t\t#{value}"
        end

        puts("")
        puts("<<<")
        puts task.script.strip.green
        puts(">>>")
        puts("")
      end
    end

    def self.summary(groups:)
      # print summary
      puts("======= summary ========")
      puts("tasks number: #{DeployPin::Collector.new(groups: groups).tasks.count}")
    end
  end
end
