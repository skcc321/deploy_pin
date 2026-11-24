# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/migration'
require 'deploy_pin/generators/base'

module DeployPin
  # `rails g deploy_pin:upgrade`: creates the migration that upgrades a
  # `deploy_pins` table created before DeployPin 1.7 for resumable tasks.
  class UpgradeGenerator < Rails::Generators::Base
    include Rails::Generators::Migration

    # Rails' own migration action, so numbering (timestamped or sequential) and
    # re-runs behave like other Rails generators. The templates are shared with
    # {Generators::Upgrade}, which `deploy_pin upgrade` runs outside Rails.
    source_root File.join(DeployPin::Generators::Base::TEMPLATES_ROOT, 'upgrade')
    desc File.read(File.expand_path('USAGE', __dir__))

    # @param path [String] migrations directory
    # @return [String] the next migration timestamp
    def self.next_migration_number(path)
      next_migration_number = current_migration_number(path) + 1
      ActiveRecord::Migration.next_migration_number(next_migration_number)
    end

    # Creates the migration that upgrades the `deploy_pins` table.
    # @return [void]
    def copy_migrations
      migration_template 'upgrade_deploy_pins.rb', 'db/migrate/upgrade_deploy_pins.rb'
    end
  end
end
