# frozen_string_literal: true

# The plain Ruby test suite: it runs against the app in test/dummy, which
# does not use Rails. The Rails integration is tested in test/rails.
ENV['APP_ENV'] = 'test'

require 'simplecov'
require 'simplecov-review'
SimpleCov.start do
  command_name "test:#{ENV.fetch('DB_ROLE', 'default')}"
  formatter SimpleCov::Formatter::ReviewFormatter
end

require_relative 'dummy/config/environment'
abort 'The plain Ruby suite must run without Rails' if defined?(::Rails)

if DeployPin::Database.available?
  Dummy::Database.prepare
else
  DeployPin::Storage.record_class.create_indexes
end

require 'active_support/test_case'
require 'active_support/testing/autorun'
require 'minitest/mock'
require 'fileutils'
require 'deploy_pin/cli'

# Tasks are copied to this directory, which is created and removed around each test.
TASKS_DIR = './tmp/'

ActiveSupport::TestCase.setup do
  # Tests change the configuration: restore it after each one.
  @deploy_pin_options = DeployPin::OPTIONS.select { |option| DeployPin.enabled?(option) }
                                          .to_h { |option| [option, DeployPin.public_send(option)] }

  if DeployPin.enabled?(:deployment_state_transition)
    DeployPin.remove_instance_variable(:"@deployment_state_transition")
  end

  DeployPin.setup do
    tasks_path TASKS_DIR
    groups %w[I II III]
    fallback_group 'I'
    statement_timeout 0.2.second # 200 ms
  end

  # clean
  DeployPin::Storage.record_class.delete_all
  ::FileUtils.rm_rf(TASKS_DIR, secure: true)
  ::FileUtils.mkdir(TASKS_DIR)
end

ActiveSupport::TestCase.teardown do
  ::FileUtils.rm_rf(TASKS_DIR, secure: true)

  DeployPin::OPTIONS.each do |option|
    variable = :"@#{option}"
    DeployPin.remove_instance_variable(variable) if DeployPin.instance_variable_defined?(variable)
  end
  @deploy_pin_options.each { |option, value| DeployPin.instance_variable_set(:"@#{option}", value) }
end

require_relative 'support/generator_test_case'
