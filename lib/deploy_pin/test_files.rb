# frozen_string_literal: true

module DeployPin
  # Where the tests of tasks are: the task generator writes them there, and
  # `rake deploy_pin:cleanup` removes them with their tasks.
  module TestFiles
    # Supported test frameworks: the default directory for the tests (used
    # when {DeployPin.tests_path} is not set) and the test file name, where
    # `%<task>s` is the task file name without `.rb`.
    FRAMEWORKS = {
      rspec: { path: 'spec/deploy_pin', file: '%<task>s_spec.rb' }
    }.freeze

    # The test file of a task, in {DeployPin.tests_path} or in the framework's
    # default directory.
    #
    # @param framework [Symbol] one of {FRAMEWORKS}
    # @param task_name [String] the task file name without `.rb`, e.g. `20190401135040_backfill_users`
    # @return [String]
    def self.path(framework, task_name)
      settings = FRAMEWORKS.fetch(framework)
      directory = DeployPin.tests_path.presence || settings[:path]

      File.join(directory.to_s, format(settings[:file], task: task_name))
    end

    # The test files of a task that exist, for every framework, in
    # {DeployPin.tests_path} and in the frameworks' default directories: the
    # framework may have been detected rather than configured, and
    # {DeployPin.tests_path} set after the test was generated.
    #
    # @param task_name [String] the task file name without `.rb`
    # @return [Array<String>]
    def self.existing(task_name)
      paths = FRAMEWORKS.values.product([DeployPin.tests_path.presence, nil]).map do |settings, directory|
        File.join((directory || settings[:path]).to_s, format(settings[:file], task: task_name))
      end
      paths.uniq.select { |path| File.file?(path) }
    end
  end
end
