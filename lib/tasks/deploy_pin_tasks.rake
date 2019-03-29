namespace :deploy_pin do
  desc "run pending tasks"
  task :run, [:groups] => :environment do |t, args|
    args.with_defaults(groups: DeployPin.groups)

    DeployPin::Runner.run(args)
  end

  task :list, [:groups] => :environment  do |t, args|
    args.with_defaults(groups: DeployPin.groups)

    DeployPin::Runner.list(args)
    DeployPin::Runner.summary(args)
  end
end
