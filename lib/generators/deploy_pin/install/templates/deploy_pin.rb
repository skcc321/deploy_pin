# frozen_string_literal: true

DeployPin.setup do
  tasks_path 'lib/deploy_pin'
  groups %w[I II III]
  fallback_group 'II'
end
