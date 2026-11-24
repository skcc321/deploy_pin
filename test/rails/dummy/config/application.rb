# frozen_string_literal: true

require_relative 'boot'

require 'rails'

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

# A minimal Rails app: the Rails test suite (test/rails) checks DeployPin's
# Rails integration with it. The main suite uses the plain Ruby app in test/dummy.
module Dummy
  class Application < Rails::Application
    config.root = File.expand_path('..', __dir__)
    config.load_defaults Rails::VERSION::STRING.to_f

    # Autoload lib/ like a new Rails app does. DeployPin must keep its task
    # files in lib/deploy_pin out of Zeitwerk (see DeployPin::Engine).
    config.autoload_lib(ignore: %w[assets tasks])

    # The dummy ApplicationRecord is ActiveRecord-only.
    Rails.autoloaders.main.ignore(config.root.join('app/models/application_record.rb')) if MONGOID_STORAGE

    config.logger = Logger.new(File::NULL)
  end
end
