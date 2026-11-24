# frozen_string_literal: true

require 'rails/generators'
require 'deploy_pin/generators/rails_generator'

module DeployPin
  # `rails g deploy_pin:upgrade`: creates the migration that upgrades the
  # `deploy_pins` table. Runs {Generators::Upgrade}.
  class UpgradeGenerator < Rails::Generators::Base
    include DeployPin::Generators::RailsGenerator

    runs DeployPin::Generators::Upgrade
    desc File.read(File.expand_path('USAGE', __dir__))
  end
end
