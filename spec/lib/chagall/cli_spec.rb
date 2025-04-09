# frozen_string_literal: true

require 'spec_helper'
require 'chagall/cli'
require 'chagall/compose/main'

RSpec.describe Chagall::Cli do
  describe 'compose subcommand' do
    let(:compose_main) { instance_double(Chagall::Compose::Main) }
    let(:compose_subcommand) { Chagall::Cli.subcommand_classes['compose'] }

    before do
      allow(Chagall::Settings).to receive(:configure)
      allow(Chagall::Compose::Main).to receive(:new).and_return(compose_main)
      # Prevent exit in tests
      allow(compose_subcommand).to receive(:exit)
      allow(compose_subcommand).to receive(:puts)
    end

    context 'when running a simple command' do
      it 'passes the arguments correctly' do
        expect(Chagall::Compose::Main).to receive(:new).with('up', '-d')

        compose_subcommand.run('chagall', [ 'up', '-d' ])
      end
    end

    context 'when running a command with service and options' do
      it 'passes the arguments correctly' do
        expect(Chagall::Compose::Main).to receive(:new).with('logs', 'app', '--tail', '100', '-f')

        compose_subcommand.run('chagall', [ 'logs', 'app', '--tail', '100', '-f' ])
      end
    end

    context 'when running a command with just service' do
      it 'passes the arguments correctly' do
        expect(Chagall::Compose::Main).to receive(:new).with('restart', 'app')

        compose_subcommand.run('chagall', %w[restart app])
      end
    end

    context 'when running a command with top-level option and compose options' do
      it 'correctly parses top-level options and passes compose args' do
        # Create a new instance of Cli to check top-level options parsing
        cli = instance_double(Chagall::Cli)
        allow(Chagall::Cli).to receive(:new).and_return(cli)
        allow(cli).to receive(:parse)

        # For the actual subcommand execution
        subcommand_instance = instance_double(compose_subcommand)
        allow(compose_subcommand).to receive(:new).and_return(subcommand_instance)
        allow(subcommand_instance).to receive(:parse)
        allow(subcommand_instance).to receive(:collect_options_hash).and_return({ server: 'prod-server' })
        allow(subcommand_instance).to receive(:execute)

        expect(cli).to receive(:parse).with([ '--server', 'prod-server' ])
        expect(subcommand_instance).to receive(:execute).with('logs', [ 'app', '--tail', '100' ])

        compose_subcommand.run('chagall', [ '--server', 'prod-server', 'logs', 'app', '--tail', '100' ])
      end
    end

    context 'when no compose arguments are provided' do
      it 'shows help and exits' do
        expect(compose_subcommand).to receive(:puts)
        expect(compose_subcommand).to receive(:exit).with(0)

        compose_subcommand.run('chagall', [])
      end
    end
  end
end
