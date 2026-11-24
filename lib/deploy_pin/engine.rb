# frozen_string_literal: true

module DeployPin
  # Rails engine that loads the `deploy_pin:*` rake tasks.
  class Engine < ::Rails::Engine
    isolate_namespace DeployPin
  end
end
