# frozen_string_literal: true

require 'test_helper'

class DeployPin::DatabaseEngine::Test < ActiveSupport::TestCase
  setup do
    @connection = Minitest::Mock.new
  end

  test 'should detect MariaDB with MySQL2 adapter' do
    @connection.expect(:adapter_name, 'mysql2')
    @connection.expect(:select_value, '10.5.10-MariaDB', ['SELECT VERSION()'])

    assert_equal DeployPin::DatabaseEngine::MariaDB,
                 DeployPin::DatabaseEngine.new(@connection).detect
  end

  test 'should detect MariaDB with Trilogy adapter' do
    @connection.expect(:adapter_name, 'trilogy')
    @connection.expect(:select_value, '10.5.10-MariaDB', ['SELECT VERSION()'])

    assert_equal DeployPin::DatabaseEngine::MariaDB,
                 DeployPin::DatabaseEngine.new(@connection).detect
  end

  test 'should detect MySQL with MySQL2 adapter' do
    @connection.expect(:adapter_name, 'mysql2')
    @connection.expect(:select_value, '8.0.30', ['SELECT VERSION()'])

    assert_equal DeployPin::DatabaseEngine::MySQL,
                 DeployPin::DatabaseEngine.new(@connection).detect
  end

  test 'should detect MySQL with Trilogy adapter' do
    @connection.expect(:adapter_name, 'trilogy')
    @connection.expect(:select_value, '8.0.30', ['SELECT VERSION()'])

    assert_equal DeployPin::DatabaseEngine::MySQL,
                 DeployPin::DatabaseEngine.new(@connection).detect
  end

  test 'should detect PostgreSQL' do
    @connection.expect(:adapter_name, 'postgresql')

    assert_equal DeployPin::DatabaseEngine::PostgreSQL,
                 DeployPin::DatabaseEngine.new(@connection).detect
  end
end

# The SQL each engine runs to set a statement timeout, given in milliseconds.
class DeployPin::DatabaseEngine::TimeoutStatementTest < ActiveSupport::TestCase
  test 'MariaDB gets seconds: max_statement_time is in seconds' do
    assert_equal 'SET SESSION max_statement_time = 1500 / 1000',
                 format(DeployPin::DatabaseEngine::MariaDB::TIMEOUT_STATEMENT, 1500)
  end

  test 'MySQL and PostgreSQL get milliseconds' do
    assert_equal 'SET max_execution_time = 1500', format(DeployPin::DatabaseEngine::MySQL::TIMEOUT_STATEMENT, 1500)
    assert_equal 'SET statement_timeout TO 1500', format(DeployPin::DatabaseEngine::PostgreSQL::TIMEOUT_STATEMENT, 1500)
  end

  test 'the timeout applies on the database under test' do
    skip 'requires ActiveRecord' unless DeployPin::Database.available?

    settings = { 'pg' => "SELECT current_setting('statement_timeout')",
                 'mysql' => 'SELECT @@SESSION.max_execution_time',
                 'mariadb' => 'SELECT @@SESSION.max_statement_time' }
    applied = DeployPin::Database.execute_with_timeout(1.5) do
      ActiveRecord::Base.connection.select_value(settings.fetch(ENV.fetch('DB_ROLE')))
    end

    assert_equal({ 'pg' => '1500ms', 'mysql' => 1500, 'mariadb' => 1.5 }.fetch(ENV.fetch('DB_ROLE')), applied)
  end
end
