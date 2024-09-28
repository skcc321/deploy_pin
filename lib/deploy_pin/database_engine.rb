# frozen_string_literal: true

module DeployPin
  # This class is used to detect used database engine and managing specific
  # differences between them.
  class DatabaseEngine
    module PostgreSQL
      TIMEOUT_STATEMENT = 'SET statement_timeout TO %s'
    end

    module MySQL
      TIMEOUT_STATEMENT = 'SET max_execution_time = %s'
    end

    module MariaDB
      TIMEOUT_STATEMENT = 'SET SESSION max_statement_time = %s'
    end

    DB_ENGINES_MAPPING = {
      mariadb: MariaDB,
      mysql: MySQL,
      pg: PostgreSQL
    }.freeze

    def initialize(connection)
      @connection = connection
    end

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
