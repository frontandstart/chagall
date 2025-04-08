# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Chagall::Cli do
  let(:cli) { described_class.new }

  describe '#deploy' do
    it 'configures settings and calls Deploy::Main' do
      expect(Chagall::Settings).to receive(:configure).with(anything)
      expect(Chagall::Deploy::Main).to receive(:new).with([])

      # Stub transform_options_to_args to return an empty array
      allow_any_instance_of(described_class).to receive(:transform_options_to_args).and_return([])

      cli.deploy
    end
  end

  describe '#setup' do
    it 'configures settings and calls Setup::Main' do
      expect(Chagall::Settings).to receive(:configure).with(anything)
      expect(Chagall::Setup::Main).to receive(:new)

      # Stub transform_options_to_args to return an empty array
      allow_any_instance_of(described_class).to receive(:transform_options_to_args).and_return([])

      cli.setup
    end
  end

  describe '#transform_options_to_args' do
    it 'transforms Thor options to argument array' do
      options = {
        server: 'example.com',
        name: 'test_project',
        dry_run: true,
        compose_files: ['docker-compose.yml', 'docker-compose.override.yml']
      }

      # Manually initialize for testing private method
      cli = described_class.new
      args = cli.send(:transform_options_to_args, options)

      # Verify that each option has been transformed correctly
      expect(args).to include('--server', 'example.com')
      expect(args).to include('--name', 'test_project')
      expect(args).to include('--dry-run')
      expect(args).to include('--compose-files', 'docker-compose.yml,docker-compose.override.yml')
    end
  end

  describe '#compose' do
    before do
      allow(Chagall::Settings).to receive(:configure)
      allow_any_instance_of(described_class).to receive(:transform_options_to_args).and_return([])
    end

    it 'correctly passes command arguments to Compose::Main' do
      expect(Chagall::Compose::Main).to receive(:new).with(:logs, ['app', '--tail', '100', '-f'])

      cli.compose('logs', 'app', '--tail', '100', '-f')
    end

    it 'passes complex arguments to Compose::Main without modification' do
      expect(Chagall::Compose::Main).to receive(:new).with(:exec, ['web', 'rails', 'c', '--', '-e', 'puts 1+1'])

      cli.compose('exec', 'web', 'rails', 'c', '--', '-e', 'puts 1+1')
    end
  end

  describe 'direct compose commands' do
    before do
      allow(Chagall::Settings).to receive(:configure)
      allow_any_instance_of(described_class).to receive(:transform_options_to_args).and_return([])
    end

    %w[logs ps up down exec run].each do |cmd|
      it "#{cmd} invokes compose with correct arguments" do
        expect(cli).to receive(:invoke).with(:compose, [cmd, 'web', '--some-flag', 'value'])

        cli.send(cmd, 'web', '--some-flag', 'value')
      end
    end
  end
end
