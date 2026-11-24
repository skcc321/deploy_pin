# frozen_string_literal: true

module DeployPin
  # Runs the methods of the [Parallel](https://github.com/grosser/parallel)
  # gem with each block call under a database statement timeout. Prefix any
  # Parallel method with `parallel_` inside a task.
  #
  # The `timeout:` option sets the timeout; it defaults to
  # {DeployPin.statement_timeout}. Pass an array to give
  # {Database.execute_with_timeout} options too.
  #
  # @example
  #   parallel_each(1..2, in_processes: 2, timeout: 0.3.seconds) do |i|
  #     puts "Item: #{i}, Worker: #{Parallel.worker_number}"
  #     ActiveRecord::Base.connection.execute("<some db query>")
  #   end
  #
  # @example With timeout options
  #   parallel_each(1..2, in_processes: 2, timeout: [0.3.seconds, { connected_to: { role: :reading } }]) do |i|
  #     ActiveRecord::Base.connection.execute("<some db query>")
  #   end
  module ParallelWrapper
    # Prefix that maps a method to its Parallel counterpart.
    PARALLEL_PREFIX = 'parallel_'

    # Runs one `parallel_*` call.
    # :reek:TooManyInstanceVariables
    class ParallelRunner
      # @param method_name [Symbol] the `parallel_*` method that was called
      # @param args [Array] arguments for the Parallel method; a trailing hash
      #   with `:timeout` is used for the timeout
      # @yield the block to run for each item
      def initialize(method_name, *args, &db_block)
        @method_name = method_name
        @db_block = db_block

        if args.last.is_a?(Hash) && args.last.key?(:timeout)
          @timeout_args = args.pop
          prepare_timeout_args
        end

        @parallel_args = args
      end

      # @return [Object] the result of the Parallel method
      # @raise [RuntimeError] if no arguments were given
      def run
        raise 'You must provide at least one argument for parallel methods' if parallel_args.empty?

        Parallel.send(parallel_method_name, *parallel_args) do |*block_args|
          with_database_timeout { db_block.call(*block_args) }
        end
      end

      private

        attr_accessor :method_name, :parallel_args, :db_block

        def with_database_timeout(&block)
          return yield unless DeployPin::Database.available?

          ActiveRecord::Base.connection_pool.with_connection do
            DeployPin::Database.execute_with_timeout(timeout, **timeout_params, &block)
          end
        end

        def prepare_timeout_args
          timeout = @timeout_args[:timeout]
          if timeout.is_a?(Array)
            @timeout = timeout.shift
            @timeout_params = timeout.first
          else
            @timeout = timeout
          end
        end

        def timeout
          @timeout ||= DeployPin.statement_timeout
        end

        def timeout_params
          @timeout_params ||= {}
        end

        def parallel_method_name
          @parallel_method_name ||= method_name.to_s.gsub(PARALLEL_PREFIX, '').to_sym
        end
    end

    # Handles `parallel_*` calls.
    #
    # @return [Object] the result of the Parallel method
    def method_missing(name, *args, &block)
      return super unless respond_to_missing?(name)

      ParallelRunner.new(name, *args, &block).run
    end

    # @return [Boolean] true for `parallel_*` names of existing Parallel methods
    # :reek:ManualDispatch and :reek:BooleanParameter
    def respond_to_missing?(method_name, include_private = false)
      return super unless parallel_prefix_pattern.match? method_name

      parallel_method_name = method_name.to_s.gsub(PARALLEL_PREFIX, '').to_sym

      Parallel.respond_to?(parallel_method_name) || super
    end

    private

      def parallel_prefix_pattern
        @parallel_prefix_pattern ||= /\A#{PARALLEL_PREFIX}/
      end
  end
end
