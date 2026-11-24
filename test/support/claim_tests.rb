# frozen_string_literal: true

require 'rbconfig'
require 'timeout'

# Two `deploy_pin:run`s in separate processes, against the database under
# test, run the same pending task: they are synchronized through pipes
# (test/support/claim_runner.rb), not by sleeping. Included by the plain Ruby
# and the Rails suites, which define `runner_command` and `runner_dir`.
module ClaimTests
  extend ActiveSupport::Concern

  # Only guards against a hang if a claim were never released.
  STEP_TIMEOUT = 60

  # Each run appends `<pid> <progress>` to the log, saves progress 5, then
  # waits for the test at `started`. Runs with CLAIM_RUNNER_FAIL=1 then raise.
  TASK = <<~RUBY
    # 1:I
    # task_title: Claimed task

    # === task code goes down here ===
    File.write(ENV.fetch('CLAIM_RUNNER_LOG'), "\#{Process.pid} \#{progress}\\n", mode: 'a')
    save_progress!(5)
    ClaimRunner.checkpoint('started')
    raise 'boom' if ClaimRunner.fail?
  RUBY

  included do
    # The runners must see the records the other one commits.
    self.use_transactional_tests = false if respond_to?(:use_transactional_tests=)

    setup do
      @tasks_dir = Dir.mktmpdir('deploy_pin_claims')
      @log = File.join(@tasks_dir, 'executions.log')
      File.write(File.join(@tasks_dir, '1_claimed_task.rb'), TASK)
      File.write(@log, '')
      if DeployPin.storage == :mongoid
        DeployPin::MongoidRecord.collection.database[DeployPin::Claim::MongoidLock::COLLECTION].delete_many
      end
      @runners = []
    end

    teardown do
      @runners.each(&:stop)
      FileUtils.rm_rf(@tasks_dir)
    end
  end

  def test_overlapping_runs_execute_a_pending_task_once
    first = start_runner
    first.expect('started')

    second = start_runner
    second.expect('waiting') # the first run holds the claim

    first.continue
    first.expect('done')
    second.expect('done') # it got the claim, saw the task completed and skipped it

    assert_equal 1, executions.size
    refute_nil record.completed_at
  end

  def test_a_failed_run_releases_its_claim_and_the_next_run_resumes_its_progress
    first = start_runner(fail: true)
    first.expect('started')

    second = start_runner
    second.expect('waiting')

    first.continue
    first.expect('failed: boom') # the first process is still alive: it released the claim itself
    second.expect('started')
    second.continue
    second.expect('done')

    assert_equal([0, 5], executions.map { |line| line.split.last.to_i })
    refute_nil record.completed_at
  end

  def test_a_forced_run_runs_the_task_again_after_the_claim
    first = start_runner
    first.expect('started')

    second = start_runner('1!')
    second.expect('waiting')

    first.continue
    first.expect('done')
    second.expect('started')
    second.continue
    second.expect('done')

    assert_equal 2, executions.size
  end

  private

    def executions
      File.readlines(@log, chomp: true)
    end

    def record
      DeployPin::Storage.uncached { DeployPin::Storage.record_class.find_by(uuid: 1) }
    end

    def start_runner(*selectors, fail: false)
      selectors = ['I'] if selectors.empty?
      env = { 'CLAIM_RUNNER_LOG' => @log, 'CLAIM_RUNNER_FAIL' => fail ? '1' : '0' }
      Runner.new(self, env, [*runner_command, @tasks_dir, *selectors], runner_dir).tap { |runner| @runners << runner }
    end

    # A runner process and its pipes.
    class Runner
      def initialize(test, env, command, dir)
        @test = test
        @status, status_writer = IO.pipe
        control_reader, @control = IO.pipe
        @output = Tempfile.new('claim_runner')
        redirects = { 3 => status_writer, 4 => control_reader, %i[out err] => @output.path }
        @pid = Process.spawn(env, *command, chdir: dir, **redirects)
        status_writer.close
        control_reader.close
      end

      # Waits for the runner's next line, which must be `expected`.
      def expect(expected)
        line = Timeout.timeout(STEP_TIMEOUT, Timeout::Error, "no '#{expected}' from the runner") { @status.gets }
        @test.assert_equal expected, line&.chomp, -> { "runner output:\n#{File.read(@output.path)}" }
      end

      # Lets the runner go on from a checkpoint.
      def continue
        @control.puts('go')
      end

      def stop
        @control.close unless @control.closed? # the runner's last checkpoint gets EOF and it exits
        Process.kill('KILL', @pid) unless Timeout.timeout(STEP_TIMEOUT) { Process.wait(@pid) }
      rescue Timeout::Error
        Process.kill('KILL', @pid)
        Process.wait(@pid)
      ensure
        @status.close
        @output.close!
      end
    end
end
