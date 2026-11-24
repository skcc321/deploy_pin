# frozen_string_literal: true

DeployPin.setup do
  storage :mongoid if Dummy.mongoid?
  tasks_path File.join(Dummy::ROOT, 'lib/deploy_pin')
  groups %w[I II III]
  fallback_group 'I'
  run_formatter ->(*) {}
  list_formatter ->(*) {}
  short_list_formatter ->(*) {}
end
