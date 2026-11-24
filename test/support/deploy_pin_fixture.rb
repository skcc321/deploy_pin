# frozen_string_literal: true

require 'fileutils'

# Setup shared by the plain Ruby suite (test/test_helper.rb) and the Rails
# suite (test/rails/test_helper.rb), required after each one boots its app.
#
# Before each test: snapshot the DeployPin configuration and apply the test
# one, delete the task records, and create an empty tasks directory. After
# each test: remove that directory and restore the configuration.

# Tasks are copied to this directory, which is created and removed around each test.
TASKS_DIR = './tmp/'

ActiveSupport::TestCase.setup do
  @deploy_pin_options = DeployPin::OPTIONS.select { |option| DeployPin.enabled?(option) }
                                          .to_h { |option| [option, DeployPin.public_send(option)] }

  if DeployPin.enabled?(:deployment_state_transition)
    DeployPin.remove_instance_variable(:"@deployment_state_transition")
  end

  DeployPin.setup do
    tasks_path TASKS_DIR
    groups %w[I II III]
    fallback_group 'I'
    statement_timeout 0.2.second # 200 ms
  end

  DeployPin::Storage.record_class.delete_all
  FileUtils.rm_rf(TASKS_DIR, secure: true)
  FileUtils.mkdir(TASKS_DIR)
end

ActiveSupport::TestCase.teardown do
  # Only the directory created above: tests may change DeployPin.tasks_path.
  FileUtils.rm_rf(TASKS_DIR, secure: true)

  DeployPin::OPTIONS.each do |option|
    variable = :"@#{option}"
    DeployPin.remove_instance_variable(variable) if DeployPin.instance_variable_defined?(variable)
  end
  @deploy_pin_options.each { |option, value| DeployPin.instance_variable_set(:"@#{option}", value) }
end
