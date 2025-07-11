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
