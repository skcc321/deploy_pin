# frozen_string_literal: true

class DeployPin::TaskGenerator < Rails::Generators::Base
  class_option :parallel, type: :boolean
  argument :group, default: "post_script"

  source_root File.expand_path('templates', __dir__)

  desc 'This generator creates deploy_pin task at lib/deploy_pin/'
  def create_task_file
    raise "Not allowed 'group' argument! possible values are #{DeployPin.groups}" \
      unless DeployPin.groups.include?(group)

    template_file = if options[:parallel]
                      'parallel_task.rb.erb'
                    else
                      'task.rb.erb'
                    end

    @uuid = Time.now.strftime('%Y%m%d%H%M%S')
    template template_file, "#{DeployPin.tasks_path}/#{@uuid}_task.rb"
  end
end
