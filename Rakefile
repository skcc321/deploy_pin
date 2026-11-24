# frozen_string_literal: true

require 'bundler/setup'

require 'bundler/gem_tasks'
require 'yard'

# db:prepare and the deploy_pin:* tasks of the plain Ruby app in test/dummy
import 'test/dummy/Rakefile'

YARD::Rake::YardocTask.new(:yard)

desc 'Run the plain Ruby test suite (test/dummy)'
task :test do
  sh 'bin/test'
end

namespace :test do
  desc 'Run the Rails test suite (test/rails/dummy)'
  task :rails do
    sh 'bin/test rails'
  end

  desc 'Run both test suites'
  task all: %i[test test:rails]
end
