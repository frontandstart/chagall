# frozen_string_literal: true

require 'spec_helper'
require 'chagall/compose/main'
require 'chagall/settings'

RSpec.describe Chagall::Compose::Main do
  let(:settings) { instance_double(Chagall::Settings, project_folder_path: '/app') }
  let(:ssh) { instance_double('SSH') }

  before do
    allow(Chagall::Settings).to receive(:instance).and_return(settings)
    allow(Chagall::Settings).to receive(:[]).with(:compose_files).and_return(compose_files)
    allow_any_instance_of(described_class).to receive(:ssh).and_return(ssh)
    allow(ssh).to receive(:execute)
  end

  let(:compose_files) { [ 'compose.yaml', 'compose.prod.yaml' ] }

  describe '#initialize' do
    context 'when command is missing' do
      it 'raises an error' do
        expect { described_class.new('', 'app') }.to raise_error(Chagall::Error)
        expect { described_class.new(nil, 'app') }.to raise_error(Chagall::Error)
      end
    end

    context 'when service name is missing' do
      it 'does not raise an error' do
        expect { described_class.new('up', nil) }.not_to raise_error
        expect { described_class.new('up', '') }.not_to raise_error
      end
    end
  end

  describe '#run_command' do
    context 'with command and service' do
      it 'executes the correct command' do
        expect(ssh).to receive(:execute).with(
          'cd /app && docker compose -f compose.yaml -f compose.prod.yaml logs app',
          tty: true
        )

        described_class.new('logs', 'app')
      end
    end

    context 'with command, service, and arguments' do
      it 'executes the correct command with arguments' do
        expect(ssh).to receive(:execute).with(
          'cd /app && docker compose -f compose.yaml -f compose.prod.yaml logs app --tail 100 -f',
          tty: true
        )

        described_class.new('logs', 'app', '--tail', '100', '-f')
      end
    end

    context 'with command only (no service)' do
      it 'executes the correct command without a service' do
        expect(ssh).to receive(:execute).with(
          'cd /app && docker compose -f compose.yaml -f compose.prod.yaml up -d',
          tty: true
        )

        described_class.new('up', nil, '-d')
      end
    end

    context 'with arguments containing option flags' do
      it 'preserves all arguments exactly as they were passed' do
        expect(ssh).to receive(:execute).with(
          'cd /app && docker compose -f compose.yaml -f compose.prod.yaml exec app sh -c "echo hello"',
          tty: true
        )

        described_class.new('exec', 'app', 'sh', '-c', 'echo hello')
      end
    end
  end
end
