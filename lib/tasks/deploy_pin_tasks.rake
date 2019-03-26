namespace :deploy_pin do
  desc "run pending tasks"
  task :run, [:group] => :environment do |t, args|
    args.with_defaults(group: DeployPin.fallback_group)

    DeployPin::Runner.run(args)
  end

  task :list, [:group] => :environment  do |t, args|
    args.with_defaults(group: DeployPin.fallback_group)

    DeployPin::Runner.list(args)
  end
end
