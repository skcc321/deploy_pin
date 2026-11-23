# frozen_string_literal: true

DeployPin.setup do
  storage :mongoid if MONGOID_STORAGE
  tasks_path 'lib/deploy_pin'
  groups %w[I II III]
  run_formatter ->(*) {}
  list_formatter ->(*) {}
  short_list_formatter ->(*) {}
end
