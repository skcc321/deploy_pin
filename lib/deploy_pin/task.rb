# frozen_string_literal: true

# Task wrapper
class DeployPin::Task
  attr_reader :file,
    :group,
    :uuid,
    :script

  def initialize(file)
    @file = file
    @uuid = nil
    @group = nil
    @script = ""
  end

  def run
    eval(@script)
  end

  def parse_file
    @script = File.read(file)
    @script.lines[0] =~ /\A# (\d+):(\w+)/
    @uuid = $1
    @group = $2
  end

  def details
    puts @uuid, @group, @script
  end

  # for sorting
  def <=>(task_b)
    group_index <=> task_b.group_index
  end

  def group_index
    DeployPin.groups.index(group)
  end
end
