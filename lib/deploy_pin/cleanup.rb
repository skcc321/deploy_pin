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
  #
  # Files are removed by the paths they were found at, never by a normalized
  # copy: `File.expand_path` collapses `link/..` without following the link,
  # which can name another file. A test file that is also a task file (when
  # {DeployPin.tests_path} and {DeployPin.tasks_path} overlap) is not removed
  # as a test.
  class Cleanup
    # @param tasks [Array<Task>] parsed tasks
    def initialize(tasks)
      @tasks = tasks
      @task_sources = nil
    end

    # @param dry_run [Boolean] only return the files, without removing them
    # @return [Array<String>] the removed (or, on a dry run, removable) files,
    #   without the current directory's prefix when they start with it
    # @raise [CleanupWindowNotSetError] if {DeployPin.cleanup_safe_time_window} is not set
    # @raise [CleanupError] if some files could not be removed; the others are
    #   removed, and listed in {CleanupError#removed}
    # :reek:BooleanParameter and :reek:ControlParameter
    def call(dry_run: false)
      files = files_by_task
      return files.flatten.map { |path| display_path(path) } if dry_run

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
          [*task.test_files.reject { |path| task_source?(path) }, task.file]
        end
      end

      # Whether a file is a task file, with an identifier in its header,
      # whatever path names it. Generated tests have no identifier, so they are
      # removed even when they are in the tasks directory.
      def task_source?(path)
        @task_sources ||= @tasks.select { |task| task.identifier && !task.built_in? }
                                .filter_map { |task| real_path(task.file) }.to_set
        @task_sources.include?(real_path(path))
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
          removed << display_path(path)
        rescue Errno::ENOENT
          next # already gone
        rescue SystemCallError => e
          failures[display_path(path)] = e
          break
        end
      end

      # The path without the current directory's prefix (and the slashes after
      # it), `.` components and repeated slashes, which name the same file from the current directory.
      # `..` components are kept: after a symbolic link, they lead elsewhere
      # than a lexical normalization says.
      # :reek:UtilityFunction and :reek:TooManyStatements
      def display_path(path)
        cwd = Regexp.escape(Dir.pwd.chomp('/'))
        head, *parts = path.sub(%r{\A#{cwd}/+}, '').split('/', -1)
        parts = parts.reject { |part| part.empty? || part == '.' }
        head == '.' ? parts.join('/') : [head, *parts].join('/')
      end

      # :reek:UtilityFunction
      def real_path(path)
        File.realpath(path)
      rescue SystemCallError
        nil
      end
  end
end
