# 20190327011006:post_script

# === parallel task code goes down here ===
60.times { DeployPin::Record.create() }

Parallel.each(DeployPin::Record.all, progress: "Doing stuff") do |pin|
  ActiveRecord::Base.connection_pool.with_connection do
    pin.update_attribute(:uuid, "new uuid")
  end
  sleep(0.2)
end



# Create record in the DB to avoid multiple execution
DeployPin::Record.create(uuid: "20190327011006")
