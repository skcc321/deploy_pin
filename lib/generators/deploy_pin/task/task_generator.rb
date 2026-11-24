# frozen_string_literal: true

require 'rails/generators'
require 'deploy_pin/generators/rails_generator'

module DeployPin
  # `rails g deploy_pin:task <title> --group <group>`: creates a task and its
  # test. Runs {Generators::Task}, see there for the options.
  class TaskGenerator < Rails::Generators::Base
    include DeployPin::Generators::RailsGenerator

    runs DeployPin::Generators::Task
    desc File.read(File.expand_path('USAGE', __dir__))
  end
end
