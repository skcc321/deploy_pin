# frozen_string_literal: true

DeployPin.setup do
  tasks_path 'lib/deploy_pin'
  groups %w[I II III]
  fallback_group 'II'
  statement_timeout 10.minutes
  run_formatter(
    lambda do |index, task_count, task, executable, start, time = nil|
      end_of_msg = if executable
                     start ? '(Started)' : "(Done in #{time})\n\n"
                   else
                     "(Skipped)\n\n"
                   end

      puts("[#{index + 1}/#{task_count}] Task #{task.title} #{task.uuid}##{task.group} #{end_of_msg}".blue.bold)
    end
  )
  list_formatter(
    lambda do |index, task|
      puts("======= Task ##{index} ========".blue.bold)

      # print details
      task.details.each do |key, value|
        puts("#{key}:\t\t#{value}")
      end

      puts("\n<<<\n#{task.script.strip.green}\n>>>\n\n")
    end
  )
end
