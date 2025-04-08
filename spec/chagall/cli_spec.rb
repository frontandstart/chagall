# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Chagall::CLI do
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

  describe 'compose commands' do
    before do
      allow(Chagall::Settings).to receive(:configure)
      allow_any_instance_of(described_class).to receive(:transform_options_to_args).and_return([])
    end
    
    %w[run exec down logs ls ps up].each do |cmd|
      it "correctly passes #{cmd} command to Compose::Main" do
        expect(Chagall::Compose::Main).to receive(:new).with(cmd.to_sym, ['web', 'arg1', 'arg2'])
        
        cli.send(cmd, 'web', 'arg1', 'arg2')
      end
    end
  end
end 