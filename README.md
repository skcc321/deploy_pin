[![Gem Version](https://badge.fury.io/rb/deploy_pin.svg)](https://badge.fury.io/rb/deploy_pin)
![](https://ruby-gem-downloads-badge.herokuapp.com/deploy_pin)
![example workflow](https://github.com/skcc321/deploy_pin/actions/workflows/verify.yml/badge.svg)

# DeployPin

![DeployPin](http://hereisfree.com/content1//pic/zip/2009109935062477801.jpg)

Sometimes we need to execute set of commands (tasks) after/before deployment.
Most likely you use migrations for such things, but that is not what is related to migration at all.
Also sometimes you need to execute some code before migration or later, after migration without blocking of main thread.

deploy_pins is exactly what you need.

## Usage


![DeployPin](deploy_pin.gif)

To generate new task template file
```bash
rails g deploy_pin:task some_task_title
# or
rails g deploy_pin:task some_task_title --parallel
```

Also, you can specify author
```bash
rails g deploy_pin:task some_task_title -a author_name
```

To list all pending tasks
```bash
rake deploy_pin:list
```

To run all pending tasks
```bash
rake deploy_pin:run
```

## Groupped tasks

Please define allowed groups in `config/initializers/deploy_pin.rb`
if you want to group tasks around "allowed_group"
```bash
rails g deploy_pin:task task_title -g allowed_group
# or
rails g deploy_pin:task task_title -g allowed_group --parallel
```

To list all pending tasks
```bash
rake deploy_pin:list[allowed_group]
```

To run all pending tasks
```bash
rake deploy_pin:run[allowed_group]
```

## Run by uuid

To run some specific task by uuid
```bash
rake deploy_pin:run['uuid_1, uuid_2']
```
Or you can combine uuid and group
```bash
rake deploy_pin:run['uuid, allowed_group']
```
In case if you want to rerun task you should add exclamation mark in the end of uuid
```bash
rake deploy_pin:run['uuid_1!, uuid_2!']
```

## Installation


Add this line to your application's Gemfile:

```ruby
gem 'deploy_pin'
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install deploy_pin
```

then generate configuration file
```bash
rails g deploy_pin:install
```

and run migration
```bash
rake db:migrate
```

## Database Timeout
By default, deploy_pin will run all the non-parallel tasks under a database statement timeout.  
A default value must be defined in the deploy_pin initializer. Ex.:
```ruby
# config/initializers/deploy_pin.rb
DeployPin.setup do
  statement_timeout 0.2.second # 200 ms
end
```

In order to not use the default value, it's required to use explicitly in the task, like:
```ruby
# Some deploy_pin task 
# 20190401135040:I
# task_title: Execute some query with timeout

# === task code goes down here ===
DeployPin::Database::execute_with_timeout do
 ActiveRecord::Base.connection.execute("select * from shipments;")
end
```

To know more about the params, please check the documentation [here](lib/deploy_pin/database.rb).

## Parallel
To run parallel tasks using timeout, it's required to use the parallel wrapper, which mimics parallel interface,  
but adding the timeout option.

In a deploy_pin task, instead of using `Parallel.each(1..2, in_processes: 2)`, use:
```ruby
parallel_each(1..2, in_processes: 2, timeout: 0.3.seconds) do |i|
  # ActiveRecord::Base.connection_pool.with_connection it's already include in the parallel wrapper.
  puts "Item: #{i}, Worker: #{Parallel.worker_number}"
  ActiveRecord::Base.connection.execute("<some db query>")
end
```

Check the documentation [here](lib/deploy_pin/parallel_wrapper.rb).

## Formatting
`run_formatter` is used to format the output of a `run` task
`list_formatter` is used to format the output of a `list` task

A default value must be defined in the deploy_pin initializer. Ex.:
```ruby
# config/initializers/deploy_pin.rb
DeployPin.setup do
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
```

In order to not use the default value, it's required to use explicitly in the task, like:
```ruby
# Some deploy_pin task 
# 20190401135040:I
# task_title: Execute some query with timeout

# === task code goes down here ===
DeployPin::Database::execute_with_timeout do
 ActiveRecord::Base.connection.execute("select * from shipments;")
end
```

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
