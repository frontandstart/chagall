# frozen_string_literal: true

require 'rspec'
require_relative '../../../chagall/lib/chagall/settings'

RSpec.describe Chagall::Deploy::Settings do
  before do
    # Reset the singleton instance for testing
    Chagall::Deploy::Settings.__send__(:instance_variable_set, :@instance, nil)
  end

  describe '#configure' do
    let(:argv) { ['-s', 'user@server', '-n', 'myproject', '-f', 'compose.prod.yaml', 'ARG1', 'ARG2'] }
    subject(:settings) { Chagall::Deploy::Settings.new.configure(argv) }

    it 'parses required options correctly' do
      expect(settings.options[:server]).to eq('user@server')
      expect(settings.options[:name]).to eq('myproject')
      expect(settings.options[:compose_files]).to eq(['compose.prod.yaml'])
    end

    it 'captures extra arguments as build_args' do
      expect(settings.options[:build_args]).to eq('ARG1 ARG2')
    end
  end

  let(:required_args) { ['--server', 'someserver', '--name', 'testproject', '--dry-run'] }

  before do
    # Reset singleton state for isolation
    settings = described_class.instance
    settings.options = {}
    settings.missing_options = []
    settings.missing_compose_files = []
    # Stub File.exist? to always return true to bypass compose file validation
    allow(File).to receive(:exist?).and_return(true)
  end

  context 'when additional docker build arguments are provided' do
    it 'collects unknown arguments into build_args' do
      args = required_args + ['--cache-from', '/tmp']
      settings = described_class.instance.configure(args.dup)
      expect(settings.options[:server]).to eq('someserver')
      expect(settings.options[:name]).to eq('testproject')
      expect(settings.options[:build_args]).to include('--cache-from /tmp')
    end
  end

  context 'when an unknown boolean flag is provided' do
    it 'includes the flag in build_args' do
      args = required_args + ['--some-flag']
      settings = described_class.instance.configure(args.dup)
      expect(settings.options[:build_args]).to include('--some-flag')
    end
  end
end
