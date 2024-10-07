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
