# frozen_string_literal: true

require 'erb'
require 'yaml'

module Dummy
  # Connects ActiveRecord to the database of DB_ROLE, and creates and migrates it.
  module Database
    module_function

    def config
      yaml = ERB.new(File.read(File.join(Dummy::ROOT, 'config/database.yml'))).result
      ActiveRecord::Base.configurations = YAML.safe_load(yaml, aliases: true)
      ActiveRecord::Base.configurations.configs_for(env_name: Dummy::ENV_NAME, name: Dummy::DB_ROLE)
    end

    def connect
      ActiveRecord::Base.establish_connection(config)
    end

    # Creates the database if it does not exist, and runs pending migrations.
    def prepare
      begin
        connect.with_connection(&:verify!)
      rescue ActiveRecord::NoDatabaseError
        ActiveRecord::Tasks::DatabaseTasks.create(config)
        connect
      end

      ActiveRecord::Migration.verbose = false
      ActiveRecord::MigrationContext.new(File.join(Dummy::ROOT, 'db/migrate')).migrate
    end
  end
end
