# frozen_string_literal: true

# check task criteria
module DeployPin
  class TaskCriteria
    SKIP_REGEXEP = /\A-(.+[^!])\z/
    FORCE_REGEXP = /\A([^-].+)!\z/
    COMMON_REGEXP = /(^[^-]*.+[^!]*$)/

    attr_reader :identifiers

    def initialize(identifiers:)
      @identifiers = identifiers
    end

    def suitable?(task)
      task_cover = ->(task, regexp) {
        items = identifiers.flat_map {|x| x.to_s.scan(regexp) }.flatten

        items & [task.group, task.uuid]
      }

      return false if task_cover.(task, SKIP_REGEXEP).any?
      return true if task_cover.(task, FORCE_REGEXP).any?

      task_cover.(task, COMMON_REGEXP).any? && !task.done?
    end
  end
end
