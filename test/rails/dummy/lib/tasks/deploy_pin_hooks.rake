# frozen_string_literal: true

# An app-defined hook on deploy_pin:run, which specs generated in a Rails app must
# load (Rails.application.load_tasks). Only active when DEPLOY_PIN_HOOK_FILE is set;
# see test/rails/integration_test.rb.
if (hook_file = ENV.fetch('DEPLOY_PIN_HOOK_FILE', nil))
  task 'deploy_pin:run' do
    File.write(hook_file, 'hook ran')
  end
end
