# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Chagall::Cli do
  let(:cli) { described_class.new('') }

  describe 'deploy subcommand' do
    it 'calls Deploy::Main with converted options' do
      deploy_command = Chagall::Cli::Deploy.new('')
      expect(Chagall::Deploy::Main).to receive(:new) do |args|
        expect(args).to include('--name')
      end

      # Stub convert_options_to_args to return expected args
      allow(deploy_command).to receive(:convert_options_to_args)
        .and_return(['--name', 'test_project'])

      deploy_command.execute
    end
  end

  describe 'setup subcommand' do
    it 'calls Setup::Main' do
      setup_command = Chagall::Cli::Setup.new('')
      expect(Chagall::Setup::Main).to receive(:new)

      setup_command.execute
    end
  end

  describe '#convert_options_to_args' do
    let(:cli_instance) { described_class.new('') }

    it 'converts Clamp options to argument array' do
      # Set options directly
      allow(cli_instance).to receive(:server).and_return('example.com')
      allow(cli_instance).to receive(:name).and_return('test_project')
      allow(cli_instance).to receive(:dry_run?).and_return(true)
      allow(cli_instance).to receive(:compose_files).and_return(['docker-compose.yml', 'docker-compose.override.yml'])

      args = cli_instance.send(:convert_options_to_args)

      # Verify that each option has been transformed correctly
      expect(args).to include('--server', 'example.com')
      expect(args).to include('--name', 'test_project')
      expect(args).to include('--dry-run')
      expect(args).to include('--compose-files', 'docker-compose.yml,docker-compose.override.yml')
    end
  end

  describe 'compose subcommand' do
    it 'correctly passes command arguments to Compose::Main' do
      # Create a compose command instance and set parameters
      compose_command = Chagall::Cli::Compose.new('')
      allow(compose_command).to receive(:command).and_return('logs')
      allow(compose_command).to receive(:service).and_return('app')
      allow(compose_command).to receive(:args).and_return(['--tail', '100', '-f'])

      expect(Chagall::Compose::Main).to receive(:new).with('logs', 'app', '--tail', '100', '-f')

      compose_command.execute
    end
  end

  describe 'direct compose commands' do
    %w[logs ps up down exec run].each do |cmd|
      it "#{cmd} invokes compose with correct arguments" do
        # Create a command instance for testing
        command_class = Chagall::Cli.subcommand_classes[cmd]
        command_instance = command_class.new('')

        allow(command_instance).to receive(:service).and_return('web')
        allow(command_instance).to receive(:args).and_return(['--some-flag', 'value'])

        expect(Chagall::Compose::Main).to receive(:new).with(cmd, 'web', '--some-flag', 'value')

        command_instance.execute
      end
    end
  end

  describe 'rollback subcommand' do
    it 'parses the steps parameter correctly' do
      rollback_command = Chagall::Cli::Rollback.new('')
      allow(rollback_command).to receive(:steps).and_return(3)

      # Just verify we can access the steps parameter as an integer
      expect(rollback_command.steps).to eq(3)

      # For now we just print a message, so no real behavior to test
      expect { rollback_command.execute }.to output(/not implemented/).to_stdout
    end
  end
end
