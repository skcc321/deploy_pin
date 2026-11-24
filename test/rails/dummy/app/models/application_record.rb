# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to database: { writing: :"#{ENV['DB_ROLE']}" }
end
