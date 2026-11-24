# frozen_string_literal: true

module DeployPin
  # Decides whether a task is selected by a list of identifiers. Each
  # identifier is a group name or a task identifier:
  #
  # * `"I"` or `"20190401135040"` selects matching tasks that are not done yet;
  # * `"I!"` or `"20190401135040!"` selects matching tasks even if they are done;
  # * `"!I"` or `"!20190401135040"` excludes matching tasks.
  #
  # @example Re-run one task and skip group II
  #   DeployPin::TaskCriteria.new(identifiers: %w[I 20190401135040! !II]).suitable?(task)
  class TaskCriteria
    # Matches an identifier that excludes tasks (`!I`).
    SKIP_REGEXEP = /\A!([^!]+)\z/
    # Matches an identifier that forces tasks to run again (`I!`).
    FORCE_REGEXP = /\A([^!]+)!\z/
    # Matches a plain identifier (`I`).
    COMMON_REGEXP = /(^[^!]?.+[^!]?$)/

    # @return [Array<String, Integer>]
    attr_reader :identifiers

    # @param identifiers [Array<String, Integer>] groups and task identifiers
    def initialize(identifiers:)
      @identifiers = identifiers
    end

    # @param task [Task] a parsed task
    # @return [Boolean] whether the task is selected
    def suitable?(task)
      return false if covered?(task, SKIP_REGEXEP)
      return true if covered?(task, FORCE_REGEXP)

      covered?(task, COMMON_REGEXP) && !task.done?
    end

    # @param task [Task] a parsed task
    # @return [Boolean] whether the task is selected with `!` (to run even if it is done)
    def forced?(task)
      !covered?(task, SKIP_REGEXEP) && covered?(task, FORCE_REGEXP)
    end

    private

      def covered?(task, regexp)
        items = identifiers.flat_map { |x| x.to_s.scan(regexp) }.flatten

        items.intersect?([task.group, task.identifier.to_s])
      end
  end
end
