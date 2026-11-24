# frozen_string_literal: true

# Loading this file again (DeployPin.load_tasks or Rails.application.load_tasks
# twice) must not add the actions twice: a recurring task would run twice.
return unless DeployPin.register_rake_tasks(Rake.application)

namespace :deploy_pin do
  # The groups and task identifiers of the task arguments; all groups only when
  # no argument is given. An explicit empty selection (`invoke([])`) selects
  # nothing, as in 1.10.0. From the command line, Rake splits
  # `deploy_pin:run[I, !II]` on commas: the first value is `args.identifiers`
  # and the others are in `args.extras`. From Ruby, `invoke` may also get a
  # string with commas ('I, !II'), an array (%w[I II]) or identifiers as
  # integers: strings are split, the rest is kept.
  parse_identifiers = lambda do |args|
    next DeployPin.groups if args.identifiers.nil? && args.extras.empty?

    values = [args.identifiers, *args.extras].flatten.compact

    values.flat_map { |value| value.is_a?(String) ? value.split(/\s*,\s*/).reject(&:empty?) : [value] }
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

  # `deploy_pin:cleanup[dry_run]`, or DRY_RUN=1, only prints the files.
  desc 'remove the files of one-off tasks created more than cleanup_safe_time_window ago ([dry_run] lists them)'
  task :cleanup, [:mode] => 'deploy_pin:environment' do |_t, args|
    mode = args.mode.to_s.strip
    unless ['', 'dry_run'].include?(mode)
      abort "Unknown deploy_pin:cleanup mode '#{mode}'. Use deploy_pin:cleanup[dry_run]"
    end

    dry_run = mode == 'dry_run' || %w[1 true yes].include?(ENV['DRY_RUN'].to_s.downcase)
    DeployPin::Runner.cleanup(dry_run:)
  end
end
