# 20190326234049:post_script

# === parallel task code goes down here ===
Parallel.each(DeployPin.all, progress: "Doing stuff") do |pin|
  ActiveRecord::Base.connection_pool.with_connection do
    pin.update_attribute(:uuid, "new uuid")
  end
end
