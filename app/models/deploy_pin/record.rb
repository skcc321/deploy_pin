# frozen_string_literal: true

module DeployPin
  class Record < DeployPin::ApplicationRecord
    self.table_name = 'deploy_pins'
  end
end
