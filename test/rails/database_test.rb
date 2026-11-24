# frozen_string_literal: true

require 'test_helper'

# In a Rails app, `connected_to: { role: ... }` goes through ApplicationRecord,
# which declares the app's connections (`connects_to`).
class DeployPin::RailsDatabaseTest < ActiveSupport::TestCase
  setup { skip 'requires ActiveRecord' unless DeployPin::Database.available? }

  test 'runs the block connected to a role through ApplicationRecord' do
    connected = []
    connected_to = lambda do |**options, &block|
      connected << options
      block.call
    end

    result = ApplicationRecord.stub(:connected_to, connected_to) do
      DeployPin::Database.execute_with_timeout(1, connected_to: { role: :writing }) { :done }
    end

    assert_equal :done, result
    assert_equal [{ role: :writing }], connected
  end
end
