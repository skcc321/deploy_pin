# frozen_string_literal: true

require 'test_helper'

class DeployPin::StorageTest < ActiveSupport::TestCase
  setup do
    @storage = DeployPin.storage
  end

  teardown do
    DeployPin.storage @storage
  end

  test 'defaults to active_record storage' do
    assert_equal :active_record, DeployPin::DEFAULTS[:storage]
  end

  test 'resolves active_record storage' do
    skip 'requires ActiveRecord' unless DeployPin::Database.available?

    DeployPin.storage :active_record

    assert_equal DeployPin::Record, DeployPin::Storage.record_class
  end

  test 'resolves mongoid storage' do
    skip 'requires Mongoid' unless defined?(::Mongoid)

    DeployPin.storage :mongoid

    assert_equal DeployPin::MongoidRecord, DeployPin::Storage.record_class
  end

  test 'accepts the provider as a string' do
    DeployPin.storage @storage.to_s

    assert_equal DeployPin::Storage::PROVIDERS.fetch(@storage.to_sym).call, DeployPin::Storage.record_class
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

  test 'task tracks progress through the configured storage' do
    task = DeployPin::Task.new('test/support/files/task.rb')
    task.parse
    task.prepare

    assert_equal 0, task.progress
    task.increment_progress!(2)
    task.increment_progress!(3)
    assert_equal 5, task.progress
    task.save_progress!(42)
    assert_equal 42, task.progress
  end

  test 'record lookup returns nil when missing' do
    assert_nil DeployPin::Storage.record_class.find_by(uuid: 1)
  end
end
