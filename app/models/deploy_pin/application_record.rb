# frozen_string_literal: true

module DeployPin
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
