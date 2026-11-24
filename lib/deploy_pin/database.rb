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
    # @example Run against a shard declared with `connects_to shards: { ... }`
    #   DeployPin::Database.execute_with_timeout 30.seconds, connected_to: { shard: :shard_two } do
    #     Shipment.where(state: 'stuck').delete_all
    #   end
    #
    # The timeout is set on the connection the block uses: the one of
    # `ActiveRecord::Base`, or with `connected_to:`, the one of the app's
    # `ApplicationRecord` (or `ActiveRecord::Base` without one) for that role
    # or shard. The connection's previous timeout is restored when the block
    # returns or raises, so nested calls and later queries are not affected.
    #
    # @param timeout [ActiveSupport::Duration, Numeric] timeout, in seconds when numeric
    # @param params [Hash] options
    # @option params [Hash] :connected_to `role:`, `shard:` and `prevent_writes:`, passed to `connected_to`
    # @yield the code to run under the timeout
    # @return [Object] the result of the block
    # @raise [NotImplementedError] if ActiveRecord is not loaded
    # @raise [ArgumentError] if the timeout is not greater than zero, or the options are not supported
    def execute_with_timeout(timeout = DeployPin.statement_timeout, **params, &blk)
      raise NotImplementedError, 'statement timeout requires ActiveRecord' unless available?
      raise ArgumentError, 'timeout must be greater than zero' if timeout.to_f <= 0

      connected_to = connected_to_options(params)
      return call_block_under_timeout(timeout, ActiveRecord::Base, &blk) unless connected_to

      klass = application_record
      klass.connected_to(**connected_to) do
        call_block_under_timeout(timeout, klass, &blk)
      end
    end

    # Statement timeouts are implemented on top of ActiveRecord connections only.
    #
    # @return [Boolean] whether ActiveRecord is loaded
    def available?
      defined?(::ActiveRecord::Base) ? true : false
    end

    private

      # Options of `connected_to` that select a connection of the app.
      CONNECTED_TO_OPTIONS = %i[role shard prevent_writes].freeze

      # @return [Hash, nil] the `connected_to` options, nil without them
      def connected_to_options(params)
        unknown = params.keys - [:connected_to]
        raise ArgumentError, "Unknown option(s): #{unknown.join(', ')}. Supported: connected_to" if unknown.any?

        options = params[:connected_to]
        return if options.nil?
        unless options.is_a?(Hash)
          raise ArgumentError, 'connected_to must be a Hash, e.g. connected_to: { role: :reading }'
        end

        validate_connected_to(options.symbolize_keys)
      end

      # :reek:TooManyStatements
      def validate_connected_to(options)
        if options.key?(:database)
          raise ArgumentError, 'connected_to: { database: ... } is not supported by ActiveRecord 7.2 and later. ' \
                               'Declare the database with connects_to, then pass role: or shard:'
        end
        unknown = options.keys - CONNECTED_TO_OPTIONS
        if unknown.any?
          raise ArgumentError, "Unsupported connected_to option(s): #{unknown.join(', ')}. " \
                               'Supported: role, shard, prevent_writes'
        end
        raise ArgumentError, 'connected_to needs role: or shard:' unless options.key?(:role) || options.key?(:shard)

        options
      end

      # Runs the block on the connection of `klass` that the current thread uses,
      # under the timeout, and restores that connection's previous timeout.
      def call_block_under_timeout(timeout, klass, &block)
        klass.connection_pool.with_connection do |connection|
          engine = db_engine(connection)
          next run_without_timeout(connection, &block) unless engine

          # at least 1 millisecond: 0 turns the timeout off
          with_engine_timeout(engine, connection, timeout.to_f.in_milliseconds.ceil, &block)
        end
      end

      # :reek:TooManyStatements
      def with_engine_timeout(engine, connection, milliseconds)
        previous = engine.current_timeout(connection)
        engine.apply_timeout(connection, milliseconds)
        succeeded = false
        begin
          result = yield
          succeeded = true
          result
        ensure
          restore_timeout(engine, connection, previous, raise_errors: succeeded)
        end
      end

      # A failed restore must not hide the block's own error (e.g. an aborted
      # transaction, whose rollback undoes the SET anyway).
      def restore_timeout(engine, connection, previous, raise_errors:)
        engine.restore_timeout(connection, previous)
      rescue ActiveRecord::ActiveRecordError
        raise if raise_errors
      end

      # Databases without a statement timeout (e.g. SQLite) run the block without one.
      def run_without_timeout(connection)
        warn_unsupported_engine(connection)
        yield
      end

      def warn_unsupported_engine(connection)
        return if @unsupported_engine_warned

        @unsupported_engine_warned = true
        warn "[DeployPin] Statement timeouts are not supported for the #{connection.adapter_name} adapter; " \
             'running without a timeout.'
      end

      # The app's ApplicationRecord, which holds `connects_to` in Rails apps, or ActiveRecord::Base.
      def application_record
        defined?(::ApplicationRecord) ? ::ApplicationRecord : ActiveRecord::Base
      end

      # The engine of a connection, detected once per connection.
      def db_engine(connection)
        engines = (@db_engines ||= ObjectSpace::WeakMap.new)
        return engines[connection] if engines.key?(connection)

        engines[connection] = DeployPin::DatabaseEngine.new(connection).detect
      end
  end
end
