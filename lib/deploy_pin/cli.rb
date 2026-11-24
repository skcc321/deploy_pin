# frozen_string_literal: true

require 'thor'
require 'deploy_pin'
require 'deploy_pin/generators'

module DeployPin
  # The `deploy_pin` command: the generators for any Ruby app. In a Rails
  # app, `rails g deploy_pin:*` runs the same generators.
  #
  # Before a command runs, the configuration is loaded with
  # {DeployPin.load_config}: the files given with `--require`, else
  # `config/deploy_pin.rb` (or `config/initializers/deploy_pin.rb`).
  #
  # @example
  #   deploy_pin install
  #   deploy_pin task backfill_user_names -g I
  #   deploy_pin task backfill_user_names -g I --require config/environment.rb
  class CLI < Thor
    # Option that loads files before the command, e.g. `--require config/environment.rb`.
    REQUIRE_OPTION = '--require'
    # Commands that run without loading the configuration.
    NO_CONFIG_COMMANDS = %w[help -h --help version].freeze

    package_name 'deploy_pin'

    # @return [Boolean] true, so errors exit with a non-zero status
    def self.exit_on_failure?
      true
    end

    # Loads the configuration, then runs the command.
    #
    # @param given_args [Array<String>] command line arguments
    # @param config [Hash] Thor configuration
    # @return [void]
    def self.start(given_args = ARGV, config = {})
      args = given_args.dup
      files = extract_required_files!(args)
      begin
        DeployPin.load_config(files) unless args.empty? || NO_CONFIG_COMMANDS.include?(args.first)
      rescue ArgumentError => e
        (config[:shell] || Thor::Base.shell.new).error(set_color(e.message, :red))
        exit(1)
      end

      super(args, config)
    end

    # Removes every `--require FILE` (or `--require=FILE`) from the arguments.
    #
    # @param args [Array<String>] command line arguments, changed in place
    # @return [Array<String>] the files
    def self.extract_required_files!(args)
      files = []
      while (index = args.index { |arg| arg == REQUIRE_OPTION || arg.start_with?("#{REQUIRE_OPTION}=") })
        option = args.delete_at(index)
        files << (option.include?('=') ? option.split('=', 2).last : args.delete_at(index))
      end
      files.compact
    end

    # Colors a message like Thor's shell does.
    # @return [String]
    def self.set_color(...)
      Thor::Base.shell.new.set_color(...)
    end

    register Generators::Install, 'install', 'install [--storage=mongoid]',
             'Create config/deploy_pin.rb and, for ActiveRecord, the deploy_pins migration'
    register Generators::Task, 'task', 'task TITLE -g GROUP [--require config/environment.rb]',
             'Create a task in DeployPin.tasks_path, and a test for it'
    register Generators::Upgrade, 'upgrade', 'upgrade',
             'Create the migration that upgrades the deploy_pins table'

    desc 'version', 'Print the DeployPin version'
    # Prints the DeployPin version.
    # @return [void]
    def version
      puts DeployPin::VERSION
    end
  end
end
