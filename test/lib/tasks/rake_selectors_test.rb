# frozen_string_literal: true

require 'test_helper'
require_relative '../../support/rake_selector_tests'

# The selectors in a plain Ruby app, with the tasks from DeployPin.load_tasks.
class DeployPin::PlainRakeSelectorsTest < ActiveSupport::TestCase
  include RakeSelectorTests

  setup do
    @rake = Rake.application
    Rake.application = Rake::Application.new
    DeployPin.load_tasks
  end

  teardown { Rake.application = @rake }
end
