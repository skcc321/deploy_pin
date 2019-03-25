require "deploy_pin/railtie"
require "deploy_pin/runner"
require "deploy_pin/task"

module DeployPin
  def self.tasks_path
    'lib/deploy_pin'
  end
end
