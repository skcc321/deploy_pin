# frozen_string_literal: true

require 'test_helper'
require 'open3'

class DeployPin::EngineTest < ActiveSupport::TestCase
  DUMMY_ROOT = File.expand_path('dummy', __dir__)
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

class DeployPin::EngineLoadingTest < ActiveSupport::TestCase
  test 'the engine is loaded in a Rails app' do
    assert_includes Rails.application.railties.map(&:class), DeployPin::Engine
  end

  test 'the deploy_pin generators are found by namespace' do
    require 'rails/generators'

    %w[install task upgrade].each do |name|
      assert_equal "DeployPin::#{name.camelize}Generator",
                   Rails::Generators.find_by_namespace("deploy_pin:#{name}")&.name
    end
  end

  test 'the Rails environment silences the runner in tests' do
    assert_predicate DeployPin::Runner, :test_env?

    Rails.stub(:env, ActiveSupport::StringInquirer.new('production')) do
      with_app_env('test') { refute_predicate DeployPin::Runner, :test_env? }
    end
  end

  private

    def with_app_env(value)
      saved = ENV.fetch('APP_ENV', nil)
      ENV['APP_ENV'] = value
      yield
    ensure
      ENV['APP_ENV'] = saved
    end
end
