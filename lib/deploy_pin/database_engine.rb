# frozen_string_literal: true

module DeployPin
  # Detects the database engine behind an ActiveRecord connection, to pick
  # the right statement timeout SQL.
  #
  # Each engine module reads, sets and restores the session timeout of a connection:
  # `current_timeout(connection)`, `apply_timeout(connection, milliseconds)` and
  # `restore_timeout(connection, value)`, where `value` is what `current_timeout` returned.
  class DatabaseEngine
    # PostgreSQL settings: `statement_timeout`, in milliseconds.
    module PostgreSQL
      # SQL that sets the timeout, in milliseconds.
      TIMEOUT_STATEMENT = 'SET statement_timeout TO %s'

      # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter]
      # @return [String] the session setting with its unit, e.g. `"0"` or `"5s"`
      def self.current_timeout(connection)
        connection.select_value('SHOW statement_timeout')
      end

      # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter]
      # @param milliseconds [Integer]
      # @return [void]
      def self.apply_timeout(connection, milliseconds)
        connection.execute(format(TIMEOUT_STATEMENT, connection.quote(Integer(milliseconds))))
      end

      # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter]
      # @param value [String] a value {.current_timeout} returned
      # @return [void]
      def self.restore_timeout(connection, value)
        connection.execute(format(TIMEOUT_STATEMENT, connection.quote(value.to_s)))
      end
    end

    # MySQL settings: `max_execution_time`, in milliseconds.
    module MySQL
      # SQL that sets the timeout, in milliseconds.
      TIMEOUT_STATEMENT = 'SET max_execution_time = %s'

      # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter]
      # @return [Integer] the session setting, in milliseconds
      def self.current_timeout(connection)
        Integer(connection.select_value('SELECT @@SESSION.max_execution_time'))
      end

      # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter]
      # @param milliseconds [Integer]
      # @return [void]
      def self.apply_timeout(connection, milliseconds)
        connection.execute(format(TIMEOUT_STATEMENT, Integer(milliseconds)))
      end

      # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter]
      # @param value [Integer] a value {.current_timeout} returned
      # @return [void]
      def self.restore_timeout(connection, value)
        apply_timeout(connection, value)
      end
    end

    # MariaDB settings: `max_statement_time`, in seconds.
    module MariaDB
      # SQL that sets the timeout, in milliseconds: `max_statement_time` is in seconds.
      TIMEOUT_STATEMENT = 'SET SESSION max_statement_time = %s / 1000'
      # SQL that sets the timeout, in seconds.
      RESTORE_STATEMENT = 'SET SESSION max_statement_time = %s'

      # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter]
      # @return [Float] the session setting, in seconds
      def self.current_timeout(connection)
        Float(connection.select_value('SELECT @@SESSION.max_statement_time'))
      end

      # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter]
      # @param milliseconds [Integer]
      # @return [void]
      def self.apply_timeout(connection, milliseconds)
        connection.execute(format(TIMEOUT_STATEMENT, Integer(milliseconds)))
      end

      # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter]
      # @param value [Float] a value {.current_timeout} returned, in seconds
      # @return [void]
      def self.restore_timeout(connection, value)
        connection.execute(format(RESTORE_STATEMENT, format('%.6f', Float(value))))
      end
    end

    # Engine modules by key.
    DB_ENGINES_MAPPING = {
      mariadb: MariaDB,
      mysql: MySQL,
      pg: PostgreSQL
    }.freeze

    # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter]
    def initialize(connection)
      @connection = connection
    end

    # @return [Module, nil] {PostgreSQL}, {MySQL} or {MariaDB}; nil for other engines
    def detect
      db_engine_symbol =
        case connection.adapter_name
        when /postg/i then :pg
        when /mysql/i, /trilogy/i then detect_mysql_based_engine
        end

      DB_ENGINES_MAPPING[db_engine_symbol]
    end

    private

      attr_reader :connection

      def detect_mysql_based_engine
        mariadb? ? :mariadb : :mysql
      end

      def mariadb?
        connection.select_value('SELECT VERSION()') =~ /MariaDB/i
      end
  end
end
