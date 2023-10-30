# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require_relative 'lib/deploy_pin/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'deploy_pin'
  spec.version     = DeployPin::VERSION
  spec.authors     = ['Viktor Sych']
  spec.email       = ['skcc321@gmail.com']
  spec.homepage    = 'https://github.com/skcc321/deploy_pin'
  spec.summary     = 'pin some task around deployment'
  spec.description = 'pin some task around deployment to execute them during deployment circle'
  spec.license     = 'MIT'
  spec.required_ruby_version = '>= 3.0'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']
  end

  spec.add_dependency 'colorize', '~> 1.1'
  spec.add_dependency 'connection_pool', '~> 2.2'
  spec.add_dependency 'parallel', '~> 1.23'
  spec.add_dependency 'rails', '~> 7.0'
  spec.add_dependency 'redis', '> 4.0'
  spec.add_dependency 'ruby-progressbar', '~> 1.13'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'mysql2'
  spec.add_development_dependency 'pg'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rubocop-minitest'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'simplecov-review'
  spec.add_development_dependency 'simplecov-small-badge'
end
