# frozen_string_literal: true

require 'test_helper'

class DeployPin::Runner::Test < ActiveSupport::TestCase
  setup do
    DeployPin.setup do
      groups %w[I II III post]
      deployment_state_transition(
        {
          ongoing: %w[I III],
          pending: 'post',
          ttl: 0.01.second,
          redis_url: 'redis://localhost:6379'
        }
      )
    end
    DeployPin.send(:deployment_over!)
  end

  test 'deployment_tasks_code' do
    assert_nothing_raised do
      DeployPin.deployment_tasks_code
    end
  end

  test 'ongoing_deployment?' do
    assert_nothing_raised do
      DeployPin.ongoing_deployment?
    end
  end

  test 'pending_deployment?' do
    assert_nothing_raised do
      DeployPin.pending_deployment?
    end
  end

  test 'state transition' do
    refute(DeployPin.ongoing_deployment?)
    refute(DeployPin.pending_deployment?)
    sleep(0.02)
    eval(DeployPin.deployment_tasks_code[0]) # rubocop:disable Security/Eval
    assert(DeployPin.ongoing_deployment?)
    refute(DeployPin.pending_deployment?)
    eval(DeployPin.deployment_tasks_code[1]) # rubocop:disable Security/Eval
    sleep(0.02)
    refute(DeployPin.ongoing_deployment?)
    refute(DeployPin.pending_deployment?)
    sleep(0.02)
    eval(DeployPin.deployment_tasks_code[2]) # rubocop:disable Security/Eval
    refute(DeployPin.ongoing_deployment?)
    assert(DeployPin.pending_deployment?)
  end
end
