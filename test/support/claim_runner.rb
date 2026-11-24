# frozen_string_literal: true

# Runs `rake deploy_pin:run[<selectors>]` in a process of its own, for the
# tests in test/support/claim_tests.rb:
#
#   ruby test/support/claim_runner.rb TASKS_DIR SELECTORS...              # the plain Ruby app
#   bin/rails runner ../../support/claim_runner.rb TASKS_DIR SELECTORS... # the Rails app
#
# It talks to the test over two pipes: it writes one line per step to fd 3
# (`waiting` when it waits for a claim, the checkpoints of the task code,
# then `done` or `failed: <message>`) and, at each checkpoint, waits for a
# line on fd 4. It exits only when the test lets it, so a claim it still held
# would not be released by its exit.
STATUS = IO.new(3, 'w')
STATUS.sync = true
CONTROL = IO.new(4, 'r')

unless defined?(Rails)
  ENV['APP_ENV'] ||= 'test'
  require_relative '../dummy/config/environment'
end
require 'rake'

# Called by the task code of the tests.
module ClaimRunner
  def self.report(line)
    STATUS.puts(line)
  end

  # Reports a step and waits for the test to continue.
  def self.checkpoint(name)
    report(name)
    CONTROL.gets
  end

  def self.fail?
    ENV['CLAIM_RUNNER_FAIL'] == '1'
  end
end

DeployPin.tasks_path(ARGV.shift)
DeployPin::Claim.poll_interval = 0.05
ActiveSupport::Notifications.subscribe(DeployPin::Claim::WAIT_EVENT) { ClaimRunner.report('waiting') }

if defined?(Rails)
  Rails.application.load_tasks
else
  DeployPin.load_tasks
end

begin
  Rake::Task['deploy_pin:run'].invoke(*ARGV)
  ClaimRunner.report('done')
rescue StandardError => e
  ClaimRunner.report("failed: #{e.message}")
end
ClaimRunner.checkpoint('finished')
