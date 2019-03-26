# frozen_string_literal: true

DeployPin.setup do
  tasks_path "lib/deploy_pin"
  groups ["post_script", "pre_script"]
  fallback_group "post_script"
end
