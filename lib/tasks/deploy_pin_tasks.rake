namespace :deploy_pin do
  desc "run pending tasks"
  task run: :environment do
    DeployPin::Runner.run
  end

  task list: :environment do
    puts DeployPin::Runner.list
  end
end
