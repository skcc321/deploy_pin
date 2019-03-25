class DeployPin::TaskGenerator < Rails::Generators::Base
  source_root File.expand_path('templates', __dir__)

  desc 'This generator creates deploy_pin task at lib/deploy_pin/'
  def create_task_file
    template 'task.rb', "lib/deploy_pin/#{file_name}.rb"
  end

  private

    def file_name
      'task'
    end
end
