# frozen_string_literal: true

module DeployPin
  # Runs database queries under a statement timeout (PostgreSQL, MySQL and MariaDB).
  module Database
    extend self

    # Runs a block under a database statement timeout. On databases without
    # statement timeouts (anything but PostgreSQL, MySQL and MariaDB, e.g.
    # SQLite), the block runs without a timeout and a warning is printed once.
    #
    # @example Use the default {DeployPin.statement_timeout}
    #   # 20190401135040:I
    #   # task_title: Execute some query with timeout
    #   # affected_areas: none
    #
    #   # === task code goes down here ===
    #   DeployPin::Database.execute_with_timeout do
    #     ActiveRecord::Base.connection.execute("select * from shipments;")
    #   end
    #
    # @example Pass a timeout
    #   DeployPin::Database.execute_with_timeout 10.minutes do
    #     ActiveRecord::Base.connection.execute("select * from shipments;")
    #   end
    #
    # @example Run against a replica, through `ApplicationRecord.connected_to`
    #   DeployPin::Database.execute_with_timeout 1.second, connected_to: { role: :reading } do
    #     Shipment.all
    #   end
    #
    # @example Run against another database, through `ActiveRecord::Base.connected_to`
    #   DeployPin::Database.execute_with_timeout 30.seconds, connected_to: { database: :test_mysql } do
    #     ActiveRecord::Base.connection.execute("<some mysql query>")
    #   end
    #
    # @param timeout [ActiveSupport::Duration, Numeric] timeout, in seconds when numeric
    # @param params [Hash] options
    # @option params [Hash] :connected_to arguments passed to `connected_to`
    # @yield the code to run under the timeout
    # @return [Object] the result of the block
    # @raise [NotImplementedError] if ActiveRecord is not loaded
    # @raise [ArgumentError] if the timeout is not greater than zero
    def execute_with_timeout(timeout = DeployPin.statement_timeout, **params, &blk)
      raise NotImplementedError, 'statement timeout requires ActiveRecord' unless available?
      raise ArgumentError, 'timeout must be greater than zero' if timeout.to_f <= 0

      return call_block_under_timeout(timeout, &blk) unless params.key? :connected_to

      klass = params[:connected_to].key?(:database) ? ActiveRecord::Base : application_record
      klass.connected_to(**params[:connected_to]) do
        call_block_under_timeout(timeout, &blk)
      end
    end

    # Statement timeouts are implemented on top of ActiveRecord connections only.
    #
    # @return [Boolean] whether ActiveRecord is loaded
    def available?
      defined?(::ActiveRecord::Base) ? true : false
    end

    private

      def call_block_under_timeout(timeout)
        set_max_timeout(timeout)

        yield
      end

      def set_max_timeout(timeout)
        engine = db_engine
        return warn_unsupported_engine unless engine

        timeout_in_milliseconds = timeout.to_f.in_milliseconds.ceil # Make sure is always at least 1. 0 turns this off
        connection.execute engine::TIMEOUT_STATEMENT % connection.quote(timeout_in_milliseconds)
      end

      # Databases without a statement timeout (e.g. SQLite) run the block without one.
      def warn_unsupported_engine
        return if @unsupported_engine_warned

        @unsupported_engine_warned = true
        warn "[DeployPin] Statement timeouts are not supported for the #{connection.adapter_name} adapter; " \
             'running without a timeout.'
      end

      # The app's ApplicationRecord, which holds `connects_to` in Rails apps, or ActiveRecord::Base.
      def application_record
        defined?(::ApplicationRecord) ? ::ApplicationRecord : ActiveRecord::Base
      end

      def db_engine
        @db_engine ||= DeployPin::DatabaseEngine.new(connection).detect
      end

      def connection
        ActiveRecord::Base.connection
      end
  end
end
