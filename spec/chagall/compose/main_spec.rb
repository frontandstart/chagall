# frozen_string_literal: true

require 'spec_helper'

describe Chagall::Compose::Main do
  let(:settings_instance) { Chagall::Settings.instance }
  let(:ssh_instance) { instance_double(Chagall::SSH) }

  before do
    allow(settings_instance).to receive(:options).and_return({
                                                               server: 'test-server',
                                                               name: 'test-app',
                                                               projects_folder: '~/projects'
                                                             })
    allow(settings_instance).to receive(:project_folder_path).and_return('~/projects/test-app')
    allow(Chagall::Settings).to receive(:[]).with(:compose_files).and_return([ 'compose.yaml' ])
    allow(Chagall::SSH).to receive(:new).and_return(ssh_instance)
  end

  describe '#initialize' do
    it 'raises an error if service name is empty' do
      expect do
        described_class.new('logs', '')
      end.to raise_error(Chagall::Error, 'Service name is required')
    end

    it 'raises an error if command is empty' do
      expect do
        described_class.new('', 'app')
      end.to raise_error(Chagall::Error, 'Command is required')
    end
  end

  describe '#run_command' do
    before do
      allow(ssh_instance).to receive(:execute).and_return(true)
    end

    it 'ensures project folder exists before running the command' do
      expect(ssh_instance).to receive(:execute).with('test -d ~/projects/test-app').and_return(true)
      expect(ssh_instance).to receive(:execute).with(
        'cd ~/projects/test-app && docker compose -f compose.yaml logs app',
        tty: true
      ).and_return(true)

      described_class.new('logs', 'app')
    end

    it 'creates the project folder if it does not exist' do
      expect(ssh_instance).to receive(:execute).with('test -d ~/projects/test-app').and_return(false)
      expect(ssh_instance).to receive(:execute).with('mkdir -p ~/projects/test-app').and_return(true)
      expect(ssh_instance).to receive(:execute).with(
        'cd ~/projects/test-app && docker compose -f compose.yaml logs app',
        tty: true
      ).and_return(true)

      described_class.new('logs', 'app')
    end

    it 'passes additional arguments to the command' do
      expect(ssh_instance).to receive(:execute).with('test -d ~/projects/test-app').and_return(true)
      expect(ssh_instance).to receive(:execute).with(
        'cd ~/projects/test-app && docker compose -f compose.yaml logs app --tail 100 -f',
        tty: true
      ).and_return(true)

      described_class.new('logs', 'app', '--tail', '100', '-f')
    end

    it 'raises an error if the command fails' do
      expect(ssh_instance).to receive(:execute).with('test -d ~/projects/test-app').and_return(true)
      expect(ssh_instance).to receive(:execute).with(
        'cd ~/projects/test-app && docker compose -f compose.yaml logs app',
        tty: true
      ).and_return(false)

      expect do
        described_class.new('logs', 'app')
      end.to raise_error(Chagall::Error, /Command failed:/)
    end
  end
end
