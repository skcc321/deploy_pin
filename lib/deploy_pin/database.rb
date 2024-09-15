# frozen_string_literal: true

module DeployPin
  module Database
    PG_TIMEOUT_STATEMENT = 'SET statement_timeout TO %s'
    MYSQL_TIMEOUT_STATEMENT = 'SET max_execution_time = %s'

    extend self

    def dummy_method; end

    # Run a block under a sql maximum timeout.
    #
    # A default timeout will be get from DeployPin.setup
    #
    #   # config/initializers/deploy_pin.rb
    #   DeployPin.setup do
    #     statement_timeout 0.2.second # 200 ms
    #   end
    #
    #   # <app root>/deploy_pin/20190401135040_task.rb
    #   # 20190401135040:I
    #   # task_title: Execute some query with timeout
    #   # affected_areas: none
    #
    #   # === task code goes down here ===
    #   DeployPin::Database::execute_with_timeout do
    #     ActiveRecord::Base.connection.execute("select * from shipments;")
    #   end
    #
    # A timeout can be passed as param as well:
    #
    #   DeployPin::Database::execute_with_timeout 10.minutes do
    #     ActiveRecord::Base.connection.execute("select * from shipments;")
    #   end
    #
    # In order to connect to multiple databases, pass the +connected_to+ keyword into the params.
    # The +connected_to+ will use the +ActiveRecord::Base.connected_to+.
    # To connect to a replica database, for example:
    #
    #   DeployPin::Database::execute_with_timeout 1.seconds, connected_to: { role: :reading } do
    #     Shipment.all # Get all record from replica
    #   end
    #
    # Or a specific database:
    #
    #   DeployPin::Database.execute_with_timeout 30.second, connected_to: { database: :test_mysql } do
    #     ActiveRecord::Base.connection.execute("<some mysql query>")
    #   end
    def execute_with_timeout(timeout = DeployPin.statement_timeout, **params, &blk)
      raise ArgumentError, 'timeout must be greater than zero' if timeout.to_f <= 0

      return call_block_under_timeout(timeout, &blk) unless params.key? :connected_to

      klass = params[:connected_to].key?(:database) ? ActiveRecord::Base : ::ApplicationRecord
      klass.connected_to(**params[:connected_to]) do
        call_block_under_timeout(timeout, &blk)
      end
    end

    private

      def call_block_under_timeout(timeout)
        set_max_timeout(timeout)

        yield
      end

      def set_max_timeout(timeout)
        timeout_in_milliseconds = timeout.to_f.in_milliseconds.ceil # Make sure is always at least 1. 0 turns this off

        timeout_statement =
          if postgresql?
            PG_TIMEOUT_STATEMENT
          elsif mysql?
            MYSQL_TIMEOUT_STATEMENT
          end

        connection.execute timeout_statement % connection.quote(timeout_in_milliseconds)
      end

      def postgresql?
        connection.adapter_name =~ /postg/i
      end

      def mysql?
        connection.adapter_name =~ /mysql/i
      end

      def connection
        ActiveRecord::Base.connection
      end
  end
end
