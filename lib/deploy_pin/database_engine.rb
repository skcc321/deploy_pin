# frozen_string_literal: true

module DeployPin
  # Detects the database engine behind an ActiveRecord connection, to pick
  # the right statement timeout SQL.
  class DatabaseEngine
    # PostgreSQL settings.
    module PostgreSQL
      # SQL that sets the timeout, in milliseconds.
      TIMEOUT_STATEMENT = 'SET statement_timeout TO %s'
    end

    # MySQL settings.
    module MySQL
      # SQL that sets the timeout, in milliseconds.
      TIMEOUT_STATEMENT = 'SET max_execution_time = %s'
    end

    # MariaDB settings.
    module MariaDB
      # SQL that sets the timeout, in milliseconds.
      TIMEOUT_STATEMENT = 'SET SESSION max_statement_time = %s'
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
