# frozen_string_literal: true

require 'test_helper'
require 'support/claim_tests'

# Overlapping runs of the plain Ruby app (test/dummy), in separate processes.
class DeployPin::ClaimTest < ActiveSupport::TestCase
  include ClaimTests

  private

    def runner_command
      [RbConfig.ruby, File.expand_path('../../support/claim_runner.rb', __dir__)]
    end

    def runner_dir
      File.expand_path('../../..', __dir__)
    end
end
