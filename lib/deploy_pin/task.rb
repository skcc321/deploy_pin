# frozen_string_literal: true

# Task wrapper
module DeployPin
  class Task
    extend ::DeployPin::ParallelWrapper
    include ::DeployPin::ParallelWrapper

    attr_reader :file,
                :identifier,
                :group,
                :title,
                :script,
                :recurring,
                :explicit_timeout

    def initialize(file)
      @file = file
      @identifier = nil
      @group = nil
      @title = ''
      @script = ''
      @explicit_timeout = false
      @parallel = false
    end

    def run
      # eval script
      eval(script)
    end

    def mark
      return if recurring

      # store record in the DB
      DeployPin::Record.create(uuid: identifier)
    end

    def done?
      return if recurring

      DeployPin::Record.where(uuid: identifier).exists?
    end

    def under_timeout?
      !explicit_timeout? && !parallel?
    end

    def parse
      each_line do |line|
        case line.strip
        when /\A# (-?\d+):(\w+):?(recurring)?/
          @identifier = Regexp.last_match(1).to_i
          @group = Regexp.last_match(2)
          @recurring = Regexp.last_match(3)
        when /\A# task_title:(.+)/
          @title = Regexp.last_match(1).strip
        when /\A[^#].*/
          @script += line

          @explicit_timeout = true if line =~ /Database.execute_with_timeout.*/
          @parallel = true if line =~ /[Pp]arallel.*/
        end
      end
    end

    def each_line(&block)
      if file.starts_with?('# no_file_task')
        file.each_line(&block)
      else
        File.foreach(file, &block)
      end
    end

    def details
      {
        identifier: identifier,
        group: group,
        title: title
      }
    end

    def eql?(other)
      # same script & different identifier
      script == other.script && identifier != other.identifier
    end

    def unreachable_future
      1.year.from_now.to_date.strftime('%Y%m%d%H%M%S').to_i
    end

    def sorting_key
      if identifier.to_i.negative?
        [group_index, unreachable_future + identifier]
      else
        [group_index, identifier]
      end
    end

    # for sorting
    def <=>(other)
      sorting_key <=> other.sorting_key
    end

    protected


      def group_index
        DeployPin.groups.index(group)
      end

      def explicit_timeout?
        @explicit_timeout
      end

      def parallel?
        @parallel
      end
  end
end
