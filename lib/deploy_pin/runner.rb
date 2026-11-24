# frozen_string_literal: true

module DeployPin
  # Entry point used by the `deploy_pin:*` rake tasks.
  #
  # @example Run all pending tasks of groups I and II
  #   DeployPin::Runner.run(identifiers: %w[I II])
  module Runner
    # Runs the selected tasks that have not been done yet.
    #
    # @param identifiers [Array<String, Integer>] groups and task identifiers to select;
    #   see {TaskCriteria} for the `!` prefix and suffix syntax
    # @return [void]
    # @raise [StandardError] a task's error, unless {DeployPin.continue_on_error} is set
    def self.run(identifiers:)
      DeployPin::Collector.new(identifiers:).run
    end

    # Prints each selected task, including its script, with {DeployPin.list_formatter}.
    #
    # @param identifiers [Array<String, Integer>] groups and task identifiers to select;
    #   see {TaskCriteria} for the `!` prefix and suffix syntax
    # @return [void]
    def self.list(identifiers:)
      DeployPin::Collector.new(identifiers:).list
    end

    # Prints the selected tasks grouped by group, with {DeployPin.short_list_formatter}.
    #
    # @param identifiers [Array<String, Integer>] groups and task identifiers to select;
    #   see {TaskCriteria} for the `!` prefix and suffix syntax
    # @return [void]
    def self.short_list(identifiers:)
      DeployPin::Collector.new(identifiers:).short_list
    end

    # Marks the selected tasks as done without running them.
    #
    # @param identifiers [Array<String, Integer>] groups and task identifiers to select;
    #   see {TaskCriteria} for the `!` prefix and suffix syntax
    # @return [void]
    def self.mark_done(identifiers:)
      DeployPin::Collector.new(identifiers:).mark_done
    end

    # Prints how many tasks are selected.
    #
    # @param identifiers [Array<String, Integer>] groups and task identifiers to select;
    #   see {TaskCriteria} for the `!` prefix and suffix syntax
    # @return [void]
    def self.summary(identifiers:)
      # print summary
      self.print('======= Summary ========')
      self.print("Tasks number: #{DeployPin::Collector.new(identifiers:).tasks_count}")
    end

    # Prints a message, except in the test environment.
    #
    # @param msg [String]
    # @return [void]
    def self.print(msg)
      puts(msg) unless Rails.env.test?
    end
  end
end
