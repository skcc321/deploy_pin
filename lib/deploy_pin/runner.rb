# frozen_string_literal: true

# executes tasks
module DeployPin::Runner
  def self.run(group:)
    pending.each do |task|
      task.run if task.group == group
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

    files.map do |file|
      task = DeployPin::Task.new(file)
      task.parse_file
      task
    end
  end
end
