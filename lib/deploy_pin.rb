require "deploy_pin/runner"
require "deploy_pin/task"
require "deploy_pin/engine"
require "parallel"
require "ruby-progressbar"

module DeployPin
  OPTIONS = %i(
    tasks_path
    fallback_group
    groups
  )

  OPTIONS.each do |option|
    instance_eval %{
      def #{option}(val = nil)
        return @@#{option} unless val.present?

        @@#{option} = val
      end
    }
  end

  def self.setup(&block)
    instance_eval(&block)
  end
end
