# 2.0.1 / 2026-11-24
### Documented
* Run one DeployPin executor at a time per storage: DeployPin does not coordinate overlapping `deploy_pin:run`s or a `deploy_pin:mark_done` during a run, which can run the same pending task twice. See "Running one executor at a time" in the README.

### Fixed
* Tasks generated within the same second no longer get the same identifier, which made the second one be skipped once the first was done. One-off tasks with the same identifier now stop `run`, `list`, `short_list` and `mark_done` with an error naming both files, whichever groups are selected.
* Task code is kept as written: comments and blank lines, e.g. in heredocs, are no longer removed. Header lines are read from the header only, so `# 456:II` in the code no longer changes the task's identifier and group. Code that only mentions `parallel` or `execute_with_timeout` in a string or comment keeps the default timeout. Tasks that differ only in standalone comments and blank lines are still duplicates, while differences inside heredocs and strings count, and headers such as `# 3:I:` still work.
* The upgrade migration (`deploy_pin upgrade`, `rails g deploy_pin:upgrade`) only marks records done when it adds `completed_at` to a pre-1.7 table. On a newer table it no longer marks unfinished tasks done or overwrites completion times. It cannot be rolled back (`ActiveRecord::IrreversibleMigration`), since a rollback would remove the columns and the task state in them.
* `DeployPin::Database.execute_with_timeout` restores the connection's previous timeout after the block, also when it raises, and sets it on the connection the block uses, detecting the database of each connection. `connected_to:` takes `role:`, `shard:` and `prevent_writes:`; `connected_to: { database: }`, which ActiveRecord 7.2+ no longer supports, and unknown options raise an `ArgumentError` that says so.
* `parallel_*` methods pass `in_threads:`, `in_processes:` and other Parallel options given next to `timeout:` to Parallel instead of dropping them, and no longer change the timeout array or the options passed to them.
* `deploy_pin task --recurring` (and `rails g deploy_pin:task --recurring`) requires an integer `--identifier`, and writes nothing without one. Tasks it created before were skipped.
* `DeployPin.load_tasks` (or `Rails.application.load_tasks`) called twice no longer runs each task twice per `rake deploy_pin:run`.

# 2.0.0 / 2026-11-24
### Breaking changes
* Requires Rails (or, without Rails, ActiveSupport) 7.2 or later. Rails 7.0 and 7.1 are end-of-life: apps on them stay on deploy_pin 1.10. CI runs Rails 7.2 and 8.1.
* deploy_pin no longer depends on `rails`, but on `activesupport`, `thor` and `rake`. Rails apps already have them.

### Added
* DeployPin works without Rails. Rails is no longer a dependency (ActiveSupport and Thor are). In other Ruby apps:
  * the `deploy_pin` command runs the generators: `deploy_pin install` (creates `config/deploy_pin.rb`), `deploy_pin task` and `deploy_pin upgrade`. It loads `config/deploy_pin.rb` first, or the files given with `--require`;
  * `DeployPin.load_tasks` adds the `deploy_pin:*` rake tasks to a Rakefile. They run the app's `environment` task first when there is one, else `DeployPin.load_config`.
  Rails apps keep working as before: the engine loads the rake tasks, `rails g deploy_pin:task` runs the same task generator, and `rails g deploy_pin:install`/`upgrade` keep Rails' migration numbering. Both share the templates.
* `storage` accepts a record class of your own, e.g. for Sequel or ROM.
* `deploy_pin install` takes `--config-path` and `--migrations-path`.

### Changed
* Outside Rails apps, the spec generated for a task requires `spec_helper` and loads the rake tasks with `DeployPin.load_tasks`. In Rails apps it is unchanged (`rails_helper`, `Rails.application.load_tasks`).
* The generators no longer read `DeployPin.fallback_group` when they are loaded, but when they run.

### Fixed
* The statement timeout on MariaDB was 1000 times too long: `max_statement_time` is in seconds, and DeployPin set it in milliseconds.
* Rake task arguments after the first comma were ignored: `rake 'deploy_pin:run[I, !20190401135040]'` ran all of group I, including the excluded task. All the selectors are read now. `list[...]`, `short_list[...]` and `mark_done[...]` with an argument also crashed when task files existed.
* `DeployPin::Database.execute_with_timeout` with `connected_to: { role: ... }` falls back to `ActiveRecord::Base` when the app has no `ApplicationRecord`.

# 1.10.0 / 2026-11-24
### Added
* `rails g deploy_pin:task` generates an RSpec spec for each task that runs it through `rake deploy_pin:run`. The spec goes to `spec/deploy_pin/` by default. RSpec is detected when the `RSpec` constant is loaded. Configure with `test_framework` (`:rspec`, or `false` to turn off) and `tests_path`, or pass `--skip-test` / `--test-framework` to the generator.
### Fixed
* Rails 7.1+ apps no longer fail to boot when tasks live in an autoloaded `lib/` directory (`config.autoload_lib`): DeployPin tells Zeitwerk to ignore `tasks_path`.
* Tasks no longer crash on databases without statement timeouts (e.g. SQLite, the Rails 8 default) or when `statement_timeout` is not set: they run without a timeout, and a warning is printed once for unsupported databases.

# 1.9.0 / 2026-11-24
### Added
* Mongoid storage provider (`storage :mongoid`) and a `--storage` option for `rails g deploy_pin:install`.
* `storage` setting (defaults to `:active_record`) and `DeployPin::Storage` to resolve the record model. Existing configs and `deploy_pins` records are unaffected.
* YARD documentation for the public API (`bundle exec rake yard`), published at https://rubydoc.info/gems/deploy_pin.

### Changed
* Allow `connection_pool` 3.x and `parallel` 2.x; cap `redis` below 7.
* Load ActiveRecord models lazily and skip statement timeouts when ActiveRecord is not loaded.
* Test against Ruby 4.0 and Rails 8.1; update locked development dependencies to resolve security advisories.
* Releases are published with RubyGems trusted publishing and carry build attestations.

### Fixed
* The `!` force and skip syntax now works for one-character groups and identifiers (e.g. `I!`, `!I`), which matched nothing before.

# 1.7.6 / 2025-11-25
# Add `rake deploy_pin:mark_done` task to mark specific deploy pins as completed based on criteria.

# 1.7.5 / 2025-06-13
* Add validation for `group` attribute in task generation. Group should be present in the allowed groups list.

# 1.7.4 / 2025-06-13
* Change default affected areas
* Add possibility to remove fallback_group from initializer and make `--group` attribute required on task generation

# 1.7.3 / 2025-01-23
* Add `short_list` rake task for concise task listings.
* Support Ruby on Rails 8 and update dependencies.

# 1.7.2 / 2024-10-17
* Add `save_progress!` method to store progress explicitly.

# 1.7.1 / 2024-10-11
* Mark existing deploy pins as completed during upgrade.

# 1.7.0 / 2024-10-10

## Breaking Changes:

* Add support for resumable tasks. When working with long-running code that processes a large dataset
you can store progress and continue the task from where it has stopped/crashed.

!!!You should run `rails g deploy_pin:upgrade` to generate a migration file that will add the required columns to `deploy_pins` table.
