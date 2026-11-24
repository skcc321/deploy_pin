# frozen_string_literal: true

require 'digest'
require 'securerandom'

module DeployPin
  # Serializes one-off tasks across runners that share a storage backend, so
  # overlapping `deploy_pin:run`s execute a pending task once.
  #
  # A runner claims a task before it runs it and releases the claim once the
  # task has finished and its completion is stored, or once it has failed. A
  # runner that finds the task claimed waits for the claim, then checks again
  # whether the task is done ({Collector}).
  #
  # The claim depends on {DeployPin.storage}:
  #
  # * an ActiveRecord model on PostgreSQL, MySQL or MariaDB (the default
  #   `:active_record` storage, or your own model): a session advisory lock,
  #   held by a connection of its own. The database releases it when that
  #   connection closes, so a runner that dies does not block the others.
  # * a Mongoid model (`:mongoid`, or your own model): a document in the
  #   `deploy_pin_claims` collection that expires {lease_duration} seconds
  #   after it was last renewed. The runner renews it while the task runs, so
  #   a runner that dies blocks the others for up to {lease_duration}.
  # * anything else (an ActiveRecord adapter without advisory locks such as
  #   SQLite, or a custom record class): no claim. Run one `deploy_pin:run` at a time.
  #
  # A claim protects against overlapping runners, not against crashes: if a
  # runner dies after a task had external effects but before its completion
  # was stored, the next run executes the task again, resuming from its saved
  # {Task#progress}.
  module Claim
    class << self
      # @return [Numeric] seconds between attempts while another runner holds a claim
      attr_accessor :poll_interval
      # @return [Numeric] seconds a Mongoid claim lasts unless it is renewed
      attr_accessor :lease_duration
    end

    self.poll_interval = 1
    self.lease_duration = 60

    # Name of the event instrumented with ActiveSupport::Notifications when
    # a runner starts waiting for a claim another runner holds. The payload
    # has the task `:identifier`.
    WAIT_EVENT = 'wait_for_claim.deploy_pin'

    # Runs the block while holding the claim on a task identifier, waiting for
    # other runners to release it first. Without a claim for the storage, just
    # runs the block.
    #
    # @param identifier [Integer] the task identifier
    # @yield while the claim is held
    # @return [Object] the result of the block
    def self.hold(identifier, &)
      lock = build(identifier)
      return yield unless lock

      holding(lock, identifier, &)
    ensure
      lock&.close
    end

    # @param lock [ActiveRecordLock, MongoidLock]
    # @param identifier [Integer]
    # @return [Object] the result of the block
    def self.holding(lock, identifier)
      acquire(lock, identifier)
      begin
        yield
      ensure
        release(lock, identifier)
      end
    end

    # A failed release must not hide the task's error. The claim goes anyway:
    # with the lock's connection, or when the Mongoid claim expires.
    #
    # @param lock [ActiveRecordLock, MongoidLock]
    # @param identifier [Integer]
    # @return [void]
    def self.release(lock, identifier)
      lock.release
    rescue StandardError => e
      Runner.print("[DeployPin] Could not release the claim on task #{identifier}: #{e.message}".red)
    end

    # @param identifier [Integer]
    # @return [ActiveRecordLock, MongoidLock, nil] the lock for {DeployPin.storage}, if it has one
    def self.build(identifier)
      record_class = Storage.record_class
      if defined?(::ActiveRecord::Base) && record_class < ::ActiveRecord::Base
        ActiveRecordLock.build(record_class, identifier)
      elsif defined?(::Mongoid::Document) && record_class.include?(::Mongoid::Document)
        MongoidLock.new(record_class, identifier)
      end
    end

    # @param lock [ActiveRecordLock, MongoidLock]
    # @param identifier [Integer]
    # @return [void]
    def self.acquire(lock, identifier)
      return if lock.try_acquire

      Runner.print("[DeployPin] Task #{identifier} is claimed by another runner, waiting for it".yellow)
      ActiveSupport::Notifications.instrument(WAIT_EVENT, identifier:)
      sleep(poll_interval) until lock.try_acquire
    end

    private_class_method :build, :holding, :release, :acquire

    # A session advisory lock (PostgreSQL `pg_try_advisory_lock`, MySQL and
    # MariaDB `GET_LOCK`), on a connection of its own: the task's code cannot
    # release it by reconnecting, and no transaction is held while the task runs.
    class ActiveRecordLock
      # @param record_class [Class<ActiveRecord::Base>]
      # @param identifier [Integer]
      # @return [ActiveRecordLock, nil] nil if the database has no advisory locks
      def self.build(record_class, identifier)
        lock = new(record_class, identifier)
        return lock if lock.supported?

        lock.close
        nil
      end

      # @param record_class [Class<ActiveRecord::Base>]
      # @param identifier [Integer]
      def initialize(record_class, identifier)
        handler = ::ActiveRecord::ConnectionAdapters::ConnectionHandler.new
        @pool = handler.establish_connection(record_class.connection_db_config)
        @identifier = identifier
      end

      # @return [Boolean] whether the database has advisory locks
      def supported?
        connection.supports_advisory_locks?
      end

      # @return [Boolean] whether the lock was acquired
      def try_acquire
        connection.get_advisory_lock(key)
      end

      # @return [void]
      def release
        connection.release_advisory_lock(key)
      end

      # Closes the lock's connection, which releases the lock if it is still held.
      #
      # @return [void]
      def close
        @pool.checkin(@connection) if @connection
        @pool.disconnect!
      end

      private

        def connection
          @connection ||= @pool.checkout
        end

        # Advisory locks are per database on PostgreSQL but per server on MySQL.
        def key
          @key ||= begin
            name = "deploy_pin:#{connection.current_database}:#{@identifier}"
            if connection.adapter_name.match?(/postg/i)
              Digest::SHA256.digest(name).unpack1('q>') # a signed 64-bit key
            else
              "deploy_pin:#{Digest::SHA256.hexdigest(name)[0, 48]}" # MySQL allows 64 characters
            end
          end
        end
    end

    # A document in the `deploy_pin_claims` collection, keyed by `_id` (unique
    # without any index setup). It names the runner that holds it and expires
    # {Claim.lease_duration} seconds after it was last renewed, by the
    # database clock. The holder renews it from a thread while the task runs.
    class MongoidLock
      # Collection that holds the claims.
      COLLECTION = 'deploy_pin_claims'
      # Duplicate key error: another runner inserted the claim at the same time.
      DUPLICATE_KEY = 11_000

      # @param record_class [Class<Mongoid::Document>]
      # @param identifier [Integer]
      def initialize(record_class, identifier)
        @collection = record_class.collection.database[COLLECTION]
        @id = "#{record_class.collection_name}:#{identifier}"
        @owner = SecureRandom.uuid
      end

      # Takes the claim if nobody holds it or it has expired.
      #
      # @return [Boolean] whether the claim was acquired
      def try_acquire
        claim = @collection.find_one_and_update({ _id: @id }, [{ '$set' => take }],
                                                upsert: true, return_document: :after)
        (claim['owner'] == @owner).tap { |acquired| start_renewal if acquired }
      rescue ::Mongo::Error::OperationFailure => e
        raise unless e.code == DUPLICATE_KEY

        false
      end

      # @return [void]
      def release
        @renewal&.kill&.join
        @renewal = nil
        @collection.delete_one(_id: @id, owner: @owner)
      end

      # @return [void]
      def close; end

      private

        def lease_milliseconds
          (Claim.lease_duration * 1000).to_i
        end

        def expiry
          { '$add' => ['$$NOW', lease_milliseconds] }
        end

        # A missing `expires_at` (a new claim) also sorts before `$$NOW`.
        def take
          free = { '$lt' => ['$expires_at', '$$NOW'] }
          {
            'owner' => { '$cond' => [free, @owner, '$owner'] },
            'expires_at' => { '$cond' => [free, expiry, '$expires_at'] }
          }
        end

        # :reek:TooManyStatements
        def start_renewal
          @renewal = Thread.new do
            loop do
              sleep(Claim.lease_duration / 3.0)
              renew
            end
          end
          @renewal.report_on_exception = false
        end

        def renew
          renewed = @collection.update_one({ _id: @id, owner: @owner }, [{ '$set' => { 'expires_at' => expiry } }])
          return if renewed.matched_count.positive?

          Runner.print("[DeployPin] Lost the claim #{@id}: another runner may run the task".red)
        rescue StandardError => e
          Runner.print("[DeployPin] Could not renew the claim #{@id}: #{e.message}".red)
        end
    end
  end
end
