# frozen_string_literal: true

require 'connection_pool'
require 'redis'

# Extended with {DeployPin::DeploymentState}.
module DeployPin
  # Tracks whether a deployment is in progress, so application code can
  # behave differently while it runs. It is enabled by
  # {DeployPin.deployment_state_transition} and extends {DeployPin}.
  #
  # The state is stored in Redis by built-in recurring tasks that run with
  # the configured groups, and cached in memory for the configured `ttl`.
  #
  # @example
  #   DeployPin.ongoing_deployment? # => true between the "ongoing" groups
  #   DeployPin.pending_deployment? # => true after the "pending" group
  module DeploymentState
    # Redis key that holds the state.
    STORE_KEY = 'deploy_pin:deployment'
    # State between the start and end groups of `ongoing`.
    ONGOING = 'ongoing'
    # State after the `pending` group.
    PENDING = 'pending'

    # Source of the task that clears the state.
    DEPLOYMENT_OVER_TASK = %(
      # no_file_task
      # -10:%<group>s:recurring
      # task_title: Cleanup DeployPin.state

      DeployPin.send(:deployment_over!)
    ).strip

    # Source of the task that sets the state to {ONGOING}.
    DEPLOYMENT_ONGOING_TASK = %(
      # no_file_task
      # 0:%<group>s:recurring
      # task_title: Set DeployPin.state to 'ongoing'

      DeployPin.send(:deployment_ongoing!)
    ).strip

    # Source of the task that sets the state to {PENDING}.
    DEPLOYMENT_PENDING_TASK = %(
      # no_file_task
      # 0:%<group>s:recurring
      # task_title: Set DeployPin.state to 'pending'

      DeployPin.send(:deployment_pending!)
    ).strip

    # @return [Boolean] whether a deployment is running
    def ongoing_deployment?
      deployment_state == ONGOING
    end

    # @return [Boolean] whether a deployment has entered the pending step
    def pending_deployment?
      deployment_state == PENDING
    end

    # @return [Array<String>] sources of the built-in state tasks; empty unless
    #   {DeployPin.deployment_state_transition} is set
    def deployment_tasks_code
      return [] unless DeployPin.enabled?(:deployment_state_transition)

      ongoing_start_group, ongoing_end_group = DeployPin.deployment_state_transition[:ongoing]
      rollback_group = DeployPin.deployment_state_transition[:pending]

      [
        format(DEPLOYMENT_ONGOING_TASK, group: ongoing_start_group),
        format(DEPLOYMENT_OVER_TASK, group: ongoing_end_group),
        format(DEPLOYMENT_PENDING_TASK, group: rollback_group)
      ]
    end

    protected

      # Clears the state. Called by the built-in task.
      # @return [void]
      def deployment_over!
        in_memory_store.delete(:deployment)
        persistent_store.del(STORE_KEY)
      end

      # Sets the state to {ONGOING}. Called by the built-in task.
      # @return [void]
      def deployment_ongoing!
        persistent_store.set(STORE_KEY, ONGOING)
      end

      # Sets the state to {PENDING}. Called by the built-in task.
      # @return [void]
      def deployment_pending!
        persistent_store.set(STORE_KEY, PENDING)
      end

    private

      def in_memory_store
        Thread.current[:deploy_pin] ||= {}
      end

      def persistent_store
        @persistent_store ||= ConnectionPool::Wrapper.new do
          Redis.new(url: DeployPin.deployment_state_transition[:redis_url])
        end
      end

      def deployment_state
        state = in_memory_store[:deployment] || {}

        if state.blank? || state[:expiration] < Time.current
          in_memory_store[:deployment] = {
            expiration: DeployPin.deployment_state_transition[:ttl].from_now,
            state: persistent_store.get(STORE_KEY)
          }
        end

        in_memory_store[:deployment][:state]
      end
  end

  extend DeploymentState
end
