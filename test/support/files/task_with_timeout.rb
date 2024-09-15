# frozen_string_literal: true

# 75371573753754:III
# task_title: task with explicit wait
# affected_areas: none

# === task code goes down here ===

DeployPin::Database.execute_with_timeout do
  ActiveRecord::Base.connection.execute("SELECT pg_sleep(#{0.1.second.to_f});")
end
