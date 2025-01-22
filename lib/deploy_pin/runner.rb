# frozen_string_literal: true

# executes tasks
module DeployPin
  module Runner
    def self.run(identifiers:)
      DeployPin::Collector.new(identifiers:).run
    end

    def self.list(identifiers:)
      DeployPin::Collector.new(identifiers:).list
    end

    def self.cleanup(identifiers:)
      DeployPin::Collector.new(identifiers:).cleanup
    end

    def self.summary(identifiers:)
      # print summary
      self.print('======= Summary ========')
      self.print("Tasks number: #{DeployPin::Collector.new(identifiers:).tasks_count}")
    end

    def self.print(msg)
      puts(msg) unless Rails.env.test?
    end
  end
end
