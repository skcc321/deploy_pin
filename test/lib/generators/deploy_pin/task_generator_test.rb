# frozen_string_literal: true

require 'test_helper'
require 'generators/deploy_pin/task/task_generator'

class DeployPin::TaskGeneratorTest < Rails::Generators::TestCase
  tests DeployPin::TaskGenerator
  destination Rails.root.join('tmp/generators')
  setup :prepare_destination

  test 'raises error if group is missing' do
    assert_raises(Thor::Error) do
      DeployPin::TaskGenerator.new([], {}, destination_root: destination_root)
    end
  end

  test 'generator runs without errors (with group)' do
    assert_nothing_raised do
      DeployPin::TaskGenerator.new(
        ['title'],
        { group: 'I', author: 'author' },
        destination_root: destination_root
      )
    end
  end

  test 'generator runs without errors (with --parallel flag)' do
    assert_nothing_raised do
      DeployPin::TaskGenerator.new(
        ['title', '--parallel'],
        { group: 'I', author: 'author' }
      )
    end
  end
end
