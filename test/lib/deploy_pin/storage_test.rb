# frozen_string_literal: true

require 'test_helper'

class DeployPin::StorageTest < ActiveSupport::TestCase
  teardown do
    DeployPin.storage :active_record
  end

  test 'uses active_record storage by default' do
    assert_equal :active_record, DeployPin.storage
    assert_equal DeployPin::Record, DeployPin::Storage.record_class
  end

  test 'accepts the provider as a string' do
    DeployPin.storage 'active_record'

    assert_equal DeployPin::Record, DeployPin::Storage.record_class
  end

  test 'raises on unknown provider' do
    DeployPin.storage :unknown

    error = assert_raises(ArgumentError) { DeployPin::Storage.record_class }
    assert_match(/Unknown DeployPin storage :unknown/, error.message)
  end

  test 'task persists records through the configured storage' do
    task = DeployPin::Task.new('test/support/files/task.rb')
    task.parse
    task.prepare
    task.mark

    assert_predicate DeployPin::Storage.record_class.find_by(uuid: task.identifier).completed_at, :present?
  end
end
