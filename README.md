[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Gem Version](https://badge.fury.io/rb/deploy_pin.svg)](https://badge.fury.io/rb/deploy_pin)
![](https://ruby-gem-downloads-badge.herokuapp.com/deploy_pin)
[![Verification](https://github.com/skcc321/deploy_pin/actions/workflows/verify.yml/badge.svg)](https://github.com/skcc321/deploy_pin/actions/workflows/verify.yml)
[![Publish Gem](https://github.com/skcc321/deploy_pin/actions/workflows/publish.yml/badge.svg)](https://github.com/skcc321/deploy_pin/actions/workflows/publish.yml)

# DeployPin

Deploying applications often involves the need to execute a series of specific commands or tasks either before or after the deployment process. While you might typically turn to migrations for such operations, these tasks aren't always migration-related. Additionally, there are situations where you need to execute code before or after a migration without causing the main thread to block.

Introducing deploy_pins – your go-to solution for streamlined task management during the deployment process. This Ruby library allows you to seamlessly orchestrate tasks before, after, or independently of migrations, offering the flexibility you need to maintain a smooth and efficient deployment workflow. With deploy_pins, you can take control of your deployment tasks and ensure that your application operates flawlessly in any environment.

## Usage

![DeployPin](deploy_pin.gif)

To generate a new task template file:
```bash
rails g deploy_pin:task some_task_title
# or
rails g deploy_pin:task some_task_title --parallel
```

You can also specify the author:
```bash
rails g deploy_pin:task some_task_title -a author_name
```

To list all pending tasks:
```bash
rake deploy_pin:list
```

To run all pending tasks:
```bash
rake deploy_pin:run
```

## Grouped Tasks

To define allowed groups, navigate to `config/initializers/deploy_pin.rb`. You can group tasks around the "allowed_group" like this:
```bash
rails g deploy_pin:task task_title -g allowed_group
# or
rails g deploy_pin:task task_title -g allowed_group --parallel
```

To list all pending tasks within the "allowed_group":
```bash
rake deploy_pin:list[allowed_group]
```

To run all pending tasks within the "allowed_group":
```bash
rake deploy_pin:run[allowed_group]
```

## Run by Identifier

To execute a specific task using its identifier:
```bash
rake deploy_pin:run['identifier_1, identifier_2']
```

Alternatively, you can combine an identifier and a group:
```bash
rake deploy_pin:run['identifier, allowed_group']
```

If you wish to rerun a task, add an exclamation mark at the end of the identifier:
```bash
rake deploy_pin:run['identifier_1!, identifier_2!']
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'deploy_pin'
```

Then execute:
```bash
$ bundle
```

You can also install it manually with:
```bash
$ gem install deploy_pin
```

Afterward, generate the configuration file:
```bash
rails g deploy_pin:install
```

Finally, run the migration:
```bash
rake db:migrate
```

## Database Timeout

By default, deploy_pin runs all non-parallel tasks under a database statement timeout. To set a default value, you should define it in the deploy_pin initializer, for example:

```ruby
# config/initializers/deploy_pin.rb
DeployPin.setup do
  statement_timeout 0.2.seconds # 200 ms
end
```

If you want to use a different value than the default, you need to specify it explicitly in the task, as shown below:

```ruby
# Some deploy_pin task
# 20190401135040:I
# task_title: Execute some query with timeout
# affected_areas: none

# === task code goes down here ===
DeployPin::Database::execute_with_timeout do
 ActiveRecord::Base.connection.execute("select * from shipments;")
end
```

For more information about the parameters, please refer to the documentation [here](lib/deploy_pin/database.rb).

## Parallel

To run parallel tasks using a timeout, you need to use the parallel wrapper, which mimics the parallel interface but adds the timeout option. In a deploy_pin task, instead of using `Parallel.each(1..2, in_processes: 2)`, use:

```ruby
parallel_each(1..2, in_processes: 2, timeout: 0.3.seconds) do |i|
  # ActiveRecord::Base.connection_pool.with_connection is already included in the parallel wrapper.
  puts "Item: #{i}, Worker: #{Parallel.worker_number}"
  ActiveRecord::Base.connection.execute("<some db query>")
end
```

Check the documentation [here](lib/deploy_pin/parallel_wrapper.rb) for more details.

## Formatting

`run_formatter` is used to format the output of a `run` task, and `list_formatter` is used to format the output of a `list` task. To set a default value, you should define it in the deploy_pin initializer:

```ruby
# config/initializers/deploy_pin.rb
DeployPin.setup do
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

      # Print details
      task.details.each do |key, value|
        puts("#{key}:\t\t#{value}")
      end

      puts("\n<<<\n#{task.script.strip.green}\n>>>\n\n")
    end
  )
end
```

To use a different formatting value than the default, you need to specify it explicitly in the task, similar to the database timeout configuration.

## Resumable Tasks

When working with long-running code that processes a large dataset, it makes sense to store progress in the database to allow resuming the task later. You can do this by using the `DeployPin::Task` instance methods: `#progress`, `#save_progress!(num)` and `#increment_progress!(num)`.

Here is an example of how to use these methods:

```ruby
# Some DeployPin task
...
# === task code goes here ===

# The progress is 0 by default
Users.where(id: progress..).find_each do |user|
  # Do some work
  increment_progress!(1) # Increment progress by 1 and store it in the database so you can resume the task from this point
  # or save_progress!(user.id) # Save the progress as the user id
end
```

This allows your task to resume from where it left off, minimizing the risk of repeating work.


## Recurring Tasks
If you want to generate a recurring task, you can use the `--recurring` option. Make sure to set a correct `--identifier`, which should be a numeric value. Positive and negative numbers are possible here. The identifier affects the order of task execution, allowing you to customize the sequence as desired.

Please note that two identifiers, 0 and -10, are already reserved for deployment state tracking. Avoid using these identifiers.

```bash
rails g deploy_pin:task some_task_title --recurring --identifier 5
# or
rails g deploy_pin:task some_task_title --parallel --recurring --identifier 5
```

## DeploymentStateTrack
In the initializer
```ruby
DeployPin.setup do
  groups %w[I II III post rollback]
  ...
  deployment_state_transition({
    ongoing: %w[I III],
    pending: "rollback", # enters to pending step before "rollback"
    ttl: 20.second, # memoize the state to avoid Redis spam
    redis_url: "redis://localhost:6379"
  })
end

# enabled next methods
DeployPin.ongoing_deployment?
DeployPin.pending_deployment?
```

Around the deployment
```bash
bundle exec rake deploy_pin:run[I, II, III] - # enters to ongoing state before "I" and leaves it after "III" so all tasks in I, II, III have DeployPin.oingoing_deployment? == true
bundle exec rake deploy_pin:run[rollback] - # enters "pending state"
```
## Similar Gems
- https://github.com/ilyakatz/data-migrate
- https://github.com/Shopify/maintenance_tasks
- https://github.com/theSteveMitchell/after_party

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
