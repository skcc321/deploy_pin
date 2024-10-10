# frozen_string_literal: true

DeployPin.setup do
  tasks_path 'lib/deploy_pin'
  groups %w[pre I II III]
  fallback_group 'III'
  statement_timeout 10.minutes
  deployment_state_transition({
                                ongoing: %w[I III],
                                pending: 'rollback', # enters to pending step before "rollback"
                                ttl: 20.second, # memoize the state to avoid the store spam
                                redis_url: 'redis://localhost:6379'
                              })
  run_formatter(
    lambda do |index, task_count, task, executable, start, duration = nil|
      end_of_msg = if executable
                     start ? '(Started)' : "(Done in #{duration})\n\n"
                   else
                     "(Skipped)\n\n"
                   end

      puts("[#{index + 1}/#{task_count}] Task #{task.title} #{task.identifier}##{task.group} #{end_of_msg}".blue.bold)
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
