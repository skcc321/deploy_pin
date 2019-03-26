# frozen_string_literal: true

# executes tasks
module DeployPin::Runner
  def self.run(group:)
    tasks = pending
    tasks.each_with_index do |task, index|
      if task.group == group
        puts "[#{index + 1}/#{tasks.count}] Task UUID #{task.uuid}"
        task.run
        puts ""
      end
    end
  end

  def self.list(group:)
    pending.each_with_index do |task, index|
      puts "======= Task ##{index} ========"
      puts task.script if task.group == group
      puts ""
    end

    puts "======= summary ========"
    puts "tasks number: #{pending.count}"
  end

  def self.pending
    files = Dir["#{DeployPin.tasks_path}/*.rb"]

    records = DeployPin::Record.pluck(:uuid)

    files.map do |file|
      task = DeployPin::Task.new(file)
      task.parse_file
      task unless records.include?(task.uuid)
    end.compact
  end
end
