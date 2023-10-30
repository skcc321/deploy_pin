# frozen_string_literal: true

# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'

require 'simplecov'
require 'simplecov_small_badge'
require 'simplecov-review'

SimpleCov.start do
  SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::ReviewFormatter,
    SimpleCovSmallBadge::Formatter
  ])
end

# configure any options you want for SimpleCov::Formatter::BadgeFormatter
SimpleCovSmallBadge.configure do |config|
  # does not created rounded borders
  config.rounded_border = true
  # set the background for the title to darkgrey
  config.background = '#ffffcc'
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
  if DeployPin.enabled?(:deployment_state_transition)
    DeployPin.remove_instance_variable(:"@deployment_state_transition")
  end

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
