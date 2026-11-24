# frozen_string_literal: true

require_relative 'boot'

require 'rails'
require 'action_controller/railtie'

MONGOID_STORAGE = ENV['DB_ROLE'] == 'mongodb'

if MONGOID_STORAGE
  require 'mongoid'
else
  require 'active_record/railtie'
end

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)
require 'deploy_pin'

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f

    # Autoload lib/ like a new Rails app does. DeployPin must keep its task
    # files in lib/deploy_pin out of Zeitwerk (see DeployPin::Engine).
    config.autoload_lib(ignore: %w[assets tasks])

    # The dummy ApplicationRecord is ActiveRecord-only.
    Rails.autoloaders.main.ignore(config.root.join('app/models/application_record.rb')) if MONGOID_STORAGE

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
