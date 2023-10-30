# frozen_string_literal: true

require 'connection_pool'
require 'redis'

# This module is used to track the state of a deployment.
module DeployPin
  # The mixin that extends DeployPin module with
  # @ongoing_deployment? & @pending_deployment? methods
  module DeploymentState
    STORE_KEY = 'deploy_pin:deployment'
    ONGOING = 'ongoing'
    PENDING = 'pending'

    DEPLOYMENT_OVER_TASK = %(
      # no_file_task
      # -10:%<group>s:recurring
      # task_title: Cleanup DeployPin.state

      DeployPin.send(:deployment_over!)
    ).strip

    DEPLOYMENT_ONGOING_TASK = %(
      # no_file_task
      # 0:%<group>s:recurring
      # task_title: Set DeployPin.state to 'ongoing'

      DeployPin.send(:deployment_ongoing!)
    ).strip

    DEPLOYMENT_PENDING_TASK = %(
      # no_file_task
      # 0:%<group>s:recurring
      # task_title: Set DeployPin.state to 'pending'

      DeployPin.send(:deployment_pending!)
    ).strip

    def ongoing_deployment?
      deployment_state == ONGOING
    end

    def pending_deployment?
      deployment_state == PENDING
    end

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

      def deployment_over!
        in_memory_store.delete(:deployment)
        persistent_store.del(STORE_KEY)
      end

      def deployment_ongoing!
        persistent_store.set(STORE_KEY, ONGOING)
      end

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
