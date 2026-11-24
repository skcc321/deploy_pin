# frozen_string_literal: true

module DeployPin
  # A task loaded from a file in {DeployPin.tasks_path}.
  #
  # The file starts with a header, followed by the code to run:
  #
  #     # 20190401135040:I
  #     # task_title: Backfill user names
  #     # affected_areas: users
  #
  #     # === task code goes down here ===
  #     User.where(name: nil).find_each { |user| user.update!(name: user.email) }
  #
  # The first line is `# <identifier>:<group>`, or `# <identifier>:<group>:recurring`
  # for a task that runs on every deployment. Negative identifiers sort after
  # the other tasks of their group.
  #
  # The code is evaluated in the context of the task, so it can call the
  # {ParallelWrapper} `parallel_*` methods and {#increment_progress!}.
  #
  # Tasks run under {DeployPin.statement_timeout}, unless their code calls
  # {Database.execute_with_timeout} or uses Parallel.
  # :reek:TooManyMethods
  class Task # rubocop:disable Metrics/ClassLength
    extend ::DeployPin::ParallelWrapper
    include ::DeployPin::ParallelWrapper

    # @return [String] path of the task file, or the task source for built-in tasks
    attr_reader :file
    # @return [Integer, nil] the identifier from the header, usually a timestamp
    attr_reader :identifier
    # @return [String, nil] the group from the header, one of {DeployPin.groups}
    attr_reader :group
    # @return [String] the `task_title` from the header
    attr_reader :title
    # @return [String] the `affected_areas` from the header
    attr_reader :affected_areas
    # @return [String] the code to run
    attr_reader :script
    # @return [String, nil] `"recurring"` for a task that runs on every deployment
    attr_reader :recurring
    # @return [Boolean] whether the code calls {Database.execute_with_timeout} itself
    attr_reader :explicit_timeout

    # @!method progress
    #   @return [Integer] the progress saved with {#increment_progress!} or {#save_progress!}
    delegate :progress, to: :record

    # @param file [String] path of a task file, or task source starting with
    #   `# no_file_task`. Call {#parse} to load it.
    def initialize(file)
      @file = file
      @identifier = nil
      @group = nil
      @title = ''
      @affected_areas = ''
      @script = ''
      @explicit_timeout = false
      @parallel = false
    end

    # Evaluates the task code.
    #
    # @return [Object] the result of the code
    def run
      # eval script
      eval(script)
    end

    # @return [Object, nil] the stored record for this task (see {Storage}), or nil
    def record
      DeployPin::Storage.record_class.find_by(uuid: identifier)
    end

    # Creates the stored record for a non-recurring task if it does not exist yet.
    #
    # @return [void]
    def prepare
      return if recurring

      DeployPin::Storage.record_class.create(uuid: identifier) unless record
    end

    # Stores the completion time of a non-recurring task.
    #
    # @return [void]
    def mark
      return if recurring

      # store record in the DB
      record.update(completed_at: Time.current)
    end

    # Adds to the saved progress, so a long task can resume where it stopped.
    #
    # @example In a task file
    #   User.where('id > ?', progress).find_each do |user|
    #     user.touch
    #     increment_progress!(1)
    #   end
    # @param incrementor [Integer]
    # @return [void]
    # @raise [NotImplementedError] for recurring tasks
    def increment_progress!(incrementor)
      raise NotImplementedError, 'Recurring tasks do not support progress yet.' if recurring

      record.increment!(:progress, incrementor)
    end

    # Overwrites the saved progress.
    #
    # @param value [Integer]
    # @return [void]
    # @raise [NotImplementedError] for recurring tasks
    def save_progress!(value)
      raise NotImplementedError, 'Recurring tasks do not support progress yet.' if recurring

      record.update(progress: value)
    end

    # @return [Boolean, nil] whether the task has been completed; nil for
    #   recurring tasks and tasks that have not started
    def done?
      return if recurring
      return unless record

      record.completed_at.present?
    end

    # @return [Boolean] whether the task should run under {DeployPin.statement_timeout}
    def under_timeout?
      !explicit_timeout? && !parallel?
    end

    # Reads the header and the code from {#file}.
    #
    # @return [void]
    # :reek:TooManyStatements
    def parse # rubocop:disable Metrics/MethodLength
      each_line do |line|
        case line.strip
        when /\A# (-?\d+):(\w+):?(recurring)?/
          @identifier = Regexp.last_match(1).to_i
          @group = Regexp.last_match(2)
          @recurring = Regexp.last_match(3)
        when /\A# task_title:(.+)/
          @title = Regexp.last_match(1).strip
        when /\A# affected_areas:(.+)/
          @affected_areas = Regexp.last_match(1).strip
        when /\A[^#].*/
          @script += line

          @explicit_timeout = true if line =~ /Database.execute_with_timeout.*/
          @parallel = true if line =~ /[Pp]arallel.*/
        end
      end
    end
    # :reek:TooManyStatements

    # @yieldparam line [String] each line of the task source
    # @return [void]
    def each_line(&block)
      if file.starts_with?('# no_file_task')
        file.each_line(&block)
      else
        File.foreach(file, &block)
      end
    end

    # @return [Hash{Symbol => Object}] identifier, group, title and affected areas, for formatters
    def details
      {
        identifier:,
        group:,
        title:,
        affected_areas:
      }
    end

    # Whether another task has the same code but a different identifier.
    #
    # @param other [Task]
    # @return [Boolean]
    def eql?(other)
      # same script & different identifier
      script == other.script && identifier != other.identifier
    end

    # @return [Integer] a timestamp a year ahead, used to sort negative identifiers last
    def unreachable_future
      1.year.from_now.to_date.strftime('%Y%m%d%H%M%S').to_i
    end

    # @return [Array(Integer, Integer)] group position and identifier, used for sorting
    def sorting_key
      if identifier.to_i.negative?
        [group_index, unreachable_future + identifier]
      else
        [group_index, identifier]
      end
    end

    # Orders tasks by group position, then identifier.
    #
    # @param other [Task]
    # @return [Integer, nil]
    def <=>(other)
      sorting_key <=> other.sorting_key
    end

    protected

      # @return [Integer, nil] position of {#group} in {DeployPin.groups}
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
  # :reek:TooManyMethods
end
