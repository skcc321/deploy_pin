# frozen_string_literal: true

# executes tasks
module DeployPin
  module Runner
    def self.run(identifiers:)
      DeployPin::Collector.new(identifiers: identifiers).run do |index, count, task, executable, start:|
        end_of_msg = if executable
                       start ? '(Run)' : "(Done)\n\n"
                     else
                       "(Skip)\n\n"
                     end

        self.print("[#{index + 1}/#{count}] #{task_meta(task)} #{end_of_msg}")
      end
    end

    def self.list(identifiers:)
      DeployPin::Collector.new(identifiers: identifiers).list do |index, _count, task|
        self.print("======= Task ##{index} ========".white)

        # print details
        task.details.each do |key, value|
          self.print("#{key}:\t\t#{value}")
        end

        self.print('')
        self.print('<<<')
        self.print task.script.strip.green
        self.print('>>>')
        self.print('')
      end
    end

    def self.summary(identifiers:)
      # print summary
      self.print('======= Summary ========')
      self.print("tasks number: #{DeployPin::Collector.new(identifiers: identifiers).tasks_count}")
    end

    def self.print(msg)
      puts(msg) unless Rails.env.test?
    end

    def self.task_meta(task)
      "Task #{task.title} #{task.uuid}##{task.group}"
    end
  end
end
