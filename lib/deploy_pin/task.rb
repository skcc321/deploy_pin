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

    delegate :progress, to: :record

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

    def remove
      File.delete(file) if File.exist?(file)
      record&.destroy
    end

    def record
      DeployPin::Record.find_by(uuid: identifier)
    end

    def prepare
      return if recurring

      DeployPin::Record.create(uuid: identifier) unless record
    end

    def mark
      return if recurring

      # store record in the DB
      record.update(completed_at: Time.current)
    end

    def increment_progress!(incrementor)
      raise NotImplementedError, 'Recurring tasks do not support progress yet.' if recurring

      record.increment!(:progress, incrementor)
    end

    def save_progress!(value)
      raise NotImplementedError, 'Recurring tasks do not support progress yet.' if recurring

      record.update(progress: value)
    end

    def done?
      return if recurring
      return unless record

      record.completed_at.present?
    end

    def under_timeout?
      !explicit_timeout? && !parallel?
    end

    def classified_for_cleanup?
      return false unless done?

      record.completed_at < DeployPin.cleanup_safe_time_window.call.ago
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
        identifier:,
        group:,
        title:
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
