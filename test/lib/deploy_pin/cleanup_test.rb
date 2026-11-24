# frozen_string_literal: true

require 'test_helper'

# `rake deploy_pin:cleanup`: removes the source files and tests of one-off
# tasks created (the timestamp in their identifier) more than
# `cleanup_safe_time_window` ago. Stored records are not looked at.
class DeployPin::CleanupTest < ActiveSupport::TestCase
  SPECS_DIR = "#{TASKS_DIR}spec/".freeze

  setup do
    DeployPin.setup do
      cleanup_safe_time_window 30.days
      tests_path SPECS_DIR
    end
    FileUtils.mkdir_p(SPECS_DIR)

    @old_id = timestamp(31.days.ago)
    @old = add_task('old', @old_id)
    @recent = add_task('recent', timestamp(29.days.ago))
    @recurring = add_task('recurring', 5, recurring: true)
    @not_a_timestamp = add_task('not_a_timestamp', 75_371_573_753_751)
    @negative = add_task('negative', -3)
  end

  test 'removes old tasks and their tests, whatever their records' do
    removed = cleanup

    assert_equal ["#{specs_dir}#{@old_id}_old_spec.rb", "#{tasks_dir}#{@old_id}_old.rb"], removed
    refute_path_exists @old
    refute_path_exists spec(@old)
    [@recent, @recurring, @not_a_timestamp, @negative].each do |file|
      assert_path_exists file
      assert_path_exists spec(file)
    end
  end

  test 'does not read or change the records' do
    DeployPin::Storage.record_class.create(uuid: @old_id)

    assert_equal 2, cleanup.size
    assert_nil DeployPin::Storage.record_class.find_by(uuid: @old_id).completed_at
  end

  test 'dry run returns the files without removing them' do
    assert_equal 2, cleanup(dry_run: true).size
    assert_path_exists @old
    assert_path_exists spec(@old)
  end

  test 'removes nothing when the window is not set' do
    DeployPin.remove_instance_variable(:@cleanup_safe_time_window)

    error = assert_raises(DeployPin::CleanupWindowNotSetError) { cleanup }
    assert_match 'cleanup_safe_time_window 6.months', error.message
    assert_path_exists @old
  end

  test 'accepts a window in seconds' do
    DeployPin.setup { cleanup_safe_time_window 28 * 24 * 3600 }

    assert_equal 4, cleanup.size
  end

  test 'finds tests in the default directory when tests_path changed' do
    DeployPin.setup { tests_path "#{TASKS_DIR}other/" }

    assert_equal ["#{tasks_dir}#{@old_id}_old.rb"], cleanup
  end

  test 'keeps built-in deployment state tasks' do
    DeployPin.setup do
      groups %w[I II III rollback]
      deployment_state_transition({ ongoing: %w[I III], pending: 'rollback', ttl: 1.second,
                                    redis_url: 'redis://localhost:6379' })
    end

    assert_equal 2, cleanup.size
  end

  test 'Runner.cleanup prints each path, and a summary unless it is a dry run' do
    paths = "#{specs_dir}#{@old_id}_old_spec.rb\n#{tasks_dir}#{@old_id}_old.rb\n"

    DeployPin::Runner.stub(:test_env?, false) do
      assert_output(paths) { DeployPin::Runner.cleanup(dry_run: true) }
      assert_output("#{paths.gsub(/^/, 'Removed ')}Removed 2 files\n") { DeployPin::Runner.cleanup }
    end
    refute_path_exists @old
  end

  test 'keeps tasks whose identifier is not exactly a 14-digit timestamp' do
    invalid = [
      add_task('extra_digit', "#{@old_id}1".to_i),  # strptime ignores the extra digit
      add_task('february_30', 20_230_230_120_000),  # strptime turns it into March 2
      add_task('short', @old_id / 10)
    ]

    assert_equal 2, cleanup.size
    invalid.each { |file| assert_path_exists file }
  end

  test 'removes old tasks of groups that are no longer configured' do
    retired = add_task('retired', timestamp(40.days.ago), group: 'retired')

    assert_equal [retired, @old].map { |file| file.delete_prefix('./') },
                 cleanup.grep_v(/_spec\.rb\z/)
  end

  test 'keeps the task when its test cannot be removed, and reports only removed files' do
    other_id = timestamp(32.days.ago)
    other = add_task('other', other_id)
    failing = "#{specs_dir}#{@old_id}_old_spec.rb"
    delete = File.method(:delete)
    deny = ->(path) { File.expand_path(path) == File.expand_path(failing) ? raise(Errno::EACCES) : delete.call(path) }

    error = File.stub(:delete, deny) { assert_raises(DeployPin::CleanupError) { cleanup } }

    assert_equal ["#{specs_dir}#{other_id}_other_spec.rb", "#{tasks_dir}#{other_id}_other.rb"], error.removed
    assert_equal [failing], error.failures.keys
    assert_match failing, error.message
    refute_path_exists other
    assert_path_exists @old
    assert_path_exists failing

    # the next cleanup finds them again
    assert_equal [failing, "#{tasks_dir}#{@old_id}_old.rb"], cleanup
  end

  test 'Runner.cleanup prints the removed files before raising' do
    failing = "#{specs_dir}#{@old_id}_old_spec.rb"
    error = DeployPin::CleanupError.new(removed: ['a.rb'], failures: { failing => Errno::EACCES.new(failing) })
    collector = Minitest::Mock.new.expect(:cleanup, nil) { raise error }

    DeployPin::Runner.stub(:test_env?, false) do
      DeployPin::Collector.stub(:new, collector) do
        assert_output("Removed a.rb\nRemoved 1 file\n") do
          assert_raises(DeployPin::CleanupError) { DeployPin::Runner.cleanup }
        end
      end
    end
  end

  test 'removes the file it found, not the one a lexically normalized path names' do
    # alias/.. is nested/ for the file system, but tmp/ for File.expand_path
    FileUtils.mkdir_p(["#{TASKS_DIR}nested/child", "#{TASKS_DIR}nested/tasks", "#{TASKS_DIR}tasks"])
    File.symlink(File.expand_path("#{TASKS_DIR}nested/child"), "#{TASKS_DIR}alias")
    DeployPin.setup { tasks_path "#{TASKS_DIR}alias/../tasks" }
    name = "#{@old_id}_same.rb"
    File.write("#{TASKS_DIR}nested/tasks/#{name}", "# #{@old_id}:I\n:found\n")
    File.write("#{TASKS_DIR}tasks/#{name}", "# #{@old_id}:I\n:decoy\n")

    removed = cleanup(dry_run: true)
    assert_equal ["#{tasks_dir}alias/../tasks/#{name}"], removed
    assert_equal ':found', File.read(removed.first).lines.last.strip

    assert_equal removed, cleanup
    refute_path_exists "#{TASKS_DIR}nested/tasks/#{name}"
    assert_path_exists "#{TASKS_DIR}tasks/#{name}"
  end

  test 'does not remove a task file as the test of another task' do
    DeployPin.setup { tests_path TASKS_DIR }
    # a valid recurring task whose name matches the old task's spec name
    lookalike = "#{TASKS_DIR}#{@old_id}_old_spec.rb"
    File.write(lookalike, "# 7:I:recurring\n:lookalike\n")

    assert_equal ["#{tasks_dir}#{@old_id}_old.rb"], cleanup
    assert_path_exists lookalike
    refute_path_exists @old
  end

  test 'created_at and cleanable?' do
    tasks = [@old, @recent, @recurring, @not_a_timestamp, @negative].map do |file|
      DeployPin::Task.new(file).tap(&:parse)
    end

    assert_equal Time.strptime(@old_id.to_s, '%Y%m%d%H%M%S'), tasks.first.created_at
    assert_equal([false, false, true, true, true], tasks.map { |task| task.created_at.nil? })
    assert_equal([true, false, false, false, false], tasks.map { |task| task.cleanable?(before: 30.days.ago) })
  end

  private

    def cleanup(**options)
      DeployPin::Collector.new(identifiers: DeployPin.groups).cleanup(**options)
    end

    def timestamp(time)
      time.strftime('%Y%m%d%H%M%S').to_i
    end

    # Writes a task and its spec, named like the generator names them.
    def add_task(title, identifier, recurring: false, group: 'I')
      file = "#{TASKS_DIR}#{recurring ? 'r_' : ''}#{identifier}_#{title}.rb"
      File.write(file, <<~RUBY)
        # #{identifier}:#{group}#{':recurring' if recurring}
        # task_title: #{title}

        # === task code goes down here ===
        :#{title}
      RUBY
      File.write(spec(file), '')
      file
    end

    def spec(task_file)
      "#{SPECS_DIR}#{File.basename(task_file, '.rb')}_spec.rb"
    end

    # TASKS_DIR as Collector#cleanup returns it: relative to the current directory.
    def tasks_dir
      TASKS_DIR.delete_prefix('./')
    end

    def specs_dir
      SPECS_DIR.delete_prefix('./')
    end
end
