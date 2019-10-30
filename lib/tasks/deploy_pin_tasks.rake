namespace :deploy_pin do
  desc "run pending tasks"
  task :run, [:identifiers] => :environment do |t, args|
    identifiers = args.identifiers
    attributes = identifiers.nil? ? DeployPin.groups : identifiers.split(/\s*,\s*/)

    DeployPin::Runner.run(identifiers: attributes)
  end

  task :list, [:identifiers] => :environment  do |t, args|
    args.with_defaults(identifiers: DeployPin.groups)

    DeployPin::Runner.list(args)
    DeployPin::Runner.summary(args)
  end
end
