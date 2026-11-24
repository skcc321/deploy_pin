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
require 'deploy_pin/cli'

require_relative 'support/deploy_pin_fixture'
require_relative 'support/generator_test_case'
