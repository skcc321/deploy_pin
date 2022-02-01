# frozen_string_literal: true

module DeployPin
  class Engine < ::Rails::Engine
    isolate_namespace DeployPin
  end
end
