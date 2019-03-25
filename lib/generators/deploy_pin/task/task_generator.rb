# frozen_string_literal: true

class DeployPin::TaskGenerator < Rails::Generators::Base
  source_root File.expand_path('templates', __dir__)
  argument :group, default: "post_script"

  desc 'This generator creates deploy_pin task at lib/deploy_pin/'
  def create_task_file
    @uuid = Time.now.strftime('%Y%m%d%H%M%S')

    template 'task.rb.erb', "#{DeployPin.tasks_path}/#{@uuid}_task.rb"
  end
end
