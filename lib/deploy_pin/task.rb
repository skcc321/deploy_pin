# frozen_string_literal: true

# Task wrapper
class DeployPin::Task
  attr_reader :file

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
end
