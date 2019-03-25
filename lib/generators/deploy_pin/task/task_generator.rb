class DeployPin::TaskGenerator < Rails::Generators::Base
  source_root File.expand_path('templates', __dir__)

  desc 'This generator creates deploy_pin task at lib/deploy_pin/'
  def create_task_file
    template 'task.rb', "#{DeployPin.tasks_path}/#{file_name}.rb"
  end

  private

    def file_name
      "#{Time.now.strftime('%Y%m%d%H%M%S')}_task"
    end
end
