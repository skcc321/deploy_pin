# frozen_string_literal: true

# Make the database selected by DB_ROLE the primary connection, so ActiveRecord::Base
# (used by DeployPin::Database and by task scripts) talks to the engine under test.
ActiveSupport.on_load(:active_record) do
  establish_connection(ENV['DB_ROLE'].to_sym) if ENV['DB_ROLE'].present?
end
