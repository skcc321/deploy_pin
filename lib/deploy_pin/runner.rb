# frozen_string_literal: true

# executes tasks
module DeployPin::Runner
  def self.run(groups:)
    tasks = pending(groups: groups)
    tasks.each_with_index do |task, index|
      puts "[#{index + 1}/#{tasks.count}] Task UUID #{task.uuid}"
      task.run
      puts ""
    end
  end

  def self.list(groups:)
    pending(groups: groups).each_with_index do |task, index|
      puts "======= Task ##{index} ========"
      puts task.script
      puts ""
    end

    puts "======= summary ========"
    puts "tasks number: #{pending(groups: groups).count}"
  end

  def self.pending(groups:)
    files = Dir["#{DeployPin.tasks_path}/*.rb"]

    # get done records uuids
    records = DeployPin::Record.pluck(:uuid)

    files.map do |file|
      task = DeployPin::Task.new(file)
      task.parse_file

      # task is done
      next if records.include?(task.uuid)

      # group mismatch
      next unless groups.include?(task.group)

      task
    end.compact.sort # sort by group position in config
  end
end
