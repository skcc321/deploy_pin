# frozen_string_literal: true

module DeployPin
  # `rails g deploy_pin:task <title> --group <group> [--parallel] [--recurring --identifier <id>]`:
  # creates a task file in {DeployPin.tasks_path}.
  class TaskGenerator < Rails::Generators::Base
    class_option :parallel, type: :boolean, aliases: '-p'
    class_option :recurring, type: :boolean, aliases: '-r'
    class_option :identifier, aliases: '-i'
    argument :title, required: true
    class_option :group, aliases: '-g', default: DeployPin.fallback_group
    class_option :author, aliases: '-a'

    source_root File.expand_path('templates', __dir__)

    desc 'This generator creates deploy_pin task at lib/deploy_pin/'

    def initialize(*args)
      super

      validate
    end

    # Writes the task file, named after its identifier and title.
    # @return [void]
    def create_task_file
      template_file = if options[:parallel]
                        'parallel_task.rb.erb'
                      else
                        'task.rb.erb'
                      end

      @author = options[:author] || ENV['USER']
      @group = options[:group]
      @recurring = options[:recurring]
      @identifier = @recurring ? options[:identifier] : Time.now.strftime('%Y%m%d%H%M%S')
      filename = @recurring ? "r_#{@identifier}_#{title}.rb" : "#{@identifier}_#{title}.rb"
      template template_file, "#{DeployPin.tasks_path}/#{filename}"
    end

    # @return [void]
    # @raise [Thor::Error] if the group is missing or not in {DeployPin.groups}
    def validate
      raise Thor::Error, set_color('Missing required option: --group', :red) if options[:group].blank?

      return if DeployPin.groups.include?(options[:group])

      raise Thor::Error, set_color("Group '#{options[:group]}' is not defined in DeployPin.groups", :red)
    end
  end
end
