# frozen_string_literal: true

# executes tasks
module DeployPin::Runner
  def self.run(group:)
    tasks = pending(group: group)
    tasks.each_with_index do |task, index|
      puts "[#{index + 1}/#{tasks.count}] Task UUID #{task.uuid}"
      task.run
      puts ""
    end
  end

  def self.list(group:)
    pending(group: group).each_with_index do |task, index|
      puts "======= Task ##{index} ========"
      puts task.script
      puts ""
    end

    puts "======= summary ========"
    puts "tasks number: #{pending(group: group).count}"
  end

  def self.pending(group:)
    files = Dir["#{DeployPin.tasks_path}/*.rb"]

    records = DeployPin::Record.pluck(:uuid)

    files.map do |file|
      task = DeployPin::Task.new(file)
      task.parse_file
      task unless records.include?(task.uuid) || task.group != group
    end.compact
  end
end
