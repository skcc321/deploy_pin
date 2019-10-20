require 'test_helper'
require 'rake'

class DeployPinTasksTest < ActiveSupport::TestCase
  setup do
    DeployPin.setup do
      tasks_path './tmp/'
      groups ["I", "II", "III"]
      fallback_group "I"
    end
  end

  Rails.application.load_tasks

  test "deploy_pin:list'" do
    assert_nothing_raised do
      Rake::Task["deploy_pin:list"].invoke
    end
  end

  test "deploy_pin:list[I]'" do
    assert_nothing_raised do
      Rake::Task["deploy_pin:list"].invoke('I')
    end
  end

  test "deploy_pin:run'" do
    assert_nothing_raised do
      Rake::Task["deploy_pin:run"].invoke
    end
  end

  test "deploy_pin:run[I]'" do
    assert_nothing_raised do
      Rake::Task["deploy_pin:run"].invoke('I')
    end
  end

  test "deploy_pin:run[75371573753751]'" do
    assert_nothing_raised do
      Rake::Task["deploy_pin:run"].invoke('75371573753751')
    end
  end
end
