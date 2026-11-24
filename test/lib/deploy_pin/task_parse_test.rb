# frozen_string_literal: true

require 'test_helper'

# Metadata comes from the header only; the code after it is kept as written.
class DeployPin::TaskParseTest < ActiveSupport::TestCase
  test 'a heredoc keeps its comment-like lines and blank lines, and does not change the header' do
    task = parse(<<~'RUBY')
      # frozen_string_literal: true

      # 123:I
      # task_title: Heredoc task
      # affected_areas: none

      # === task code goes down here ===
      $heredoc = <<~TEXT
        # 456:II:recurring
        # task_title: not the title

        Parallel.each and execute_with_timeout are only words here
      TEXT
    RUBY

    assert_equal [123, 'I', nil, 'Heredoc task', 'none'],
                 [task.identifier, task.group, task.recurring, task.title, task.affected_areas]
    task.run
    assert_equal "# 456:II:recurring\n# task_title: not the title\n\n" \
                 "Parallel.each and execute_with_timeout are only words here\n", $heredoc # rubocop:disable Style/GlobalVars
    assert_predicate task, :under_timeout?
  end

  test 'comments and blank lines in the code are kept' do
    task = parse(<<~RUBY)
      # 1:I
      # task_title: t

      # === task code goes down here ===
      a = 1

      # a comment in the code
      a
    RUBY

    assert_equal "a = 1\n\n# a comment in the code\na\n", task.script
  end

  test 'a task file without the code delimiter' do
    task = parse(<<~RUBY)
      # 20190401135040:II:recurring
      # task_title: No delimiter
      # affected_areas: users
      x = <<~TEXT
        # 1:III
      TEXT
      x.strip
    RUBY

    assert_equal [20_190_401_135_040, 'II', 'recurring', 'No delimiter', 'users'],
                 [task.identifier, task.group, task.recurring, task.title, task.affected_areas]
    assert_equal '# 1:III', task.run
  end

  test 'the template of the generator' do
    task = parse(<<~RUBY)
      # frozen_string_literal: true

      # -5:III
      # task_title: @jane Generated
      # affected_areas: Please, provide a list of affected areas.

      # === parallel task code goes down here ===
      Parallel.each([1]) { |i| i }

      # DeployPin::Database::execute_with_timeout 10.minutes do
      # end
    RUBY

    assert_equal [-5, 'III', '@jane Generated'], [task.identifier, task.group, task.title]
    assert task.script.start_with?("Parallel.each([1]) { |i| i }\n\n# DeployPin::Database")
    refute_predicate task, :under_timeout?
    refute task.explicit_timeout
  end

  test 'the built-in deployment state tasks' do
    DeployPin.deployment_state_transition({ ongoing: %w[I III], pending: 'II', ttl: 1.second })
    tasks = DeployPin.deployment_tasks_code.map { |code| DeployPin::Task.new(code).tap(&:parse) }

    assert_equal([[0, 'I', 'recurring'], [-10, 'III', 'recurring'], [0, 'II', 'recurring']],
                 tasks.map { |task| [task.identifier, task.group, task.recurring] })
    assert_equal ["Set DeployPin.state to 'ongoing'", 'Cleanup DeployPin.state', "Set DeployPin.state to 'pending'"],
                 tasks.map(&:title)
    assert_equal 'DeployPin.send(:deployment_over!)', tasks[1].script.strip
    assert(tasks.all?(&:under_timeout?))
  end

  test 'tasks with the same code and different headers are duplicates' do
    first = parse("# 1:I\n# task_title: first\n\n# === task code goes down here ===\na = 1\n\na\n")
    second = parse("# 2:II\n# task_title: second\n# affected_areas: x\n" \
                   "# === task code goes down here ===\n\na = 1\n\na")
    different = parse("# 3:I\n# === task code goes down here ===\na = 1\n# a comment\na\n")

    assert first.eql?(second)
    refute first.eql?(different)
  end

  test 'explicit timeout and parallel are detected from calls, not from comments or strings' do
    {
      "DeployPin::Database.execute_with_timeout(1) { 1 }\n" => [true, false],
      "Parallel.map([1]) { |i| i }\n" => [false, true],
      "parallel_each([1]) { |i| i }\n" => [false, true],
      "# DeployPin::Database.execute_with_timeout\n# Parallel.each\n1\n" => [false, false],
      "puts 'run in parallel, without execute_with_timeout'\n" => [false, false],
      "parallel_count = 2\nparallel_count\n" => [false, false],
      "x = <<~TEXT\n  Parallel.each\n  DeployPin::Database.execute_with_timeout\nTEXT\n" => [false, false]
    }.each do |code, (explicit_timeout, parallel)|
      task = parse("# 1:I\n# === task code goes down here ===\n#{code}")

      assert_equal explicit_timeout, task.explicit_timeout, code
      assert_equal parallel, task.send(:parallel?), code
      assert_equal !explicit_timeout && !parallel, task.under_timeout?, code
    end
  end

  private

    def parse(source)
      file = File.join(DeployPin.tasks_path, "#{SecureRandom.hex(4)}.rb")
      File.write(file, source)
      DeployPin::Task.new(file).tap(&:parse)
    end
end
