# frozen_string_literal: true

# A plain Ruby app (no Rails) that uses DeployPin: the main test suite runs
# against it. It stores task records with ActiveRecord, or with Mongoid when
# DB_ROLE is `mongodb`.
require_relative 'boot'
require 'logger'

module Dummy
  ROOT = File.expand_path('..', __dir__)
  # The app environment, like RACK_ENV in a Rack app.
  ENV_NAME = ENV.fetch('APP_ENV', 'development')
  # The database under test: pg, mysql, mariadb or mongodb.
  DB_ROLE = ENV.fetch('DB_ROLE', 'pg')

  def self.mongoid?
    DB_ROLE == 'mongodb'
  end
end

if Dummy.mongoid?
  require 'mongoid'
  Mongoid.load!(File.join(Dummy::ROOT, 'config/mongoid.yml'), Dummy::ENV_NAME)
  Mongoid.logger.level = Logger::WARN
  Mongo::Logger.logger.level = Logger::WARN
else
  require 'active_record'
  require_relative 'database'
  Dummy::Database.connect
end

require 'deploy_pin'
require_relative 'deploy_pin'
