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

  task :short_list, [:identifiers] => :environment do |_t, args|
    args.with_defaults(identifiers: DeployPin.groups)

    DeployPin::Runner.short_list(**args)
    DeployPin::Runner.summary(**args)
  end

  task :mark_done, [:identifiers] => :environment do |_t, args|
    args.with_defaults(identifiers: DeployPin.groups)

    DeployPin::Runner.mark_done(**args)
    DeployPin::Runner.summary(**args)
  end
end
