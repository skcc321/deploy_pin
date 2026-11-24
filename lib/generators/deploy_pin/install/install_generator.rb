# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/migration'
require 'deploy_pin/generators/base'

module DeployPin
  # `rails g deploy_pin:install [--storage=mongoid]`: creates the initializer
  # and, for ActiveRecord, the `deploy_pins` migration. Outside Rails,
  # `deploy_pin install` ({Generators::Install}) does the same.
  class InstallGenerator < Rails::Generators::Base
    include Rails::Generators::Migration

    # Rails' own migration action, so numbering (timestamped or sequential) and
    # re-runs behave like other Rails generators. The templates are shared with
    # {Generators::Install}, which `deploy_pin install` runs outside Rails.
    source_root File.join(DeployPin::Generators::Base::TEMPLATES_ROOT, 'install')
    desc 'Add the migration & initializer for DeployPin'

    class_option :storage, type: :string, default: 'active_record', enum: %w[active_record mongoid],
                           desc: 'Storage provider for task records'

    # @param path [String] migrations directory
    # @return [String] the next migration timestamp
    def self.next_migration_number(path)
      next_migration_number = current_migration_number(path) + 1
      ActiveRecord::Migration.next_migration_number(next_migration_number)
    end

    # Creates the `deploy_pins` migration, unless the storage is Mongoid.
    # @return [void]
    def copy_migrations
      return if mongoid?

      migration_template 'create_deploy_pins.rb', 'db/migrate/create_deploy_pins.rb'
    end

    # Creates `config/initializers/deploy_pin.rb`.
    # @return [void]
    def copy_initializer
      template 'deploy_pin.rb', 'config/initializers/deploy_pin.rb'
    end

    # Reminds Mongoid users to create the indexes.
    # @return [void]
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
