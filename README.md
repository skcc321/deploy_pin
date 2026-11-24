# DeployPin

[![Gem Version](https://img.shields.io/gem/v/deploy_pin?color=CC342D)](https://rubygems.org/gems/deploy_pin)
[![Downloads](https://img.shields.io/gem/dt/deploy_pin)](https://rubygems.org/gems/deploy_pin)
[![CI](https://github.com/skcc321/deploy_pin/actions/workflows/verify.yml/badge.svg)](https://github.com/skcc321/deploy_pin/actions/workflows/verify.yml)
[![Docs](https://img.shields.io/badge/docs-rubydoc.info-blue)](https://rubydoc.info/gems/deploy_pin)
[![Ruby](https://img.shields.io/badge/ruby-%E2%89%A5%203.1-CC342D)](#requirements)
[![Rails](https://img.shields.io/badge/rails-7.2%20%E2%80%93%208.x%20or%20none-CC0000)](#requirements)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](MIT-LICENSE)

**Run one-off and recurring tasks around your deployments — data backfills, cache warm-ups, cleanups — in a defined order, once per task, with database timeouts and resumable progress.**

Migrations are for schema changes. Everything else you need to run during a release (backfill a column, re-index records, call an external API, warm a cache) usually ends up in an ad-hoc rake task that someone has to remember to run. DeployPin keeps these tasks in your repository as plain Ruby files, runs each one once, in the order you define, and remembers what has already run.

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
  - [Without Rails](#without-rails)
- [Quick start](#quick-start)
- [How it works](#how-it-works)
- [Commands](#commands)
- [Hooking into your deploy](#hooking-into-your-deploy)
- [Features in depth](#features-in-depth)
- [Configuration reference](#configuration-reference)
- [Development](#development)
- [Contributing](#contributing)
- [Similar gems](#similar-gems)
- [License](#license)

## Features

- 📌 **Run once:** each task's completion is stored, so it never runs twice. You can still re-run it on purpose.
- 🗂 **Groups and ordering:** run tasks before or after migrations, or at any other step of your deploy.
- ⏱ **Statement timeouts:** tasks run under a database statement timeout (PostgreSQL, MySQL, MariaDB).
- ⚡ **Parallel:** a [Parallel](https://github.com/grosser/parallel) wrapper that applies the timeout in every worker.
- 🔁 **Resumable:** save progress so a long task continues where it stopped.
- ♻️ **Recurring tasks:** tasks that run on every deploy.
- 🧹 **Cleanup:** remove the files of old one-off tasks, so the tasks directory doesn't keep growing.
- 🚦 **Deployment state:** `DeployPin.ongoing_deployment?` lets your app behave differently while a deploy is in progress.
- 🍃 **ActiveRecord or Mongoid** storage, or a record class of your own.
- 🧩 **Rails or plain Ruby:** a Rails engine and `rails g` generators, or the `deploy_pin` command and `DeployPin.load_tasks` in any other Ruby app (Sinatra, Hanami, Roda, scripts…).

## Requirements

| | |
|---|---|
| Ruby | ≥ 3.1 (CI runs 3.3, 3.4 and 4.0) |
| Rails | Optional. ≥ 7.2, < 9 (CI runs 7.2 and 8.1). Without Rails, ActiveSupport ≥ 7.2 is used. For Rails 7.0 and 7.1, use deploy_pin 1.10 |
| Storage | ActiveRecord (PostgreSQL, MySQL, MariaDB, …), Mongoid, or your own record class |
| Redis | Only for [deployment state](#deployment-state) |

Statement timeouts need ActiveRecord with PostgreSQL, MySQL or MariaDB. With other setups, tasks run without a timeout.

## Installation

Add the gem to your Gemfile and install it:

```bash
bundle add deploy_pin
```

Then generate the initializer and the migration, and migrate:

```bash
rails g deploy_pin:install
rails db:migrate
```

<details>
<summary>Using Mongoid?</summary>

Generate the initializer with Mongoid storage (no migration is created), then create the indexes:

```bash
rails g deploy_pin:install --storage=mongoid
rails db:mongoid:create_indexes
```

Mongoid is not a dependency of deploy_pin, so it has to be in your Gemfile. See [Storage](#storage).

</details>

The generated `config/initializers/deploy_pin.rb` starts like this:

```ruby
DeployPin.setup do
  tasks_path 'lib/deploy_pin'
  groups %w[pre I II III]
  fallback_group 'III'
  statement_timeout 10.minutes
  # ...formatters and deployment state, see below
end
```

### Without Rails

DeployPin works in any Ruby app. Add it together with a storage gem and your database adapter, for example ActiveRecord with SQLite (use `pg` or `mysql2` for other databases, or `mongoid` instead of `activerecord`):

```bash
bundle add deploy_pin activerecord sqlite3
```

The `deploy_pin` command runs the same generators as `rails g deploy_pin:*`. Create `config/deploy_pin.rb` and the `deploy_pins` migration (with `--storage=mongoid`, only the configuration):

```bash
bundle exec deploy_pin install # --config-path and --migrations-path change where the files go
```

The generated configuration turns on [deployment state](#deployment-state), which needs Redis. Remove `deployment_state_transition` from it if you don't use Redis.

Then add the rake tasks to your `Rakefile`. They run your `environment` task first, so define one that loads your app, connects to the database and loads `config/deploy_pin.rb`. Run the migration with your migration tool:

```ruby
# Rakefile
require 'deploy_pin'
DeployPin.load_tasks

task :environment do
  require_relative 'config/environment'
end
```

```ruby
# config/environment.rb
require 'active_record'
require 'deploy_pin'
ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: 'db/app.sqlite3')
require_relative 'deploy_pin'
```

Without an `environment` task, the rake tasks only load `config/deploy_pin.rb`.

Generate tasks with `deploy_pin task`. It loads `config/deploy_pin.rb` first, or the files given with `--require`. Then run them with rake:

```bash
bundle exec deploy_pin task backfill_user_names -g I --require config/environment.rb
bundle exec rake deploy_pin:run
```

The rest of this README uses the Rails commands. Replace `rails g deploy_pin:<command>` with `deploy_pin <command>`, and `config/initializers/deploy_pin.rb` with `config/deploy_pin.rb`. [`bin/smoke_test_gem`](bin/smoke_test_gem) runs these steps on CI.

## Quick start

```bash
# 1. Generate a task in a group
rails g deploy_pin:task backfill_user_names -g I

# 2. Write the code in lib/deploy_pin/<timestamp>_backfill_user_names.rb
#    and its test in spec/deploy_pin/<timestamp>_backfill_user_names_spec.rb

# 3. See what is pending
rake deploy_pin:list

# 4. Run it (normally from your deploy script)
rake deploy_pin:run
```

## How it works

### Task files

A task is a Ruby file in `tasks_path`. The generator writes the header for you:

```ruby
# 20190401135040:I
# task_title: Backfill user names
# affected_areas: users

# === task code goes down here ===
User.where(name: nil).find_each { |user| user.update!(name: user.email) }
```

| Header line | Meaning |
|---|---|
| `# 20190401135040:I` | `<identifier>:<group>`. The identifier is a timestamp for one-off tasks. |
| `# 20190401135040:I:recurring` | A [recurring task](#recurring-tasks) that runs on every deploy |
| `# task_title:` | Shown by `list` and `run` |
| `# affected_areas:` | Free text for reviewers: what the task touches |

The header is the comment block at the top of the file, up to `# === task code goes down here ===` (or up to the first line of code in files without that line). DeployPin reads the header lines from there only. Everything after it is the task's code, run exactly as written, so comments and lines such as `# 456:II` inside strings or heredocs are kept and do not change the task.

The generator gives each one-off task an unused identifier: two tasks generated in the same second get consecutive timestamps. One-off tasks must not share an identifier, because they share its completion record. `deploy_pin:run`, `list`, `short_list` and `mark_done` stop with an error naming both files if two do, whatever the selected groups. Give the task that has not run yet a new identifier.

### Groups and ordering

`groups` defines the steps of your deploy, in order. Group names are up to you, and so is the moment each group runs: you choose it by calling `rake 'deploy_pin:run[<group>]'` at that point of your deploy. You can have as many stages as you need. For example:

| Group | When you run it | Typical tasks |
|---|---|---|
| `pre` | Right before the deploy starts | Pause background jobs, take a snapshot, flip a feature flag |
| `I`, `II`, … | Around the migrations | Backfill data that the new schema or code needs |
| `post` | Right after the new release is live | Warm caches, re-enable jobs, notify other services |

Tasks are sorted by **group**, then by **identifier**. Negative identifiers run after the other tasks of their group.

A non-recurring task runs only once. When it finishes, it is marked done in the storage, and later runs skip it. If two tasks have the same code, only the first one runs. Lines that hold only a comment or nothing don't count, unless they are inside a heredoc or another string.

### Running one executor at a time

DeployPin does not coordinate overlapping runs. Serialize the invocations that change task state against the same storage: run one `deploy_pin:run` at a time, from a designated release job or host, and don't run `deploy_pin:mark_done` while a run is in progress. Two executors that overlap can both select the same pending task and run it.

A task is marked done after it finishes. If the process stops after the task changed something but before it was marked done, the next run runs the task again, so write tasks that can resume (see [progress](#resumable-tasks)) or are safe to run again.

This is about separate DeployPin invocations. Parallel workers inside a single task, with [`parallel_*`](#parallel), are supported.

### Selecting tasks

Every command takes an optional, comma-separated list of groups and identifiers:

| Argument | Selects |
|---|---|
| *(none)* | All pending tasks in all groups |
| `I` | Pending tasks in group `I` |
| `20190401135040` | That task, if it is pending |
| `20190401135040!` or `I!` | Re-run: selects matching tasks even if they are done |
| `!20190401135040` or `!II` | Skips matching tasks |

```bash
rake 'deploy_pin:run[I, II]'
rake 'deploy_pin:run[20190401135040!]'   # re-run one task
rake 'deploy_pin:run[I, !20190401135040]' # group I except one task
```

> [!TIP]
> Quote the task name (`'deploy_pin:run[...]'`). Shells such as zsh treat the square brackets as glob patterns.

## Commands

| Command | Description |
|---|---|
| `rails g deploy_pin:task <title> -g <group>` | Generate a task and its [test](#testing-tasks). Options: `--parallel`, `--recurring --identifier <n>`, `-a <author>`, `--skip-test`, `--test-framework=rspec` |
| `deploy_pin install`, `deploy_pin task <title> -g <group>`, `deploy_pin upgrade` | The generators, [without Rails](#without-rails). `--require <file>` loads files first |
| `rails g deploy_pin:upgrade`, `deploy_pin upgrade` | Only for a `deploy_pins` table created before DeployPin 1.7: a migration that adds the columns for resumable tasks and marks the existing records done. It changes nothing on newer tables, and cannot be rolled back: it raises `ActiveRecord::IrreversibleMigration` instead of removing the columns |
| `rake deploy_pin:list[...]` | List pending tasks, including their code |
| `rake deploy_pin:short_list[...]` | List pending tasks by group, without the code |
| `rake deploy_pin:run[...]` | Run pending tasks |
| `rake deploy_pin:mark_done[...]` | Mark tasks as done without running them. For example, in `db/seeds.rb` for a fresh database, or for a new environment |
| `rake deploy_pin:cleanup` | Remove the files and tests of one-off tasks created more than [`cleanup_safe_time_window`](#cleaning-up-old-tasks) ago. `deploy_pin:cleanup[dry_run]` (or `DRY_RUN=1`) only lists them |

## Hooking into your deploy

Call `deploy_pin:run` with the right groups at each stage of your deploy. With `groups %w[pre I II III post]`:

```bash
# right before the deploy
bundle exec rake 'deploy_pin:run[pre]'

# with the migrations
bundle exec rake db:migrate 'deploy_pin:run[I, II, III]'

# right after the new release is live
bundle exec rake 'deploy_pin:run[post]'
```

### Example: a search index change in two stages

Say the new release searches a new Elasticsearch index, `products_v2`. The index has to exist before the new code goes live, but filling it takes hours. Split the work into a `pre` task and a `post` task:

```bash
rails g deploy_pin:task create_products_v2_index -g pre
rails g deploy_pin:task backfill_products_v2_index -g post
```

The **pre** task creates the mapping and indexes only the data the new release needs right away, so the deploy stays fast:

```ruby
# 20261124120000:pre
# task_title: Create products_v2 index and index recent products
# affected_areas: product search

# === task code goes down here ===
client = Elasticsearch::Client.new(url: ENV.fetch('ELASTICSEARCH_URL'))

unless client.indices.exists?(index: 'products_v2')
  client.indices.create(
    index: 'products_v2',
    body: {
      mappings: {
        properties: {
          name: { type: 'text' },
          sku: { type: 'keyword' },
          price: { type: 'scaled_float', scaling_factor: 100 }
        }
      }
    }
  )
end

# Products changed in the last week: enough for search to work after the release
Product.where(updated_at: 1.week.ago..).find_in_batches(batch_size: 500) do |batch|
  client.bulk(body: batch.flat_map { |product| [{ index: { _index: 'products_v2', _id: product.id } }, product.search_document] })
end
```

The **post** task indexes everything else after the release is live. It saves its progress, so if it is interrupted, the next `deploy_pin:run[post]` continues where it stopped instead of starting over:

```ruby
# 20261124120100:post
# task_title: Index all products into products_v2
# affected_areas: product search

# === task code goes down here ===
client = Elasticsearch::Client.new(url: ENV.fetch('ELASTICSEARCH_URL'))

Product.where('id > ?', progress).find_in_batches(batch_size: 1_000) do |batch|
  client.bulk(body: batch.flat_map { |product| [{ index: { _index: 'products_v2', _id: product.id } }, product.search_document] })
  save_progress!(batch.last.id)
end
```

Both tasks run once. The next deploy skips them because they are marked done.

### Deploy tool examples

The examples below use the same stages. Adjust them to your own groups.

<details>
<summary>Heroku</summary>

The release phase runs before the new release goes live:

```
# Procfile
release: bundle exec rake 'deploy_pin:run[pre]' db:migrate 'deploy_pin:run[I, II, III]'
```

Heroku has no hook after the release is live, so run `post` as a one-off dyno from your deploy pipeline:

```bash
heroku run "bundle exec rake 'deploy_pin:run[post]'"
```

</details>

<details>
<summary>Capistrano</summary>

```ruby
# lib/capistrano/tasks/deploy_pin.rake
namespace :deploy_pin do
  { pre: 'pre', migrate: 'I, II, III', post: 'post' }.each do |stage, groups|
    task stage do
      on primary(:db) do
        within release_path do
          with rails_env: fetch(:rails_env) do
            execute :rake, "'deploy_pin:run[#{groups}]'"
          end
        end
      end
    end
  end
end

# config/deploy.rb
before 'deploy:migrate', 'deploy_pin:pre'
after 'deploy:migrate', 'deploy_pin:migrate'
after 'deploy:published', 'deploy_pin:post'
```

</details>

<details>
<summary>Kamal</summary>

Use [Kamal hooks](https://kamal-deploy.org/docs/hooks/overview/). They run on your machine, so each one calls `kamal app exec` (remember to make them executable):

```bash
# .kamal/hooks/pre-deploy: the new image is pushed, the old version still serves traffic
kamal app exec --primary --version "$KAMAL_VERSION" "bin/rails 'deploy_pin:run[pre]'"

# .kamal/hooks/post-deploy: the new version is live
kamal app exec --primary --reuse "bin/rails 'deploy_pin:run[I, II, III]' 'deploy_pin:run[post]'"
```

The default Rails entrypoint runs `db:prepare` when the container boots, so here the migration groups run in the post-deploy hook.

</details>

## Features in depth

### Database timeout

Tasks run under `statement_timeout` from the initializer. To use a different timeout, wrap the code in `DeployPin::Database.execute_with_timeout`. The default timeout is then not applied to that task.

```ruby
# === task code goes down here ===
DeployPin::Database.execute_with_timeout 30.minutes do
  ActiveRecord::Base.connection.execute('UPDATE shipments SET ...')
end
```

It also accepts `connected_to:` with `role:`, `shard:` and `prevent_writes:`, to run against a replica or a shard declared with `connects_to` in your `ApplicationRecord`:

```ruby
DeployPin::Database.execute_with_timeout 1.minute, connected_to: { role: :reading } do
  Shipment.count
end
```

`connected_to: { database: ... }` is not supported by ActiveRecord 7.2 and later, and raises an `ArgumentError`, as do other options. The timeout is set on the connection the block uses, and that connection's previous timeout is restored afterwards, also when the block raises. See the [`DeployPin::Database` docs](https://rubydoc.info/gems/deploy_pin/DeployPin/Database).

### Parallel

Generate the task with `--parallel`. Inside it, prefix any [Parallel](https://github.com/grosser/parallel) method with `parallel_`. Each block call gets its own connection and runs under the timeout:

```ruby
parallel_each(User.ids.each_slice(1_000).to_a, in_processes: 4, timeout: 5.minutes) do |ids|
  User.where(id: ids).update_all(active: true)
end
```

`timeout:` is used by DeployPin, and the other options (`in_processes:`, `in_threads:`, `progress:`…) are passed to Parallel. See the [`DeployPin::ParallelWrapper` docs](https://rubydoc.info/gems/deploy_pin/DeployPin/ParallelWrapper) for passing timeout options.

### Resumable tasks

Long tasks can save progress in their record and pick up from there on the next run. Use `progress`, `save_progress!(value)` and `increment_progress!(by)`:

```ruby
# === task code goes down here ===
User.where('id > ?', progress).find_each do |user|
  user.recalculate_stats!
  save_progress!(user.id) # resume after the last processed id
end
```

### Recurring tasks

Recurring tasks run on every deploy and are never marked done. Their identifier is an integer you choose (negative ones run last in their group), which sets their order within the group. `--identifier` is required, and the generator writes nothing if it is missing or not an integer:

```bash
rails g deploy_pin:task warm_caches -g III --recurring --identifier 5
```

> [!NOTE]
> Identifiers `0` and `-10` are used by the built-in [deployment state](#deployment-state) tasks. Don't use them.

### Cleaning up old tasks

Once a one-off task has run in every environment, its file is no longer needed. `deploy_pin:cleanup` removes the files of one-off tasks created more than `cleanup_safe_time_window` ago, together with their [tests](#testing-tasks). A task's creation time is the timestamp in its identifier. Set the window to your deployment cycle, from generating a task to running it in every environment, plus a safety buffer:

```ruby
DeployPin.setup do
  cleanup_safe_time_window 6.months
end
```

Run it in your repository and commit the result:

```bash
bundle exec rake 'deploy_pin:cleanup[dry_run]' # lists the files it would remove, one per line
bundle exec rake deploy_pin:cleanup            # removes them
git commit -am 'Remove old DeployPin tasks'
```

- Without `cleanup_safe_time_window`, cleanup removes nothing and fails with a message saying how to set it.
- Only source files are removed. Cleanup doesn't read or change the stored records, so it doesn't need access to your production database. If a removed file comes back, environments where it already ran skip it, because its record is still there.
- Recurring tasks, the built-in deployment state tasks and tasks whose identifier isn't a timestamp are never removed.
- An environment that hasn't deployed within the window will never run the removed tasks. Pick a window longer than the time between deploys of your slowest environment.

### Deployment state

DeployPin can store in Redis whether a deploy is in progress, so your code can check it:

```ruby
DeployPin.setup do
  groups %w[I II III post rollback]
  deployment_state_transition({
    ongoing: %w[I III],  # "ongoing" from the start of I until the end of III
    pending: 'rollback', # "pending" from the start of rollback
    ttl: 20.seconds,     # how long to cache the state in memory
    redis_url: 'redis://localhost:6379'
  })
end

DeployPin.ongoing_deployment? # => true while groups I..III run
DeployPin.pending_deployment? # => true after rollback started
```

### Continue on error

By default, a failing task stops the run. With `continue_on_error`, the error is logged, the task is marked done, and the run continues. This can be useful in CI, where external services may be unavailable:

```ruby
DeployPin.setup do
  continue_on_error ENV.fetch('DEPLOY_PIN_CONTINUE_ON_ERROR', 'false') == 'true'
end
```

### Storage

Task records are kept by a storage provider, set with `storage`:

| Provider | Model | Where |
|---|---|---|
| `:active_record` (default) | `DeployPin::Record` | `deploy_pins` table |
| `:mongoid` | `DeployPin::MongoidRecord` | `deploy_pins` collection |

You can also set `storage` to a class of your own, for example a Sequel or ROM model. It must respond to `.find_by(uuid:)` and `.create(uuid:)`, and its records to `#progress`, `#completed_at`, `#update(attributes)` and `#increment!(attribute, by)`. See the [`DeployPin::Storage` docs](https://rubydoc.info/gems/deploy_pin/DeployPin/Storage).

`DeployPin::Storage.record_class` returns the model of the configured provider. Statement timeouts and the parallel timeout rely on ActiveRecord. Without it, tasks run without a timeout.

### Testing tasks

`rails g deploy_pin:task` also creates a spec for the task, at `spec/deploy_pin/<task file>_spec.rb`. The directory is created if it doesn't exist. The spec runs the task end to end, the same way a deploy does, through `rake 'deploy_pin:run[<identifier>]'`. It checks that the task runs without errors and is marked as done. Add your own expectations for what the task changes:

```ruby
# spec/deploy_pin/20261124120000_backfill_user_names_spec.rb (generated)
RSpec.describe 'DeployPin task 20261124120000_backfill_user_names' do
  subject(:run_task) { Rake::Task['deploy_pin:run'].invoke('20261124120000') }

  # ...

  it 'backfills user names' do
    user = User.create!(email: 'user@example.com', name: nil)

    expect { run_task }.to change { user.reload.name }.to('user@example.com')
  end
end
```

The spec turns off `continue_on_error`, so a failing task always fails its spec.

The spec requires `rails_helper` in a Rails app, and `spec_helper` otherwise, so make sure that helper loads your app.

RSpec is the only supported framework for now. It is detected automatically when the `RSpec` constant is loaded, which is the case when `rspec-rails` is in the `:development` group, as rspec-rails recommends. If nothing is detected, the generator skips the test and says so. Set the framework and the directory, or turn test generation off, in the initializer:

```ruby
DeployPin.setup do
  test_framework :rspec        # detected by default; `false` to not generate tests
  tests_path 'spec/deploy_pin' # default for RSpec
end
```

For a single task, pass `--skip-test` or `--test-framework=rspec` to the generator.

### Output formatting

`run_formatter`, `list_formatter` and `short_list_formatter` control what the rake tasks print. The install generator writes working defaults into the initializer.

<details>
<summary>Default formatters</summary>

```ruby
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
      task.details.each { |key, value| puts("#{key}:\t\t#{value}") }
      puts("\n<<<\n#{task.script.strip.green}\n>>>\n\n")
    end
  )
  short_list_formatter(
    lambda do |group, tasks, start_index|
      puts(" Group: #{group} ".center(38, '=').light_cyan.bold)
      tasks.each.with_index(start_index) do |task, index|
        puts(" Task ##{index} ".center(38, '=').blue.bold)
        task.details.each { |key, value| puts("#{key}:".ljust(20) + value.to_s) }
        puts
      end
    end
  )
end
```

</details>

## Configuration reference

All options are set in `DeployPin.setup`. See the [API docs](https://rubydoc.info/gems/deploy_pin/DeployPin) for details.

| Option | Default | Description |
|---|---|---|
| `tasks_path` | — | Directory with task files (`'lib/deploy_pin'` in the generated initializer) |
| `groups` | — | Ordered list of groups |
| `fallback_group` | — | Group for `deploy_pin:task` when `-g` is not given |
| `statement_timeout` | — | Default database statement timeout |
| `storage` | `:active_record` | `:active_record`, `:mongoid`, or a record class |
| `cleanup_safe_time_window` | not set | How long after its creation `deploy_pin:cleanup` may remove a one-off task's file. See [Cleaning up old tasks](#cleaning-up-old-tasks) |
| `continue_on_error` | `false` | Log failed tasks and continue instead of stopping |
| `test_framework` | detected (`:rspec` if `RSpec` is loaded) | Test framework for generated task tests; `false` to skip them. See [Testing tasks](#testing-tasks) |
| `tests_path` | `'spec/deploy_pin'` | Directory for generated task tests |
| `task_wrapper` | runs the task | `->(task, task_runner) { ... }` around every task, e.g. for logging or error reporting |
| `deployment_state_transition` | off | See [Deployment state](#deployment-state) |
| `run_formatter`, `list_formatter`, `short_list_formatter` | — | See [Output formatting](#output-formatting) |

## Development

You need Ruby (see [`.ruby-version`](.ruby-version)) and Docker. The `pg` and `mysql2` gems compile against the PostgreSQL and MySQL client libraries, so install those first (on macOS: `brew install libpq mysql-client`, then make sure `pg_config` and `mysql_config` are on your `PATH`).

```bash
git clone https://github.com/skcc321/deploy_pin.git && cd deploy_pin
bundle install

# Start the databases (credentials come from .env)
docker compose up -d
set -a; source .env; set +a
export APP_ENV=test RAILS_ENV=test
```

There are two test suites, and CI runs both:

- `bin/test` runs DeployPin in a plain Ruby app, [`test/dummy`](test/dummy), without Rails: the library, the `deploy_pin` command, the rake tasks and the generated specs.
- `bin/test rails` runs it in a Rails app, [`test/rails/dummy`](test/rails/dummy): the engine, `rails g deploy_pin:*`, `bin/rails deploy_pin:run` and the generated specs.

Run them against one database at a time. `DB_ROLE` is `pg`, `mysql`, `mariadb` or `mongodb`:

```bash
DB_ROLE=pg bundle exec rake db:prepare # not needed for mongodb
DB_ROLE=pg bin/rails db:prepare        # the Rails app shares the database
DB_ROLE=pg bin/test
DB_ROLE=pg bin/test rails
DB_ROLE=pg bin/test test/lib/deploy_pin/task_test.rb -n /parse/ # a single file
```

`Gemfile.lock` uses Rails 8.1. To run against Rails 7.2, use its gemfile from [`gemfiles/`](gemfiles):

```bash
BUNDLE_GEMFILE=gemfiles/rails_7_2.gemfile bundle install
BUNDLE_GEMFILE=gemfiles/rails_7_2.gemfile DB_ROLE=pg bin/test rails
```

Linting and docs, also checked on CI:

```bash
bundle exec rubocop
gem install reek && reek lib
bundle exec rake yard # builds doc/, must stay 100% documented
```

<details>
<summary>Run the CI workflow locally with <code>act</code></summary>

With [`act`](https://nektosact.com/installation/index.html) and Docker:

```bash
act pull_request --secret-file .env --container-architecture linux/amd64 -W .github/workflows -j test
```

</details>

## Contributing

Bug reports and pull requests are welcome.

1. For bigger changes, open an [issue](https://github.com/skcc321/deploy_pin/issues) first to discuss them.
2. Fork the repo and create a branch from `master`.
3. Add tests, and run them on at least one SQL database and on `mongodb` if you touch storage.
4. Make sure `rubocop` passes and new public methods have YARD docs.
5. Add a line under `# Unreleased` in [CHANGELOG.md](CHANGELOG.md).
6. Open a pull request. The template asks what changed, why, and how you tested it.

Please report security issues privately. See [SECURITY.md](SECURITY.md).

## Similar gems

- [data-migrate](https://github.com/ilyakatz/data-migrate): data migrations that run alongside schema migrations.
- [maintenance_tasks](https://github.com/Shopify/maintenance_tasks): a Rails engine with a web UI for running data tasks on demand.
- [after_party](https://github.com/theSteveMitchell/after_party): one-off post-deploy rake tasks.

DeployPin sits between them: tasks are tied to the steps of your deploy (groups), with statement timeouts, parallel helpers and deployment state.

## License

Released under the [MIT License](MIT-LICENSE).
