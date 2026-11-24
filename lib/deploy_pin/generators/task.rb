# frozen_string_literal: true

require 'deploy_pin/generators/base'

module DeployPin
  module Generators
    # `deploy_pin task <title> --group <group> [--parallel] [--recurring --identifier <id>]`
    # (`rails g deploy_pin:task` in a Rails app): creates a task file in
    # {DeployPin.tasks_path}, and a test for it with the configured
    # {DeployPin.test_framework} in {DeployPin.tests_path} (`spec/deploy_pin`
    # for RSpec by default).
    #
    # @example Skip the test, or pick the framework for one task
    #   deploy_pin task backfill_users -g I --skip-test
    #   deploy_pin task backfill_users -g I --test-framework=rspec
    class Task < Base
      # Supported test frameworks: the default directory for the tests (used
      # when {DeployPin.tests_path} is not set) and the test file name, where
      # `%<task>s` is the task file name without `.rb`.
      TEST_FRAMEWORKS = {
        rspec: { path: 'spec/deploy_pin', file: '%<task>s_spec.rb' }
      }.freeze

      # Printed when no test framework is configured and none is detected.
      UNDETECTED_TEST_FRAMEWORK = 'test for the task: no test framework detected. ' \
                                  'Add rspec (rspec-rails in a Rails app) to the :development group, ' \
                                  'or set DeployPin.test_framework :rspec'

      class_option :parallel, type: :boolean, aliases: '-p', desc: 'Use the Parallel task template'
      class_option :recurring, type: :boolean, aliases: '-r', desc: 'Run the task on every deployment'
      class_option :identifier, aliases: '-i', desc: 'Identifier of a recurring task'
      argument :title, required: true, desc: 'Task name, e.g. backfill_user_names'
      class_option :group, aliases: '-g', desc: 'Group of the task (default: DeployPin.fallback_group)'
      class_option :author, aliases: '-a', desc: 'Author shown in the task title (default: $USER)'
      class_option :test_framework, type: :string,
                                    desc: "Test framework for the task's test (default: DeployPin.test_framework)"
      class_option :skip_test, type: :boolean, default: false, desc: 'Do not generate a test for the task'

      templates 'task'
      desc 'Creates a DeployPin task in DeployPin.tasks_path, and a test for it'

      # @param args [Array] Thor arguments, options and configuration
      # @raise [Thor::Error] see {#validate}
      def initialize(*args)
        super

        validate
      end

      # Writes the task file, named after its identifier and title.
      # @return [void]
      def create_task_file
        template_file = if options[:parallel]
                          'parallel_task.rb.erb'
                        else
                          'task.rb.erb'
                        end

        @author = options[:author] || ENV['USER']
        @group = group
        @recurring = options[:recurring]
        @identifier = @recurring ? options[:identifier] : Time.now.strftime('%Y%m%d%H%M%S')
        template template_file, task_path
      end

      # Writes the test for the task, unless tests are turned off.
      # @return [void]
      def create_test_file
        framework = test_framework
        return if framework == false # turned off on purpose
        return say_status(:skip, UNDETECTED_TEST_FRAMEWORK, :yellow) unless framework

        template "#{framework}/task_spec.rb.erb", test_file_path(framework)
      end

      # @return [void]
      # @raise [Thor::Error] if the group is missing or not in {DeployPin.groups},
      #   or the test framework is not one of {TEST_FRAMEWORKS}
      def validate
        raise Thor::Error, set_color('Missing required option: --group', :red) if group.blank?

        unless Array(DeployPin.groups).include?(group)
          raise Thor::Error, set_color("Group '#{group}' is not defined in DeployPin.groups", :red)
        end

        validate_test_framework
      end

      private

        # The --group option, else {DeployPin.fallback_group}. Resolved when the
        # generator runs, after the configuration is loaded.
        def group
          options[:group].presence || DeployPin.fallback_group
        end

        # The helper the spec requires: `rails_helper` in a Rails app (rspec-rails), else `spec_helper`.
        def spec_helper
          rails_app = defined?(::Rails::Application) || File.exist?(File.join(destination_root, 'spec/rails_helper.rb'))
          rails_app ? 'rails_helper' : 'spec_helper'
        end

        # The task file name without the extension, e.g. `20190401135040_backfill_users`.
        def task_name
          @recurring ? "r_#{@identifier}_#{title}" : "#{@identifier}_#{title}"
        end

        def task_path
          "#{DeployPin.tasks_path}/#{task_name}.rb"
        end

        # The test file in {DeployPin.tests_path}, or in the framework's default directory.
        def test_file_path(framework)
          settings = TEST_FRAMEWORKS.fetch(framework)
          directory = DeployPin.tests_path.presence || settings[:path]

          File.join(directory.to_s, format(settings[:file], task: task_name))
        end

        # The --test-framework flag or DeployPin.test_framework, else the detected one.
        #
        # @return [Symbol, false, nil] the framework; false when tests are turned
        #   off (--skip-test, `test_framework false`); nil when none is detected
        def test_framework
          return false if options[:skip_test]

          configured = options[:test_framework].presence || DeployPin.test_framework
          return configured if configured == false

          configured&.to_sym || detected_test_framework
        end

        # RSpec is the only supported framework, detected by its constant.
        def detected_test_framework
          :rspec if defined?(::RSpec)
        end

        def validate_test_framework
          framework = test_framework
          return if !framework || TEST_FRAMEWORKS.key?(framework)

          raise Thor::Error, set_color(
            "Unknown test framework '#{framework}'. Supported: #{TEST_FRAMEWORKS.keys.join(', ')}", :red
          )
        end
    end
  end
end
