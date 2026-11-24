# DeployPin

[![Gem Version](https://img.shields.io/gem/v/deploy_pin?color=CC342D)](https://rubygems.org/gems/deploy_pin)
[![Downloads](https://img.shields.io/gem/dt/deploy_pin)](https://rubygems.org/gems/deploy_pin)
[![CI](https://github.com/skcc321/deploy_pin/actions/workflows/verify.yml/badge.svg)](https://github.com/skcc321/deploy_pin/actions/workflows/verify.yml)
[![Docs](https://img.shields.io/badge/docs-rubydoc.info-blue)](https://rubydoc.info/gems/deploy_pin)
[![Ruby](https://img.shields.io/badge/ruby-%E2%89%A5%203.1-CC342D)](#requirements)
[![Rails](https://img.shields.io/badge/rails-7.0%20%E2%80%93%208.x-CC0000)](#requirements)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](MIT-LICENSE)

**Run one-off and recurring tasks around your deployments — data backfills, cache warm-ups, cleanups — in a defined order, exactly once, with database timeouts and resumable progress.**

Migrations are for schema changes. Everything else you need to run during a release (backfill a column, re-index records, call an external API, warm a cache) usually ends up in an ad-hoc rake task that someone has to remember to run. DeployPin keeps these tasks in your repository as plain Ruby files, runs each one once, in the order you define, and remembers what has already run.

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
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
- 🚦 **Deployment state:** `DeployPin.ongoing_deployment?` lets your app behave differently while a deploy is in progress.
- 🍃 **ActiveRecord or Mongoid** storage.

## Requirements

| | |
|---|---|
| Ruby | ≥ 3.1 (CI runs 3.3, 3.4 and 4.0) |
| Rails | ≥ 7.0, < 9 (CI runs 8.1) |
| Storage | ActiveRecord (PostgreSQL, MySQL, MariaDB, …) or Mongoid |
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

## Quick start

```bash
# 1. Generate a task in a group
rails g deploy_pin:task backfill_user_names -g I

# 2. Write the code in lib/deploy_pin/<timestamp>_backfill_user_names.rb

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

### Groups and ordering

`groups` defines the steps of your deploy, in order. For example, `pre` runs before migrations and `I`, `II` and `III` run after them. Tasks are sorted by **group**, then by **identifier**. Negative identifiers run after the other tasks of their group.

A non-recurring task runs only once. When it finishes, it is marked done in the storage, and later runs skip it. If two tasks have the same code, only the first one runs.

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
| `rails g deploy_pin:task <title> -g <group>` | Generate a task. Options: `--parallel`, `--recurring --identifier <n>`, `-a <author>` |
| `rake deploy_pin:list[...]` | List pending tasks, including their code |
| `rake deploy_pin:short_list[...]` | List pending tasks by group, without the code |
| `rake deploy_pin:run[...]` | Run pending tasks |
| `rake deploy_pin:mark_done[...]` | Mark tasks as done without running them. For example, in `db/seeds.rb` for a fresh database, or for a new environment |

## Hooking into your deploy

Run the `pre` group before migrations and the rest after them. A deploy step usually looks like this:

```bash
bundle exec rake 'deploy_pin:run[pre]' db:migrate 'deploy_pin:run[I, II, III]'
```

<details>
<summary>Heroku</summary>

```
# Procfile
release: bundle exec rake 'deploy_pin:run[pre]' db:migrate 'deploy_pin:run[I, II, III]'
```

</details>

<details>
<summary>Capistrano</summary>

```ruby
# lib/capistrano/tasks/deploy_pin.rake
namespace :deploy_pin do
  %w[pre post].each do |step|
    task step do
      groups = step == 'pre' ? 'pre' : 'I, II, III'

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
after 'deploy:migrate', 'deploy_pin:post'
```

</details>

<details>
<summary>Kamal</summary>

After `kamal deploy`, run the tasks in the new container:

```bash
kamal app exec --primary --reuse "bin/rails 'deploy_pin:run[I, II, III]'"
```

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

It also accepts `connected_to:`, to run against a replica or another database. See the [`DeployPin::Database` docs](https://rubydoc.info/gems/deploy_pin/DeployPin/Database).

### Parallel

Generate the task with `--parallel`. Inside it, prefix any [Parallel](https://github.com/grosser/parallel) method with `parallel_`. Each block call gets its own connection and runs under the timeout:

```ruby
parallel_each(User.ids.each_slice(1_000).to_a, in_processes: 4, timeout: 5.minutes) do |ids|
  User.where(id: ids).update_all(active: true)
end
```

See the [`DeployPin::ParallelWrapper` docs](https://rubydoc.info/gems/deploy_pin/DeployPin/ParallelWrapper) for passing timeout options.

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

Recurring tasks run on every deploy and are never marked done. Their identifier is a number you choose, which sets their order within the group:

```bash
rails g deploy_pin:task warm_caches -g III --recurring --identifier 5
```

> [!NOTE]
> Identifiers `0` and `-10` are used by the built-in [deployment state](#deployment-state) tasks. Don't use them.

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

`DeployPin::Storage.record_class` returns the model of the configured provider. Statement timeouts and the parallel timeout rely on ActiveRecord. Without it, tasks run without a timeout.

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
| `storage` | `:active_record` | `:active_record` or `:mongoid` |
| `continue_on_error` | `false` | Log failed tasks and continue instead of stopping |
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
export RAILS_ENV=test
```

Run the tests against one database at a time. `DB_ROLE` is `pg`, `mysql`, `mariadb` or `mongodb`:

```bash
DB_ROLE=pg bin/rails db:prepare # not needed for mongodb
DB_ROLE=pg bin/test
DB_ROLE=pg bin/test test/lib/deploy_pin/task_test.rb # a single file
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
