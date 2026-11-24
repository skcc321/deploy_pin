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

    assert_equal ["#{tasks_dir}#{@old_id}_old.rb", "#{specs_dir}#{@old_id}_old_spec.rb"], removed
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
    paths = "#{tasks_dir}#{@old_id}_old.rb\n#{specs_dir}#{@old_id}_old_spec.rb\n"

    DeployPin::Runner.stub(:test_env?, false) do
      assert_output(paths) { DeployPin::Runner.cleanup(dry_run: true) }
      assert_output("#{paths.gsub(/^/, 'Removed ')}Removed 2 files\n") { DeployPin::Runner.cleanup }
    end
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
    def add_task(title, identifier, recurring: false)
      file = "#{TASKS_DIR}#{recurring ? 'r_' : ''}#{identifier}_#{title}.rb"
      File.write(file, <<~RUBY)
        # #{identifier}:I#{':recurring' if recurring}
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
