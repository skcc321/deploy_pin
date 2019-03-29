# frozen_string_literal: true

DeployPin.setup do
  tasks_path "lib/deploy_pin"
  groups ["I", "II", "III"]
  fallback_group "II"
end
