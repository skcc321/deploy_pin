# frozen_string_literal: true

require 'test_helper'
require_relative '../support/claim_tests'

# Overlapping `rake deploy_pin:run`s of the Rails app (test/rails/dummy), in separate processes.
class DeployPin::RailsClaimTest < ActiveSupport::TestCase
  include ClaimTests

  APP_ROOT = File.expand_path('dummy', __dir__)

  private

    def runner_command
      [RbConfig.ruby, 'bin/rails', 'runner', File.expand_path('../support/claim_runner.rb', __dir__)]
    end

    def runner_dir
      APP_ROOT
    end
end
