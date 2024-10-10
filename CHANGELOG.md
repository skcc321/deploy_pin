# 1.7.0 / 2024-10-10

## Breaking Changes:

* Add support for resumable tasks. When working with long-running code that processes a large dataset
you can store progress and continue the task from where it has stopped/crashed.

!!!You should run `rails g deploy_pin:upgrade` to generate a migration file that will add the required columns to `deploy_pins` table.
