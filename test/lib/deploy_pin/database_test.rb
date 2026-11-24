# frozen_string_literal: true

require 'test_helper'

# The SQL that execute_with_timeout sends, per adapter, with connections of
# several adapters in one process.
class DeployPin::DatabaseAdaptersTest < ActiveSupport::TestCase
  # A connection that records the SQL it executes.
  class FakeConnection
    attr_reader :adapter_name, :statements

    def initialize(adapter_name, setting: nil, version: '8.0.30')
      @adapter_name = adapter_name
      @setting = setting
      @version = version
      @statements = []
    end

    def select_value(sql)
      sql == 'SELECT VERSION()' ? @version : @setting
    end

    def execute(sql)
      @statements << sql
    end

    def quote(value)
      value.is_a?(String) ? "'#{value}'" : value.to_s
    end
  end

  # A pool that hands out one connection.
  FakePool = Struct.new(:connection) do
    def with_connection
      yield connection
    end
  end

  setup { skip 'requires ActiveRecord' unless DeployPin::Database.available? }

  teardown { DeployPin::Database.instance_variable_set(:@unsupported_engine_warned, nil) }

  test 'sets and restores the timeout in the units of each engine' do
    connections = {
      postgres: FakeConnection.new('PostgreSQL', setting: '5s'),
      mysql: FakeConnection.new('Mysql2', setting: 2000),
      mariadb: FakeConnection.new('Mysql2', setting: 2.5, version: '11.4.2-MariaDB'),
      postgres_again: FakeConnection.new('PostgreSQL', setting: '0'),
      trilogy: FakeConnection.new('Trilogy', setting: 0)
    }

    connections.each_value do |connection|
      assert_equal :done, run_on(connection) { :done }
    end

    assert_equal({
                   postgres: ['SET statement_timeout TO 1500', "SET statement_timeout TO '5s'"],
                   mysql: ['SET max_execution_time = 1500', 'SET max_execution_time = 2000'],
                   mariadb: ['SET SESSION max_statement_time = 1500 / 1000',
                             'SET SESSION max_statement_time = 2.500000'],
                   postgres_again: ['SET statement_timeout TO 1500', "SET statement_timeout TO '0'"],
                   trilogy: ['SET max_execution_time = 1500', 'SET max_execution_time = 0']
                 }, connections.transform_values(&:statements))
  end

  test 'restores the timeout when the block raises' do
    connection = FakeConnection.new('PostgreSQL', setting: '5s')

    assert_raises(ZeroDivisionError) { run_on(connection) { 1 / 0 } }
    assert_equal "SET statement_timeout TO '5s'", connection.statements.last
  end

  test 'runs without a timeout on other adapters, next to supported ones' do
    sqlite = FakeConnection.new('SQLite')
    postgres = FakeConnection.new('PostgreSQL', setting: '0')

    assert_output(nil, /not supported for the SQLite adapter/) { assert_equal :done, run_on(sqlite) { :done } }
    run_on(postgres) { :done }

    assert_empty sqlite.statements
    assert_equal 2, postgres.statements.size
  end

  private

    def run_on(connection, &block)
      ActiveRecord::Base.stub(:connection_pool, FakePool.new(connection)) do
        DeployPin::Database.execute_with_timeout(1.5, &block)
      end
    end
end

# The options execute_with_timeout accepts.
class DeployPin::DatabaseOptionsTest < ActiveSupport::TestCase
  setup { skip 'requires ActiveRecord' unless DeployPin::Database.available? }

  test 'connected_to: { database: } fails clearly' do
    error = assert_raises(ArgumentError) do
      DeployPin::Database.execute_with_timeout(1, connected_to: { database: :other }) { flunk 'must not run' }
    end

    assert_match 'connected_to: { database: ... } is not supported', error.message
    assert_match 'role: or shard:', error.message
  end

  test 'unknown options fail clearly' do
    {
      { connected_to: { role: :writing, klass: 1 } } => 'Unsupported connected_to option(s): klass',
      { connected_to: {} } => 'connected_to needs role: or shard:',
      { connected_to: :reading } => 'connected_to must be a Hash',
      { connect_to: { role: :writing } } => 'Unknown option(s): connect_to'
    }.each do |options, message|
      error = assert_raises(ArgumentError, options.inspect) do
        DeployPin::Database.execute_with_timeout(1, **options) { flunk 'must not run' }
      end
      assert_match message, error.message
    end
  end
end

