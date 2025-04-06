# frozen_string_literal: true

require 'rspec'
require_relative '../../lib/chagall/settings'

RSpec.describe Chagall::Settings do
  before do
    # Reset the singleton instance for testing
    Chagall::Settings.__send__(:instance_variable_set, :@instance, nil)
    # Stub File.exist? to always return true to bypass compose file validation
    allow(File).to receive(:exist?).and_return(true)
  end

  describe '#configure' do
    let(:argv) { ['-s', 'user@server', '-n', 'myproject', '-c', 'compose.prod.yaml'] }
    subject(:settings) { Chagall::Settings.configure(argv) }

    it 'parses required options correctly' do
      expect(settings.options[:server]).to eq('user@server')
      expect(settings.options[:name]).to eq('myproject')
      expect(settings.options[:compose_files]).to eq(['compose.prod.yaml'])
    end
  end

  describe 'dot notation access' do
    let(:argv) { ['-s', 'user@server', '-n', 'myproject', '-c', 'compose.prod.yaml'] }
    before { Chagall::Settings.configure(argv) }

    it 'allows direct access to options via dot notation on instance' do
      instance = Chagall::Settings.instance
      expect(instance.options.server).to eq('user@server')
      expect(instance.options.name).to eq('myproject')
      expect(instance.options.compose_files).to eq(['compose.prod.yaml'])
    end

    it 'allows direct access to options via dot notation on class' do
      expect(Chagall::Settings.server).to eq('user@server')
      expect(Chagall::Settings.name).to eq('myproject')
      expect(Chagall::Settings.compose_files).to eq(['compose.prod.yaml'])
    end

    it 'maintains backward compatibility with hash notation' do
      expect(Chagall::Settings[:server]).to eq('user@server')
      expect(Chagall::Settings[:name]).to eq('myproject')
      expect(Chagall::Settings[:compose_files]).to eq(['compose.prod.yaml'])
    end
  end

  describe 'custom methods using dot notation' do
    let(:argv) { ['-s', 'user@server', '-n', 'myproject', '-c', 'compose.prod.yaml'] }
    before { Chagall::Settings.configure(argv) }

    it 'uses dot notation in image_tag method' do
      expect(Chagall::Settings.instance.image_tag).to eq("myproject:#{`git rev-parse --short HEAD`.strip}")
    end

    it 'uses dot notation in project_folder_path method' do
      expect(Chagall::Settings.instance.project_folder_path).to eq("#{Chagall::Settings::CHAGALL_PROJECTS_FOLDER}/myproject")
    end
  end
end
