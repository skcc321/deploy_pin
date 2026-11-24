# frozen_string_literal: true

# Uses DeployPin in a bare Ruby process: no Rails and no ORM.
# Task records are kept in memory by a record class of our own. Run by
# test/integration/plain_ruby_app_test.rb with a temporary directory as ARGV[0].
$LOAD_PATH.unshift File.expand_path('../../lib', __dir__)
require 'deploy_pin'
require 'deploy_pin/cli'

# In-memory task records, with the interface DeployPin::Storage documents.
class MemoryRecord
  RECORDS = {} # rubocop:disable Style/MutableConstant

  attr_reader :uuid, :progress, :completed_at

  def self.find_by(uuid:)
    RECORDS[uuid.to_s]
  end

  def self.create(uuid:)
    RECORDS[uuid.to_s] = new(uuid)
  end

  def initialize(uuid)
    @uuid = uuid
    @progress = 0
  end

  def update(attributes)
    attributes.each { |name, value| instance_variable_set(:"@#{name}", value) }
  end

  def increment!(attribute, by)
    update(attribute => public_send(attribute) + by)
  end
end

dir = ARGV.fetch(0)
$ran = [] # rubocop:disable Style/GlobalVars

DeployPin.setup do
  storage MemoryRecord
  tasks_path File.join(dir, 'tasks')
  groups %w[I II]
  fallback_group 'I'
  statement_timeout 1
  test_framework false
  run_formatter ->(*) {}
end

Dir.chdir(dir) do
  DeployPin::CLI.start(%w[task first_task -g I -a ci])
  sleep 1 # identifiers are timestamps in seconds
  DeployPin::CLI.start(%w[task second_task -g II -a ci])
  DeployPin::CLI.start(%w[task every_deploy -g II --recurring --identifier 7 -a ci])
end

Dir[File.join(dir, 'tasks/*.rb')].each do |file|
  header = File.read(file).split('# === task code goes down here ===').first
  # The comment keeps the scripts different: DeployPin runs only the first of tasks with the same script.
  File.write(file, "#{header}\nincrement_progress!(2) unless recurring\n$ran << title # #{File.basename(file)}\n")
end

DeployPin::Runner.run(identifiers: %w[I II])
DeployPin::Runner.run(identifiers: %w[I II])

identifiers = Dir[File.join(dir, 'tasks/[0-9]*.rb')].map { |file| File.basename(file).to_i }
puts "ran: #{$ran.sort.join(', ')}" # rubocop:disable Style/GlobalVars
puts "done: #{identifiers.all? { |id| MemoryRecord.find_by(uuid: id).completed_at }}"
puts "progress: #{identifiers.map { |id| MemoryRecord.find_by(uuid: id).progress }.join(', ')}"
puts "loaded: #{%w[Rails ActiveRecord Mongoid].select { |name| Object.const_defined?(name) }.join(', ')}"
