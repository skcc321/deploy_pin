# frozen_string_literal: true

require 'deploy_pin/generators'

module DeployPin
  module Generators
    # Runs a DeployPin generator as a Rails generator (`rails g deploy_pin:*`).
    # The Rails generator gets the arguments and options of the DeployPin
    # generator, so both take the same command line.
    #
    # @example
    #   class TaskGenerator < Rails::Generators::Base
    #     include DeployPin::Generators::RailsGenerator
    #     runs DeployPin::Generators::Task
    #   end
    module RailsGenerator
      # Settings of Thor arguments and options that are copied to the Rails generator.
      SETTINGS = %i[type default desc banner enum required aliases hide lazy_default repeatable].freeze

      # @param base [Class] a `Rails::Generators::Base` subclass
      # @return [void]
      def self.included(base)
        base.extend(ClassMethods)
      end

      # Class methods of the Rails generator.
      module ClassMethods
        # Sets the DeployPin generator to run, and copies its arguments and
        # options. Options the Rails generator already has (e.g. --force) are kept.
        #
        # @param generator [Class, nil] a {Generators::Base} subclass; omit to read it
        # @param defaults [Hash{Symbol => Object}] option defaults that differ in Rails apps
        # @return [Class] the DeployPin generator
        def runs(generator = nil, **defaults)
          return @runs if generator.nil?

          @runs = generator
          generator.arguments.each { |arg| argument(arg.name.to_sym, **thor_settings(arg)) }
          copy_class_options(generator, defaults)
          # Thor only runs the public methods defined in the generator class itself.
          define_method(:run_deploy_pin) { run_deploy_pin_generator }
          generator
        end

        private

          def copy_class_options(generator, defaults)
            generator.class_options.each_value do |option|
              name = option.name.to_sym
              next if class_options.key?(name)

              overrides = defaults.key?(name) ? { default: defaults[name] } : {}
              class_option(name, **thor_settings(option), **overrides)
            end
          end

          def thor_settings(thor_argument)
            SETTINGS.each_with_object({}) do |key, settings|
              method = key == :desc ? :description : key
              next unless thor_argument.respond_to?(method)

              value = thor_argument.public_send(method)
              settings[key] = value unless value.nil? || value == []
            end
          end
      end

      # Runs the DeployPin generator with this generator's arguments, options,
      # shell, destination and behavior (`rails generate` or `rails destroy`).
      # @return [void]
      def run_deploy_pin_generator
        values = self.class.arguments.map { |arg| public_send(arg.name) }
        config = { destination_root:, shell:, behavior: }

        self.class.runs.new(values, options, config).invoke_all
      end
    end
  end
end
