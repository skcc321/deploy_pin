# frozen_string_literal: true

require 'test_helper'
require_relative '../support/rake_selector_tests'

# The selectors in a Rails app, with the tasks loaded by DeployPin::Engine.
class DeployPin::RailsRakeSelectorsTest < ActiveSupport::TestCase
  include RakeSelectorTests

  Rails.application.load_tasks unless Rake::Task.task_defined?('deploy_pin:run')
end
