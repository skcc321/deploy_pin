# frozen_string_literal: true

require 'rails/generators'
require 'deploy_pin/generators/rails_generator'

module DeployPin
  # `rails g deploy_pin:install [--storage=mongoid]`: creates the initializer
  # and, for ActiveRecord, the `deploy_pins` migration. Runs {Generators::Install}.
  class InstallGenerator < Rails::Generators::Base
    include DeployPin::Generators::RailsGenerator

    runs DeployPin::Generators::Install, config_path: 'config/initializers/deploy_pin.rb'
    desc File.read(File.expand_path('USAGE', __dir__))
  end
end
