# frozen_string_literal: true

module DeployPin
  # Parallel wrapper to run parallel tasks using database statement timeout.
  # This wrapper keeps parallel interface, but running the processes under db statement timeout.
  #
  # In order to use this wrapper, just use call parallel methods with `parallel_`. Ex.:
  #   parallel_each(1..2, in_processes: 2, timeout: 0.3.seconds) do |i|
  #     puts "Item: #{i}, Worker: #{Parallel.worker_number}"
  #     ActiveRecord::Base.connection.execute("<some db query>")
  #   end
  #
  # In order to pass more `timeout` options, it requires to pass an array, like:
  #   parallel_each(1..2, in_processes: 2, timeout: [0.3.seconds, { connected_to: { role: :reading } }]) do |i|
  #     puts "Item: #{i}, Worker: #{Parallel.worker_number}"
  #     ActiveRecord::Base.connection.execute("<some db query>")
  #   end
  module ParallelWrapper
    PARALLEL_PREFIX = 'parallel_'

    # :reek:TooManyInstanceVariables
    class ParallelRunner
      def initialize(method_name, *args, &db_block)
        @method_name = method_name
        @db_block = db_block

        if args.last.is_a?(Hash) && args.last.key?(:timeout)
          @timeout_args = args.pop
          prepare_timeout_args
        end

        @parallel_args = args
      end

      def run
        raise 'You must provide at least one argument for parallel methods' if parallel_args.empty?

        Parallel.send(parallel_method_name, *parallel_args) do |*block_args|
          ActiveRecord::Base.connection_pool.with_connection do
            DeployPin::Database.execute_with_timeout(timeout, **timeout_params) do
              db_block.call(*block_args)
            end
          end
        end
      end

      private

        attr_accessor :method_name, :parallel_args, :db_block

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

    def method_missing(name, *args, &block)
      return super unless respond_to_missing?(name)

      ParallelRunner.new(name, *args, &block).run
    end

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
