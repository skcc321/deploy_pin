[![Gem Version](https://badge.fury.io/rb/deploy_pin.svg)](https://badge.fury.io/rb/deploy_pin)
![](https://ruby-gem-downloads-badge.herokuapp.com/deploy_pin)
![example workflow](https://github.com/skcc321/deploy_pin/actions/workflows/verify.yml/badge.svg)
[![Maintainability](https://api.codeclimate.com/v1/badges/c0a9ca97c1f9c0478ffc/maintainability)](https://codeclimate.com/github/skcc321/deploy_pin/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/c0a9ca97c1f9c0478ffc/test_coverage)](https://codeclimate.com/github/skcc321/deploy_pin/test_coverage)

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
rails g deploy_pin:task
# or
rails g deploy_pin:task --parallel
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
rails g deploy_pin:task allowed_group
# or
rails g deploy_pin:task allowed_group --parallel
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

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