# The timeout on the database under test: set on the connection the block
# uses, and the previous value restored.
class DeployPin::DatabaseRestoreTest < ActiveSupport::TestCase
  # Per engine: the SQL that reads the session timeout, the SQL that sets it to
  # 7 seconds, its value then, its value at 1.5 seconds, the SQL that resets it,
  # and a query that takes half a second.
  ENGINES = {
    'pg' => ['SHOW statement_timeout', "SET statement_timeout TO '7s'", '7s', '1500ms',
             'RESET statement_timeout', 'SELECT pg_sleep(0.5)'],
    'mysql' => ['SELECT @@SESSION.max_execution_time', 'SET max_execution_time = 7000', 7000, 1500,
                'SET max_execution_time = DEFAULT', 'SELECT 1 WHERE sleep(0.5)'],
    'mariadb' => ['SELECT @@SESSION.max_statement_time', 'SET SESSION max_statement_time = 7', 7.0, 1.5,
                  'SET SESSION max_statement_time = DEFAULT', 'SELECT 1 WHERE sleep(0.5)']
  }.freeze

  # An abstract class with roles and shards, all on the database under test.
  if DeployPin::Database.available?
    class ShardedRecord < ActiveRecord::Base
      self.abstract_class = true

      config = ActiveRecord::Base.connection_db_config.configuration_hash
      connects_to shards: {
        default: { writing: config, reading: config },
        two: { writing: config, reading: config }
      }
    end
  end

  setup do
    skip 'requires PostgreSQL, MySQL or MariaDB' unless ENGINES.key?(ENV.fetch('DB_ROLE', nil))

    @read, @set_seven, @seven, @one_and_a_half, @reset, @slow = ENGINES.fetch(ENV.fetch('DB_ROLE'))
  end

  teardown do
    next unless @reset

    ActiveRecord::Base.connection.execute(@reset)
    ShardedRecord.connection_handler.each_connection_pool(ShardedRecord.connection_specification_name) do |pool|
      pool.with_connection { |connection| connection.execute(@reset) }
    end
  end

  test 'sets the timeout for the block and restores the previous one' do
    connection.execute(@set_seven)

    assert_equal @one_and_a_half, DeployPin::Database.execute_with_timeout(1.5) { current }
    assert_equal @seven, current
  end

  test 'restores the previous timeout when the block raises' do
    connection.execute(@set_seven)

    assert_raises(RuntimeError) { DeployPin::Database.execute_with_timeout(1.5) { raise 'boom' } }
    assert_equal @seven, current
  end

  test 'restores the previous timeout after the timeout stopped a query, in and out of a transaction' do
    connection.execute(@set_seven)

    assert_raises(ActiveRecord::StatementInvalid) do
      DeployPin::Database.execute_with_timeout(0.1) { connection.execute(@slow) }
    end
    assert_equal @seven, current

    assert_raises(ActiveRecord::StatementInvalid) do
      connection.transaction { DeployPin::Database.execute_with_timeout(0.1) { connection.execute(@slow) } }
    end
    assert_equal @seven, current
  end

  test 'nested calls restore the outer timeout, then the original one' do
    connection.execute(@set_seven)

    inner, after_inner = DeployPin::Database.execute_with_timeout(3) do
      [DeployPin::Database.execute_with_timeout(1.5) { current }, current]
    end

    assert_equal @one_and_a_half, inner
    refute_equal @one_and_a_half, after_inner
    refute_equal @seven, after_inner
    assert_equal @seven, current
  end

  test 'connected_to a role or a shard sets the timeout on that connection only' do
    base_before = current
    [{ role: :reading }, { shard: :two }, { shard: :two, role: :reading }].each do |connected_to|
      seen = DeployPin::Database.stub(:application_record, ShardedRecord) do
        DeployPin::Database.execute_with_timeout(1.5, connected_to:) do
          pool = ShardedRecord.connection_pool
          [pool.role, pool.shard, ShardedRecord.connection.select_value(@read), current]
        end
      end

      role = connected_to.fetch(:role, :writing)
      shard = connected_to.fetch(:shard, :default)
      assert_equal [role, shard, @one_and_a_half, base_before], seen, connected_to.inspect
      restored = ShardedRecord.connected_to(role:, shard:) { ShardedRecord.connection.select_value(@read) }
      refute_equal @one_and_a_half, restored, connected_to.inspect
    end
  end

  private

    def connection
      ActiveRecord::Base.connection
    end

    def current
      connection.select_value(@read)
    end
end
