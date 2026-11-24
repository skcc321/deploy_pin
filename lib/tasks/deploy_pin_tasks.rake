# frozen_string_literal: true

namespace :deploy_pin do
  # The groups and task identifiers of the task arguments, or all groups.
  # Rake splits `deploy_pin:run[I, !II]` on commas: the first value is
  # `args.identifiers` and the others are in `args.extras`. A single string
  # with commas (`Rake::Task['deploy_pin:run'].invoke('I, !II')`) is split here.
  parse_identifiers = lambda do |args|
    values = [args.identifiers, *args.extras].compact
    values.empty? ? DeployPin.groups : values.flat_map { |value| value.split(/\s*,\s*/) }.reject(&:empty?)
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
    DeployPin::Runner.run(identifiers: parse_identifiers.call(args))
  end

  task :list, [:identifiers] => 'deploy_pin:environment' do |_t, args|
    identifiers = parse_identifiers.call(args)

    DeployPin::Runner.list(identifiers:)
    DeployPin::Runner.summary(identifiers:)
  end

  task :short_list, [:identifiers] => 'deploy_pin:environment' do |_t, args|
    identifiers = parse_identifiers.call(args)

    DeployPin::Runner.short_list(identifiers:)
    DeployPin::Runner.summary(identifiers:)
  end

  task :mark_done, [:identifiers] => 'deploy_pin:environment' do |_t, args|
    identifiers = parse_identifiers.call(args)

    DeployPin::Runner.mark_done(identifiers:)
    DeployPin::Runner.summary(identifiers:)
  end
end
