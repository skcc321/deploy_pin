module DeployPin
  class Railtie < ::Rails::Railtie
    rake_tasks do
      load 'tasks/deploy_pin_tasks.rake'
    end
  end
end
