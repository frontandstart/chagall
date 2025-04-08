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

  describe 'OPTIONS definition' do
    it 'ensures all options have both env_name and environment_variable' do
      Chagall::Settings::OPTIONS.each do |option|
        if option[:environment_variable]
          expect(option[:env_name]).to eq(option[:environment_variable])
        elsif option[:env_name]
          expect(option[:environment_variable]).to eq(option[:env_name])
        end
      end
    end

    it 'defines procs for options that need special handling' do
      # Find options that have proc defined
      compose_files_option = Chagall::Settings::OPTIONS.find { |o| o[:key] == :compose_files }
      keep_releases_option = Chagall::Settings::OPTIONS.find { |o| o[:key] == :keep_releases }

      # Test compose_files proc (splits comma-separated string)
      expect(compose_files_option[:proc].call('file1.yml,file2.yml')).to eq(['file1.yml', 'file2.yml'])

      # Test keep_releases proc (converts to integer)
      expect(keep_releases_option[:proc].call('5')).to eq(5)
    end
  end

  describe '#configure_with_hash' do
    let(:options) { { server: 'user@server', name: 'myproject', compose_files: ['compose.prod.yaml'] } }
    subject(:settings) { Chagall::Settings.configure_with_hash(options) }

    it 'configures settings with hash options' do
      expect(settings.options[:server]).to eq('user@server')
      expect(settings.options[:name]).to eq('myproject')
      expect(settings.options[:compose_files]).to eq(['compose.prod.yaml'])
    end

    it 'loads defaults for missing options' do
      # Options comes from DEFAULTS
      expect(settings.options[:target]).to eq('production')
    end

    context 'with config file' do
      before do
        # Mock config file loading
        allow_any_instance_of(Chagall::Settings).to receive(:config_file).and_return({
                                                                                       target: 'development',
                                                                                       platform: 'linux/arm64'
                                                                                     })
      end

      it 'overrides config file with provided options' do
        options_with_override = options.merge(target: 'custom')
        settings = Chagall::Settings.configure_with_hash(options_with_override)

        # Our option overrides config file
        expect(settings.options[:target]).to eq('custom')
        # Config file value is used when not in options
        expect(settings.options[:platform]).to eq('linux/arm64')
      end
    end
  end

  describe '#configure' do
    let(:argv) { ['-s', 'user@server', '-n', 'myproject', '-c', 'compose.prod.yaml'] }
    subject(:settings) { Chagall::Settings.configure(argv) }

    it 'loads defaults and config file' do
      # Stub the config file loading
      allow_any_instance_of(Chagall::Settings).to receive(:config_file).and_return({
                                                                                     target: 'development'
                                                                                   })

      # This method is obsolete but should still work
      settings = Chagall::Settings.configure([])

      expect(settings.options[:target]).to eq('development')
      expect(settings.options[:platform]).to eq('linux/x86_64') # default
    end
  end

  describe 'validation' do
    it 'validates required options and reports missing ones' do
      # Make server required and missing
      allow_any_instance_of(Chagall::Settings).to receive(:config_file).and_return({})

      expect do
        Chagall::Settings.configure_with_hash({})
      end.to raise_error(Chagall::SettingsError, /Missing required options/)
    end

    it 'skips validation in dry run mode' do
      expect do
        Chagall::Settings.configure_with_hash({ dry_run: true })
      end.not_to raise_error
    end

    it 'validates compose files exist' do
      # Make file existence check fail
      allow(File).to receive(:exist?).and_return(false)

      expect do
        Chagall::Settings.configure_with_hash({
                                                server: 'user@server',
                                                compose_files: ['nonexistent.yml']
                                              })
      end.to raise_error(Chagall::SettingsError, /Missing compose file/)
    end
  end

  describe 'utility methods' do
    let(:options) do
      { server: 'user@server', name: 'myproject', release: 'abc123', compose_files: ['compose.prod.yaml'] }
    end
    before { Chagall::Settings.configure_with_hash(options) }

    it 'generates image_tag correctly' do
      expect(Chagall::Settings.instance.image_tag).to eq('myproject:abc123')
    end

    it 'generates project_folder_path correctly' do
      expect(Chagall::Settings.instance.project_folder_path).to eq('~/projects/myproject')
    end
  end

  describe 'dot notation access' do
    let(:options) { { server: 'user@server', name: 'myproject', compose_files: ['compose.prod.yaml'] } }
    before { Chagall::Settings.configure_with_hash(options) }

    it 'allows access via hash notation' do
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
