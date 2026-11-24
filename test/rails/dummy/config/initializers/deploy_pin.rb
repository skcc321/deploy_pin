# frozen_string_literal: true

DeployPin.setup do
  storage :mongoid if MONGOID_STORAGE
  tasks_path 'lib/deploy_pin'
  groups %w[I II III]
  cleanup_safe_time_window 30.days
  run_formatter ->(*) {}
  list_formatter ->(*) {}
  short_list_formatter ->(*) {}
end
