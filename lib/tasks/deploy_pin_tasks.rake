# frozen_string_literal: true

namespace :deploy_pin do
  desc 'run pending tasks'
  task :run, [:identifiers] => :environment do |_t, args|
    identifiers = args.identifiers
    attributes = identifiers.nil? ? DeployPin.groups : identifiers.split(/\s*,\s*/)

    DeployPin::Runner.run(identifiers: attributes)
  end

  task :list, [:identifiers] => :environment do |_t, args|
    args.with_defaults(identifiers: DeployPin.groups)

    DeployPin::Runner.list(**args)
    DeployPin::Runner.summary(**args)
  end

  desc 'Remove tasks codebase and DB records for a defined time window'
  task cleanup: :environment do
    args.with_defaults(identifiers: DeployPin.groups)

    DeployPin::Runner.cleanup(**args)
  end
end
