# frozen_string_literal: true

module DeployPin
  # Raised by `rake deploy_pin:cleanup` when {DeployPin.cleanup_safe_time_window}
  # is not set: cleanup removes nothing until a window is chosen.
  class CleanupWindowNotSetError < StandardError
    # @return [String]
    def message
      'Set DeployPin.cleanup_safe_time_window to choose how long after its creation a task can be ' \
        'removed, e.g. `cleanup_safe_time_window 6.months` in DeployPin.setup.'
    end
  end

  # Raised by `rake deploy_pin:cleanup` when some files could not be removed.
  # A task's file is only removed after its tests, so a task whose test could
  # not be removed is kept, and the next cleanup tries again.
  class CleanupError < StandardError
    # @return [Array<String>] the files that were removed
    attr_reader :removed
    # @return [Hash{String => SystemCallError}] the files that could not be removed, and why
    attr_reader :failures

    # @param removed [Array<String>]
    # @param failures [Hash{String => SystemCallError}]
    def initialize(removed:, failures:)
      @removed = removed
      @failures = failures
      super("Could not remove #{failures.map { |path, error| "#{path} (#{error.message})" }.join(', ')}")
    end
  end

  # Removes the source files and the tests of the one-off tasks created (see
  # {Task#created_at}) more than {DeployPin.cleanup_safe_time_window} ago.
  # Recurring and built-in tasks are kept. Only files are removed: the stored
  # records are neither read nor changed, so a removed file that comes back
  # is not run again where it ran.
  #
  # Each task's tests are removed before its file, so a task whose tests
  # could not be removed stays, and the next cleanup finds them again. Tasks
  # are taken in file name order, whatever their group, so tasks of groups
  # no longer in {DeployPin.groups} are removed too.
  class Cleanup
    # @param tasks [Array<Task>] parsed tasks
    def initialize(tasks)
      @tasks = tasks
    end

    # @param dry_run [Boolean] only return the files, without removing them
    # @return [Array<String>] the removed (or, on a dry run, removable) files,
    #   relative to the current directory when they are in it
    # @raise [CleanupWindowNotSetError] if {DeployPin.cleanup_safe_time_window} is not set
    # @raise [CleanupError] if some files could not be removed; the others are
    #   removed, and listed in {CleanupError#removed}
    # :reek:BooleanParameter and :reek:ControlParameter
    def call(dry_run: false)
      files = files_by_task
      return files.flatten if dry_run

      remove(files)
    end

    private

      # The files of each removable task: its tests, then the task file.
      # :reek:TooManyStatements and :reek:NestedIterators
      def files_by_task
        window = DeployPin.cleanup_safe_time_window
        raise CleanupWindowNotSetError unless window

        before = Time.current - window
        @tasks.select { |task| task.cleanable?(before:) }.sort_by(&:file).map do |task|
          [*task.test_files, task.file].map { |path| relative_path(path) }
        end
      end

      # :reek:TooManyStatements
      def remove(files)
        removed = []
        failures = {}
        files.each { |paths| remove_task(paths, removed, failures) }
        raise CleanupError.new(removed:, failures:) if failures.any?

        removed
      end

      # Removes a task's files in order, stopping at the first failure so that
      # the task file, which comes last, is kept.
      # :reek:UtilityFunction and :reek:TooManyStatements
      def remove_task(paths, removed, failures)
        paths.each do |path|
          File.delete(path)
          removed << path
        rescue Errno::ENOENT
          next # already gone
        rescue SystemCallError => e
          failures[path] = e
          break
        end
      end

      # :reek:UtilityFunction
      def relative_path(path)
        absolute = File.expand_path(path)
        root = "#{Dir.pwd}/"
        absolute.start_with?(root) ? absolute.delete_prefix(root) : path
      end
  end
end
