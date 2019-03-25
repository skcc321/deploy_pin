# frozen_string_literal: true

# executes tasks
module DeployPin::Runner
  def self.run(group: DeployPin.default_group)
    pending.each do |task|
      task.run if task.group == group
    end
  end

  def self.list(group: DeployPin.default_group)
    pending.each do |task|
      puts task.details if task.group == group
    end
  end

  def self.pending
    files = Dir["#{DeployPin.tasks_path}/*.rb"]

    files.map do |file|
      task = DeployPin::Task.new(file)
      task.parse_file
    end
  end
end
