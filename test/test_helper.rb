# frozen_string_literal: true

# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'

require 'simplecov'
require 'simplecov-review'
SimpleCov.start do
  formatter SimpleCov::Formatter::ReviewFormatter
end

require_relative '../test/dummy/config/environment'
ActiveRecord::Migrator.migrations_paths = [File.expand_path('../test/dummy/db/migrate', __dir__)]
require 'rails/test_help'
require 'fileutils'

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_paths=)
  ActiveSupport::TestCase.fixture_paths = [File.expand_path('fixtures', __dir__)]
  ActionDispatch::IntegrationTest.fixture_paths = ActiveSupport::TestCase.fixture_paths
  ActiveSupport::TestCase.file_fixture_path = "#{File.expand_path('fixtures', __dir__)}/files"
  ActiveSupport::TestCase.fixtures :all
end

ActiveSupport::TestCase.setup do
  DeployPin.remove_instance_variable(:"@deployment_state_transition") if DeployPin.enabled?(:deployment_state_transition)

  DeployPin.setup do
    tasks_path './tmp/'
    groups %w[I II III]
    fallback_group 'I'
    statement_timeout 0.2.second # 200 ms
  end

  # clean
  DeployPin::Record.delete_all
  ::FileUtils.rm_rf(DeployPin.tasks_path, secure: true)
  ::FileUtils.mkdir(DeployPin.tasks_path)
end

ActiveSupport::TestCase.teardown do
  ::FileUtils.rm_rf(DeployPin.tasks_path, secure: true)
end
