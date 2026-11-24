# frozen_string_literal: true

module DeployPin
  # Base class for DeployPin's ActiveRecord models.
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
