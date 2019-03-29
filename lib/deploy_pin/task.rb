# frozen_string_literal: true

# Task wrapper
module DeployPin
  class Task
    attr_reader :file,
      :uuid,
      :group,
      :title,
      :script

    def initialize(file)
      @file = file
      @uuid = nil
      @group = nil
      @title = ""
      @script = ""
    end

    def run
      # eval script
      eval(script)
    end

    def mark
      # store record in the DB
      DeployPin::Record.create(uuid: uuid)
    end

    def done?
      DeployPin::Record.where(uuid: uuid).exists?
    end

    def parse_file
      File.foreach(file) do |line|
        case line.strip
        when /\A# (\d+):(\w+)/
          @uuid = $1
          @group = $2
        when /\A# task_title:(.+)/
          @title = $1.strip
        when /\A[^#].*/
          @script += line
        end
      end
    end

    def details
      {
        uuid: uuid,
        group: group,
        title: title
      }
    end

    def eql?(task_b)
      script == task_b.script
    end

    protected

      # for sorting
      def <=>(task_b)
        group_index <=> task_b.group_index
      end

      def group_index
        DeployPin.groups.index(group)
      end
  end
end
