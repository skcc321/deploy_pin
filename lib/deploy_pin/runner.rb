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

    # Removes the source files and tests of the one-off tasks created more than
    # {DeployPin.cleanup_safe_time_window} ago (see {Collector#cleanup}), and
    # prints each one and how many were removed. A dry run prints only the
    # paths, one per line, so the output can be passed to `git rm`.
    #
    # When some files cannot be removed, the removed ones are still printed
    # before the error is raised.
    #
    # @param dry_run [Boolean] only print the files, without removing them
    # @return [Array<String>] the removed (or, on a dry run, removable) files
    # @raise [CleanupWindowNotSetError] if {DeployPin.cleanup_safe_time_window} is not set
    # @raise [CleanupError] if some files could not be removed
    # :reek:BooleanParameter and :reek:TooManyStatements
    def self.cleanup(dry_run: false)
      paths = DeployPin::Collector.new(identifiers: DeployPin.groups).cleanup(dry_run:)
      return paths.each { |path| self.print(path) } if dry_run

      print_removed(paths)
    rescue DeployPin::CleanupError => e
      print_removed(e.removed)
      raise
    end

    # Prints each removed file and how many there are.
    #
    # @param paths [Array<String>]
    # @return [Array<String>] the paths
    def self.print_removed(paths)
      paths.each { |path| self.print("Removed #{path}") }
      self.print("Removed #{paths.count} #{paths.one? ? 'file' : 'files'}")
      paths
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

    # Variables that name the app environment, by priority, when the app is not a
    # Rails app: Rails, Rack, then Sinatra and other Rack apps.
    ENV_VARIABLES = %w[RAILS_ENV RACK_ENV APP_ENV].freeze

    # Prints a message, except in the test environment.
    #
    # @param msg [String]
    # @return [void]
    def self.print(msg)
      puts(msg) unless test_env?
    end

    # Whether the app runs in its test environment: `Rails.env` in a Rails
    # app, else the first of {ENV_VARIABLES} that is set.
    #
    # @return [Boolean]
    def self.test_env?
      return ::Rails.env.test? if defined?(::Rails.env)

      ENV.values_at(*ENV_VARIABLES).find(&:present?) == 'test'
    end
  end
end
