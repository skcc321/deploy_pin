# frozen_string_literal: true

require 'deploy_pin/generators/base'

module DeployPin
  module Generators
    # `deploy_pin upgrade`: creates the migration that upgrades the
    # `deploy_pins` table for resumable tasks (DeployPin 1.7).
    class Upgrade < Base
      templates 'upgrade'
      desc 'Creates the migration that upgrades the deploy_pins table'

      class_option :migrations_path, type: :string, default: 'db/migrate',
                                     desc: 'Directory of the ActiveRecord migrations'

      # Creates the migration that upgrades the `deploy_pins` table.
      # @return [void]
      def copy_migrations
        migration_template 'upgrade_deploy_pins.rb', 'upgrade_deploy_pins'
      end
    end
  end
end
