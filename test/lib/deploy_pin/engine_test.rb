# frozen_string_literal: true

require 'test_helper'
require 'open3'

class DeployPin::EngineTest < ActiveSupport::TestCase
  DUMMY_ROOT = File.expand_path('../../dummy', __dir__)
  TASK_FILE = File.join(DUMMY_ROOT, 'lib/deploy_pin/20190401135040_zeitwerk_check.rb')

  setup do
    FileUtils.mkdir_p(File.dirname(TASK_FILE))
    File.write(TASK_FILE, "# 20190401135040:I\n# task_title: Zeitwerk check\n\nputs 'ran'\n")
  end

  teardown { FileUtils.rm_f(TASK_FILE) }

  test 'the app boots and eager loads with a task file in an autoloaded lib/ directory' do
    output, status = Open3.capture2e(
      { 'RAILS_ENV' => 'test' },
      RbConfig.ruby, 'bin/rails', 'runner', 'Rails.application.eager_load!; puts "booted"',
      chdir: DUMMY_ROOT
    )

    assert_predicate status, :success?, output
    assert_match 'booted', output
  end
end
