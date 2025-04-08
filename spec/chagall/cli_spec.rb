# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Chagall::Cli do
  let(:cli) { described_class.new('') }

  # Mock a simple option definition for testing
  let(:mock_option) do
    {
      key: :test_option,
      flags: ['--test-option'],
      type: :string,
      description: 'Test option',
      environment_variable: 'TEST_OPTION'
    }
  end

  describe 'option declarations' do
    it 'correctly processes options without a proc' do
      expect(Chagall::Settings::OPTIONS).to receive(:each).and_yield(mock_option)

      # Verify the option is declared correctly
      expect_any_instance_of(Clamp::Command).to receive(:option).with(
        ['--test-option'], :string, 'Test option',
        hash_including(environment_variable: 'TEST_OPTION')
      )

      # Force option declarations to run
      described_class.new('')
    end

    it 'correctly processes options with a proc' do
      option_with_proc = mock_option.merge(proc: ->(val) { val.upcase })

      expect(Chagall::Settings::OPTIONS).to receive(:each).and_yield(option_with_proc)

      # Verify that option with block is declared
      expect_any_instance_of(Clamp::Command).to receive(:option).with(
        anything, anything, anything, hash_including(environment_variable: 'TEST_OPTION')
      ) do |*args, &block|
        # Verify the block processes the value correctly
        expect(block.call('test')).to eq('TEST')
      end

      # Force option declarations to run
      described_class.new('')
    end
  end

  describe 'deploy subcommand' do
    it 'calls Deploy::Main with options from Settings' do
      deploy_command = Chagall::Cli::Deploy.new('')

      # Expect Settings to be configured with the collected options
      expect(Chagall::Settings).to receive(:configure_with_hash).with(kind_of(Hash))
      expect(Chagall::Deploy::Main).to receive(:new)

      # Stub collect_options_hash to return options
      allow(deploy_command).to receive(:collect_options_hash)
        .and_return({ name: 'test_project' })

      deploy_command.execute
    end
  end

  describe 'setup subcommand' do
    it 'calls Setup::Main with options from Settings' do
      setup_command = Chagall::Cli::Setup.new('')

      # Expect Settings to be configured with the collected options
      expect(Chagall::Settings).to receive(:configure_with_hash).with(kind_of(Hash))
      expect(Chagall::Setup::Main).to receive(:new)

      # Stub collect_options_hash to return options
      allow(setup_command).to receive(:collect_options_hash).and_return({})

      setup_command.execute
    end
  end

  describe '#collect_options_hash' do
    let(:cli_instance) { described_class.new('') }

    it 'collects options from the command' do
      # Mock recognized options
      mock_options = [
        double('Option', attribute_name: 'server', is_a?: false),
        double('Option', attribute_name: 'name', is_a?: false),
        double('Option', attribute_name: 'dry_run', is_a?: true),
        double('Option', attribute_name: 'compose_files', is_a?: false)
      ]

      allow(cli_instance.class).to receive(:recognised_options).and_return(mock_options)

      # Set options directly
      allow(cli_instance).to receive(:server).and_return('example.com')
      allow(cli_instance).to receive(:name).and_return('test_project')
      allow(cli_instance).to receive(:dry_run?).and_return(true)
      allow(cli_instance).to receive(:compose_files).and_return(['docker-compose.yml', 'docker-compose.override.yml'])

      options = cli_instance.send(:collect_options_hash)

      # Verify that each option has been collected correctly
      expect(options[:server]).to eq('example.com')
      expect(options[:name]).to eq('test_project')
      expect(options[:dry_run]).to eq(true)
      expect(options[:compose_files]).to eq(['docker-compose.yml', 'docker-compose.override.yml'])
    end

    it 'correctly maps option keys for compatibility' do
      allow(cli_instance.class).to receive(:recognised_options).and_return([
                                                                             double('Option',
                                                                                    attribute_name: 'skip_uncommit', is_a?: true),
                                                                             double('Option', attribute_name: 'file',
                                                                                              is_a?: false),
                                                                             double('Option',
                                                                                    attribute_name: 'projects_folder', is_a?: false)
                                                                           ])

      allow(cli_instance).to receive(:skip_uncommit?).and_return(true)
      allow(cli_instance).to receive(:file).and_return('custom.Dockerfile')
      allow(cli_instance).to receive(:projects_folder).and_return('/opt/projects')

      options = cli_instance.send(:collect_options_hash)

      expect(options[:skip_uncommit_check]).to eq(true)
      expect(options[:dockerfile]).to eq('custom.Dockerfile')
      expect(options[:projects_folder]).to eq('/opt/projects')
    end
  end

  describe 'compose subcommand' do
    it 'correctly passes command arguments to Compose::Main' do
      # Create a compose command instance and set parameters
      compose_command = Chagall::Cli::Compose.new('')

      allow(compose_command).to receive(:command).and_return('logs')
      allow(compose_command).to receive(:service).and_return('app')
      allow(compose_command).to receive(:args).and_return(['--tail', '100', '-f'])
      allow(compose_command).to receive(:collect_options_hash).and_return({})

      expect(Chagall::Settings).to receive(:configure_with_hash).with(kind_of(Hash))
      expect(Chagall::Compose::Main).to receive(:new).with('logs', 'app', '--tail', '100', '-f')

      compose_command.execute
    end
  end

  describe 'rollback subcommand' do
    it 'passes steps parameter to options hash' do
      rollback_command = Chagall::Cli::Rollback.new('')

      allow(rollback_command).to receive(:steps).and_return(3)
      allow(rollback_command).to receive(:collect_options_hash).and_return({})

      expect(Chagall::Settings).to receive(:configure_with_hash) do |options|
        expect(options[:steps]).to eq(3)
      end

      expect { rollback_command.execute }.to output(/not implemented/).to_stdout
    end
  end

  describe 'option parsing from environment variables' do
    it 'reads options from environment variables' do
      # Skip actual Clamp initialization to avoid actual option parsing
      allow_any_instance_of(Clamp::Command).to receive(:initialize)

      # Test with a mocked environment variable
      ClimateControl.modify CHAGALL_SERVER: 'env-server.example.com' do
        # Stub the option parser to set a value from env
        expect_any_instance_of(Clamp::Command).to receive(:option)
          .with(anything, anything, anything, hash_including(environment_variable: 'CHAGALL_SERVER'))
          .at_least(:once)

        # Force option creation to happen
        described_class.new('')
      end
    end
  end
end
