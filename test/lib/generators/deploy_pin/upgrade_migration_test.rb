# frozen_string_literal: true

require 'test_helper'

# Runs the migration `deploy_pin upgrade` creates on the deploy_pins table of
# the database under test: on a pre-1.7 table, and on a current one.
class DeployPin::UpgradeMigrationTest < ActiveSupport::TestCase
  TEMPLATE = File.join(DeployPin::Generators::Base::TEMPLATES_ROOT, 'upgrade/upgrade_deploy_pins.rb')

  setup do
    skip 'requires ActiveRecord storage' unless DeployPin.storage == :active_record && DeployPin::Database.available?

    @connection = ActiveRecord::Base.connection
    ActiveRecord::Migration.verbose = false
  end

  teardown do
    next unless @connection

    # Back to the current schema, whatever the test did
    @connection.add_column :deploy_pins, :progress, :integer, default: 0 unless column?(:progress)
    @connection.add_column :deploy_pins, :completed_at, :datetime, default: nil unless column?(:completed_at)
    DeployPin::Record.reset_column_information
    DeployPin::Record.delete_all
  end

  test 'on a pre-1.7 table, adds the columns and marks the existing records completed' do
    @connection.remove_column :deploy_pins, :completed_at
    @connection.remove_column :deploy_pins, :progress
    DeployPin::Record.reset_column_information
    created_at = 3.days.ago.change(usec: 0)
    DeployPin::Record.create!(uuid: '1', created_at:, updated_at: created_at)

    migrate

    record = DeployPin::Record.find_by(uuid: '1')
    assert_equal created_at.to_i, record.completed_at.to_i
    assert_equal 0, record.progress
  end

  test 'on a current table, changes no record' do
    created_at = 3.days.ago.change(usec: 0)
    completed_at = 1.day.ago.change(usec: 0)
    DeployPin::Record.create!(uuid: '1', progress: 42, completed_at: nil, created_at:)
    DeployPin::Record.create!(uuid: '2', progress: 7, completed_at:, created_at:)
    before = records

    migrate

    assert_equal before, records
    assert_nil DeployPin::Record.find_by(uuid: '1').completed_at
    assert_equal 42, DeployPin::Record.find_by(uuid: '1').progress
    assert_equal completed_at.to_i, DeployPin::Record.find_by(uuid: '2').completed_at.to_i
  end

  test 'on a table with progress but without completed_at, adds completed_at and keeps progress' do
    @connection.remove_column :deploy_pins, :completed_at
    DeployPin::Record.reset_column_information
    DeployPin::Record.create!(uuid: '1', progress: 9)

    migrate

    record = DeployPin::Record.find_by(uuid: '1')
    assert_equal 9, record.progress
    assert_equal record.created_at.to_i, record.completed_at.to_i
  end

  private

    def migrate
      namespace = Module.new
      namespace.module_eval(File.read(TEMPLATE), TEMPLATE)
      namespace::UpgradeDeployPins.new.migrate(:up)
      DeployPin::Record.reset_column_information
    end

    def records
      DeployPin::Record.order(:uuid).pluck(:uuid, :progress, :completed_at, :created_at, :updated_at)
    end

    def column?(name)
      @connection.column_exists?(:deploy_pins, name)
    end
end
