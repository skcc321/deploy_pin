# frozen_string_literal: true

module DeployPin
  class InstallGenerator < Rails::Generators::Base
    include Rails::Generators::Migration

    source_root File.expand_path('templates', __dir__)
    desc 'Add the migration & initializer for DeployPin'

    class_option :storage, type: :string, default: 'active_record', enum: %w[active_record mongoid],
                           desc: 'Storage provider for task records'

    def self.next_migration_number(path)
      next_migration_number = current_migration_number(path) + 1
      ActiveRecord::Migration.next_migration_number(next_migration_number)
    end

    def copy_migrations
      return if mongoid?

      migration_template 'create_deploy_pins.rb', 'db/migrate/create_deploy_pins.rb'
    end

    def copy_initializer
      template 'deploy_pin.rb', 'config/initializers/deploy_pin.rb'
    end

    def mongoid_indexes_hint
      say 'Run `rails db:mongoid:create_indexes` to create the DeployPin indexes.' if mongoid?
    end

    private

      # Used by the migration template.
      # :reek:UtilityFunction
      def activerecord_migration_class
        "ActiveRecord::Migration[#{::ActiveRecord::Migration.current_version}]"
      end

      def mongoid?
        options[:storage] == 'mongoid'
      end
  end
end
