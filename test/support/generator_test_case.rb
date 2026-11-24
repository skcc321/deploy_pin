# frozen_string_literal: true

require 'tmpdir'

module DeployPin
  # Runs DeployPin generators (plain Thor groups) in a temporary directory.
  class GeneratorTestCase < ActiveSupport::TestCase
    attr_reader :destination

    setup do
      @destination = Dir.mktmpdir('deploy_pin_generators')
    end

    teardown do
      FileUtils.rm_rf(destination)
    end

    private

      # Runs the generator like the `deploy_pin` command does.
      # @return [Array(String, String)] stdout and stderr
      def run_generator(klass, args = [], behavior: :invoke)
        capture_io { klass.start(args, destination_root: destination, behavior:) }
      end

      # Builds the generator without running it (it validates its options on creation).
      def build_generator(klass, args = [])
        klass.new(*Thor::Options.split(args), destination_root: destination)
      end

      def generated(pattern)
        Dir[File.join(destination, pattern)].map { |path| path.delete_prefix("#{destination}/") }
      end

      def read(path)
        File.read(File.join(destination, path))
      end

      def write(path, content = '')
        FileUtils.mkdir_p(File.dirname(File.join(destination, path)))
        File.write(File.join(destination, path), content)
      end
  end
end
