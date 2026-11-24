# frozen_string_literal: true

module DeployPin
  # Rails engine that loads the `deploy_pin:*` rake tasks.
  class Engine < ::Rails::Engine
    isolate_namespace DeployPin

    # Task files (`20190401135040_backfill_users.rb`) are not constants, so
    # Zeitwerk must not autoload them. Without this, an app that autoloads
    # `lib/` (`config.autoload_lib`, the default since Rails 7.1) fails to
    # boot once a task exists in `lib/deploy_pin`.
    initializer 'deploy_pin.ignore_tasks_path', after: :load_config_initializers do |app|
      tasks_path = DeployPin.tasks_path
      next if tasks_path.blank?

      Rails.autoloaders.each { |loader| loader.ignore(app.root.join(tasks_path)) }
    end
  end
end
