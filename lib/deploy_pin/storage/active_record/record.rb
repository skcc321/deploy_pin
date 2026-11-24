# frozen_string_literal: true

module DeployPin
  # ActiveRecord storage for task records (the default), in the `deploy_pins` table.
  class Record < DeployPin::ApplicationRecord
    self.table_name = 'deploy_pins'
  end
end
