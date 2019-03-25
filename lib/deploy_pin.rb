require "deploy_pin/railtie"
require "deploy_pin/runner"

module DeployPin
  def self.tasks_path
    'lib/deploy_pin'
  end
end
