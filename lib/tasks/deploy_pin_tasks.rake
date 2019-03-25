namespace :deploy_pin do
  desc "run pending tasks"
  task run: :environment do
    DeployPin::Runner.run
  end

  task pending: :environment do
    puts DeployPin::Runner.pending
  end
end
