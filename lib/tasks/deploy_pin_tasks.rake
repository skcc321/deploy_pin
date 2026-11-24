# frozen_string_literal: true

namespace :deploy_pin do
  # The groups and task identifiers of a comma-separated argument, or all groups.
  parse_identifiers = lambda do |identifiers|
    identifiers.nil? ? DeployPin.groups : identifiers.split(/\s*,\s*/)
  end

  # Loads the app: its `environment` task when it has one (Rails, Hanami, or
  # your own), else the DeployPin configuration file (see DeployPin.load_config).
  task :environment do
    if Rake::Task.task_defined?(:environment)
      Rake::Task[:environment].invoke
    elsif DeployPin.groups.nil?
      DeployPin.load_config
    end
  end

  desc 'run pending tasks'
  task :run, [:identifiers] => 'deploy_pin:environment' do |_t, args|
    DeployPin::Runner.run(identifiers: parse_identifiers.call(args.identifiers))
  end

  task :list, [:identifiers] => 'deploy_pin:environment' do |_t, args|
    identifiers = parse_identifiers.call(args.identifiers)

    DeployPin::Runner.list(identifiers:)
    DeployPin::Runner.summary(identifiers:)
  end

  task :short_list, [:identifiers] => 'deploy_pin:environment' do |_t, args|
    identifiers = parse_identifiers.call(args.identifiers)

    DeployPin::Runner.short_list(identifiers:)
    DeployPin::Runner.summary(identifiers:)
  end

  task :mark_done, [:identifiers] => 'deploy_pin:environment' do |_t, args|
    identifiers = parse_identifiers.call(args.identifiers)

    DeployPin::Runner.mark_done(identifiers:)
    DeployPin::Runner.summary(identifiers:)
  end
end
