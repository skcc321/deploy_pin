# frozen_string_literal: true

require 'thor'
require 'deploy_pin'

module DeployPin
  # Generators for task files, the configuration file and the migrations.
  # They are plain Thor groups, so they run in any Ruby app through the
  # `deploy_pin` command ({CLI}), and in Rails apps through `rails g deploy_pin:*`
  # ({RailsGenerator}).
  module Generators
    # Base class of the DeployPin generators.
    class Base < Thor::Group
      include Thor::Actions

      # Directory of the generator templates, one subdirectory per generator.
      TEMPLATES_ROOT = File.expand_path('templates', __dir__)

      add_runtime_options!

      # @return [Boolean] true, so `deploy_pin` exits with a non-zero status on errors
      def self.exit_on_failure?
        true
      end

      # Sets the templates directory of a generator.
      #
      # @param name [String] subdirectory of {TEMPLATES_ROOT}
      # @return [void]
      def self.templates(name)
        source_root File.join(TEMPLATES_ROOT, name)
      end

      protected

        # Renders a migration template to `<migrations_path>/<timestamp>_<name>.rb`,
        # like `migration_template` of Rails generators. On `revoke` (destroy),
        # removes the existing migration instead.
        #
        # @param source [String] the template
        # @param name [String] the migration name, e.g. `create_deploy_pins`
        # @return [void]
        # @raise [Thor::Error] if a migration with that name exists, unless --force or --skip
        def migration_template(source, name)
          existing = existing_migration(name)
          return delete_migration(existing) if behavior == :revoke
          return if existing && !replace_migration?(existing, name)

          template source, File.join(migrations_path, "#{next_migration_number}_#{name}.rb")
        end

        # @return [String] the migrations directory, relative to the destination root
        def migrations_path
          options[:migrations_path].presence || 'db/migrate'
        end

      private

        # @return [String, nil] the migration path, relative to the destination root
        def existing_migration(name)
          path = Dir.glob(File.join(destination_root, migrations_path, "*_#{name}.rb")).first
          path&.delete_prefix("#{destination_root}/")
        end

        def replace_migration?(existing, name)
          if options[:skip]
            say_status :skip, existing, :yellow
            return false
          end
          if options[:force]
            delete_migration(existing)
            return true
          end

          raise Thor::Error, set_color("Another migration is already named #{name}: #{existing}. " \
                                       'Use --force to replace it or --skip to ignore it.', :red)
        end

        # Thor's remove_file only works on invoke, so this one removes on revoke too.
        def delete_migration(path)
          return unless path

          say_status :remove, path, :red
          FileUtils.rm_f(File.join(destination_root, path)) unless options[:pretend]
        end

        # A UTC timestamp, later than every existing migration.
        def next_migration_number
          numbers = Dir.glob(File.join(destination_root, migrations_path, '*.rb')).map do |path|
            File.basename(path)[/\A\d+/].to_i
          end
          [Time.now.utc.strftime('%Y%m%d%H%M%S'), format('%.14d', (numbers.max || 0) + 1)].max
        end
    end
  end
end
