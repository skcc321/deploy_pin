# frozen_string_literal: true

# check task criteria
module DeployPin
  class TaskCriteria
    SKIP_REGEXEP = /\A-(.+[^!])\z/.freeze
    FORCE_REGEXP = /\A([^-].+)!\z/.freeze
    COMMON_REGEXP = /(^[^-]*.+[^!]*$)/.freeze

    attr_reader :identifiers

    def initialize(identifiers:)
      @identifiers = identifiers
    end

    def suitable?(task)
      task_cover = lambda { |task, regexp|
        items = identifiers.flat_map { |x| x.to_s.scan(regexp) }.flatten

        items & [task.group, task.uuid]
      }

      return false if task_cover.call(task, SKIP_REGEXEP).any?
      return true if task_cover.call(task, FORCE_REGEXP).any?

      task_cover.call(task, COMMON_REGEXP).any? && !task.done?
    end
  end
end
