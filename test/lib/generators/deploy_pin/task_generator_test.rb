# frozen_string_literal: true

require 'test_helper'
require 'generators/deploy_pin/task/task_generator'

class DeployPin::TaskGeneratorTest < Rails::Generators::TestCase
  tests DeployPin::TaskGenerator
  destination Rails.root.join('tmp/generators')
  setup :prepare_destination

  test 'generator runs without errors (without group)' do
    assert_nothing_raised do
      run_generator []
    end
  end

  test 'generator runs without errors (with group)' do
    assert_nothing_raised do
      run_generator ['title -g I -a author']
    end
  end

  test 'generator runs without errors (with --parallel flag)' do
    assert_nothing_raised do
      run_generator ['--parallel']
    end
  end
end
