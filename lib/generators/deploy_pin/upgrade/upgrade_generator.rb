# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/migration'
require 'deploy_pin/generators/base'

module DeployPin
  # This generator is used to generate the migration file for upgrading db schema for 1.7 version support.
  class UpgradeGenerator < Rails::Generators::Base
    include Rails::Generators::Migration

    # Rails' own migration action, so numbering (timestamped or sequential) and
    # re-runs behave like other Rails generators. The templates are shared with
    # {Generators::Upgrade}, which `deploy_pin upgrade` runs outside Rails.
    source_root File.join(DeployPin::Generators::Base::TEMPLATES_ROOT, 'upgrade')
    desc 'Add the upgrade migration for DeployPin.'

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
