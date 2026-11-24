# frozen_string_literal: true

require 'deploy_pin/generators/base'

module DeployPin
  module Generators
    # `deploy_pin install [--storage=mongoid]`: creates the configuration file
    # and, for ActiveRecord, the `deploy_pins` migration.
    class Install < Base
      templates 'install'
      desc 'Creates the DeployPin configuration file and, for ActiveRecord, the deploy_pins migration'

      class_option :storage, type: :string, default: 'active_record', enum: %w[active_record mongoid],
                             desc: 'Storage provider for task records'
      class_option :config_path, type: :string, default: 'config/deploy_pin.rb',
                                 desc: 'Where to create the configuration file'
      class_option :migrations_path, type: :string, default: 'db/migrate',
                                     desc: 'Directory of the ActiveRecord migrations'

      # Creates the `deploy_pins` migration, unless the storage is Mongoid.
      # @return [void]
      def copy_migrations
        return if mongoid?

        # Fail before writing any file: Thor creates the file before rendering the template.
        @activerecord_migration_class = activerecord_migration_class
        migration_template 'create_deploy_pins.rb', 'create_deploy_pins'
      end

      # Creates the configuration file: `config/deploy_pin.rb`, or
      # `config/initializers/deploy_pin.rb` in a Rails app.
      # @return [void]
      def copy_initializer
        template 'deploy_pin.rb', options[:config_path]
      end

      # Reminds Mongoid users to create the indexes.
      # @return [void]
      def mongoid_indexes_hint
        return unless mongoid? && behavior == :invoke

        say 'Create the DeployPin indexes: `rails db:mongoid:create_indexes` in a Rails app, ' \
            'or `DeployPin::MongoidRecord.create_indexes`.'
      end

      private

        # Used by the migration template.
        # @raise [Thor::Error] if ActiveRecord is not installed
        def activerecord_migration_class
          return @activerecord_migration_class if @activerecord_migration_class

          require 'active_record/version'
          "ActiveRecord::Migration[#{::ActiveRecord::VERSION::STRING.to_f}]"
        rescue LoadError
          raise Thor::Error, set_color('ActiveRecord storage needs the activerecord gem. ' \
                                       'Add it to your Gemfile, or use --storage=mongoid.', :red)
        end

        def mongoid?
          options[:storage] == 'mongoid'
        end
    end
  end
end
