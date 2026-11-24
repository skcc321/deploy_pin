# frozen_string_literal: true

require 'test_helper'

# The claim of the configured storage, within one process (the cross-process
# tests are in claim_test.rb).
class DeployPin::ClaimLockTest < ActiveSupport::TestCase
  setup do
    claims.delete_many if mongoid?
    @locks = []
  end

  teardown do
    @locks.each do |lock|
      lock.release
      lock.close
    end
  end

  test 'one lock per identifier at a time, until it is released' do
    first = lock(1)
    second = lock(1)

    assert first.try_acquire
    refute second.try_acquire
    assert lock(2).try_acquire

    first.release
    assert second.try_acquire
  end

  test 'hold releases the claim when the block raises' do
    assert_raises(RuntimeError) { DeployPin::Claim.hold(1) { raise 'boom' } }

    assert lock(1).try_acquire
  end

  test 'a Mongoid claim can be taken once it has expired' do
    skip 'requires Mongoid storage' unless mongoid?

    claims.insert_one(_id: 'deploy_pins:1', owner: 'someone', expires_at: 1.minute.from_now)
    refute lock(1).try_acquire

    claims.update_one({ _id: 'deploy_pins:1' }, { '$set' => { expires_at: 1.second.ago } })
    taker = lock(1)
    assert taker.try_acquire
    assert_equal taker.instance_variable_get(:@owner), claims.find(_id: 'deploy_pins:1').first['owner']
  end

  test 'a task completed while waiting for the claim is skipped, unless it is forced' do
    File.write("#{DeployPin.tasks_path}1_task.rb", "# 1:I\n# === task code goes down here ===\n$claimed_runs += 1\n")
    $claimed_runs = 0 # rubocop:disable Style/GlobalVars
    complete_meanwhile = lambda do |identifier, &block|
      record = DeployPin::Storage.record_class
      (record.find_by(uuid: identifier) || record.create(uuid: identifier)).update(completed_at: Time.current)
      block.call
    end

    DeployPin::Claim.stub(:hold, complete_meanwhile) { DeployPin::Runner.run(identifiers: %w[I]) }
    assert_equal 0, $claimed_runs # rubocop:disable Style/GlobalVars

    DeployPin::Claim.stub(:hold, complete_meanwhile) { DeployPin::Runner.run(identifiers: %w[1!]) }
    assert_equal 1, $claimed_runs # rubocop:disable Style/GlobalVars
  end

  test 'recurring tasks are not claimed' do
    File.write("#{DeployPin.tasks_path}r_1_task.rb", "# 1:I:recurring\n# === task code goes down here ===\n1\n")

    DeployPin::Claim.stub(:hold, ->(*) { flunk 'claimed a recurring task' }) do
      DeployPin::Runner.run(identifiers: %w[I])
    end
    assert_nil DeployPin::Storage.record_class.find_by(uuid: 1)
  end

  private

    def mongoid?
      DeployPin.storage == :mongoid
    end

    def claims
      DeployPin::MongoidRecord.collection.database[DeployPin::Claim::MongoidLock::COLLECTION]
    end

    def lock(identifier)
      DeployPin::Claim.send(:build, identifier).tap { |lock| @locks << lock }
    end
end
