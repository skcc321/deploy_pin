$:.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "deploy_pin/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = "deploy_pin"
  spec.version     = DeployPin::VERSION
  spec.authors     = ["rafael"]
  spec.email       = ["skcc321@gmail.com"]
  spec.homepage    = "https://github.com/skcc321/deploy_pin"
  spec.summary     = "pin some task around deployment"
  spec.description = "pin some task around deployment to execute them during deployment circle"
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.add_dependency "rails", "~> 5.2.2", ">= 5.2.2.1"
  spec.add_runtime_dependency 'parallel', '~> 0'
  spec.add_dependency "ruby-progressbar", "~> 1.10"
  spec.add_dependency "rake", "~> 10.0"

  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency "bundler", "~> 1.17"
  spec.add_development_dependency "pry", "~> 0.12"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency 'mysql2', '~> 0.5.2'
  spec.add_development_dependency 'pg', '~> 0.18', '>= 0.18.4'
end
