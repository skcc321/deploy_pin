# frozen_string_literal: true

require 'deploy_pin/deployment_state'
require 'deploy_pin/runner'
require 'deploy_pin/collector'
require 'deploy_pin/parallel_wrapper'
require 'deploy_pin/task'
require 'deploy_pin/task_criteria'
require 'deploy_pin/engine'
require 'deploy_pin/database'
require 'deploy_pin/database_engine'
require 'parallel'
require 'ruby-progressbar'
require 'colorize'

module DeployPin
  OPTIONS = %i[
    deployment_state_transition
    fallback_group
    groups
    list_formatter
    short_list_formatter
    run_formatter
    statement_timeout
    task_wrapper
    tasks_path
  ].freeze

  DEFAULTS = {
    task_wrapper: ->(_task, task_runner) { task_runner.call }
  }.freeze

  OPTIONS.each do |option|
    instance_eval %{
      def #{option}(val = nil)
        return @#{option} unless val.present?

        @#{option} = val
      end
    }, __FILE__, __LINE__ - 6
  end

  def self.setup(&block)
    instance_eval(&block)
  end

  def self.setup_defaults!
    DEFAULTS.each do |option, value|
      instance_variable_set(:"@#{option}", value)
    end
  end

  setup_defaults!

  def self.enabled?(option)
    instance_variable_defined?("@#{option}")
  end
end
