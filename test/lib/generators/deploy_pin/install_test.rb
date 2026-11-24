# frozen_string_literal: true

require 'test_helper'
require 'active_record/version'

class DeployPin::Generators::InstallTest < DeployPin::GeneratorTestCase
  MIGRATION = 'db/migrate/*_create_deploy_pins.rb'

  test 'creates config/deploy_pin.rb and the migration for ActiveRecord' do
    run_generator DeployPin::Generators::Install

    assert_equal ['config/deploy_pin.rb'], generated('config/**/*.rb')
    assert_no_match(/storage/, read('config/deploy_pin.rb'))

    migrations = generated(MIGRATION)
    assert_equal 1, migrations.size
    assert_match %r{\Adb/migrate/\d{14}_create_deploy_pins\.rb\z}, migrations.first
    migration = read(migrations.first)
    assert_match "class CreateDeployPins < ActiveRecord::Migration[#{ActiveRecord::VERSION::STRING.to_f}]", migration
    assert_match 'create_table :deploy_pins', migration
  end

  test 'the generated configuration loads' do
    run_generator DeployPin::Generators::Install

    DeployPin.load_config(nil, root: destination)

    assert_equal %w[pre I II III], DeployPin.groups
    assert_equal 'lib/deploy_pin', DeployPin.tasks_path
    assert_equal 'III', DeployPin.fallback_group
    assert_equal 10.minutes, DeployPin.statement_timeout
    assert_equal 20.seconds, DeployPin.deployment_state_transition[:ttl]
    assert_kind_of Proc, DeployPin.run_formatter
  end

  test 'with mongoid storage skips the migration and prints the indexes hint' do
    output, = run_generator DeployPin::Generators::Install, ['--storage=mongoid']

    assert_empty generated(MIGRATION)
    assert_match(/storage :mongoid/, read('config/deploy_pin.rb'))
    assert_match 'DeployPin::MongoidRecord.create_indexes', output
  end

  test 'rejects an unknown storage' do
    assert_raises(Thor::Error) { build_generator(DeployPin::Generators::Install, ['--storage=sequel']) }
  end

  test 'writes the configuration to --config-path' do
    run_generator DeployPin::Generators::Install, ['--config-path=config/initializers/deploy_pin.rb']

    assert_equal ['config/initializers/deploy_pin.rb'], generated('config/**/*.rb')
  end

  test 'writes the migration to --migrations-path' do
    run_generator DeployPin::Generators::Install, ['--migrations-path=db/migrations']

    assert_empty generated(MIGRATION)
    assert_equal 1, generated('db/migrations/*_create_deploy_pins.rb').size
  end

  test 'numbers the migration after the existing ones' do
    write 'db/migrate/99990101000000_create_users.rb'

    run_generator DeployPin::Generators::Install

    assert_equal ['db/migrate/99990101000001_create_deploy_pins.rb'], generated(MIGRATION)
  end

  test 'fails when the migration exists' do
    write 'db/migrate/20190328085157_create_deploy_pins.rb', 'old'

    _, error = capture_io do
      assert_raises(SystemExit) { DeployPin::Generators::Install.start([], destination_root: destination) }
    end

    assert_match 'Another migration is already named create_deploy_pins', error
    assert_equal ['db/migrate/20190328085157_create_deploy_pins.rb'], generated(MIGRATION)
  end

  test 'keeps the existing migration with --skip' do
    write 'db/migrate/20190328085157_create_deploy_pins.rb', 'old'

    run_generator DeployPin::Generators::Install, ['--skip']

    assert_equal ['db/migrate/20190328085157_create_deploy_pins.rb'], generated(MIGRATION)
    assert_equal 'old', read('db/migrate/20190328085157_create_deploy_pins.rb')
  end

  test 'replaces the existing migration with --force' do
    write 'db/migrate/20190328085157_create_deploy_pins.rb', 'old'

    run_generator DeployPin::Generators::Install, ['--force']

    migrations = generated(MIGRATION)
    assert_equal 1, migrations.size
    refute_equal 'db/migrate/20190328085157_create_deploy_pins.rb', migrations.first
    assert_match 'create_table :deploy_pins', read(migrations.first)
  end

  test 'revoke removes the configuration and the migration' do
    run_generator DeployPin::Generators::Install
    run_generator DeployPin::Generators::Install, [], behavior: :revoke

    assert_empty generated('**/*.rb')
  end

  test 'writes no file when ActiveRecord is not installed' do
    missing = ->(*) { raise LoadError, 'cannot load such file -- active_record/version' }
    generator = build_generator(DeployPin::Generators::Install)

    capture_io do
      generator.stub(:require, missing) do
        assert_raises(Thor::Error) { generator.invoke_all }
      end
    end

    assert_empty generated('**/*')
  end

  test 'fails with a hint when ActiveRecord is not installed' do
    generator = build_generator(DeployPin::Generators::Install)
    missing = ->(*) { raise LoadError, 'cannot load such file -- active_record/version' }

    generator.stub(:require, missing) do
      error = assert_raises(Thor::Error) { generator.send(:activerecord_migration_class) }

      assert_match 'ActiveRecord storage needs the activerecord gem', error.message
    end
  end
end
