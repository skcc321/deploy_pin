# frozen_string_literal: true

# The Rails test suite: DeployPin in the Rails app in test/rails/dummy
# (engine, rake tasks, `rails g deploy_pin:*`). Run it with `bin/test rails`.
ENV['RAILS_ENV'] = 'test'

require 'simplecov'
require 'simplecov-review'
SimpleCov.start do
  command_name "test:rails:#{ENV.fetch('DB_ROLE', 'default')}"
  formatter SimpleCov::Formatter::ReviewFormatter
end

require_relative 'dummy/config/environment'
if DeployPin::Database.available?
  ActiveRecord::Migrator.migrations_paths = [File.expand_path('dummy/db/migrate', __dir__)]
end
DeployPin::Storage.record_class.create_indexes if DeployPin.storage == :mongoid
require 'rails/test_help'
require 'minitest/mock'

require_relative '../support/deploy_pin_fixture'
