# 20190327010719:post_script

# === task code goes down here ===
progressbar = ProgressBar.create(title: "Doing stuff", total: 20, format: '%t |%E | %B | %a')

20.times { progressbar.increment; sleep(0.2) }





# Create record in the DB to avoid multiple execution
DeployPin::Record.create(uuid: "20190327010719")
