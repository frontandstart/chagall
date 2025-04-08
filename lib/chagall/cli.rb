# frozen_string_literal: true

require 'thor'
require_relative 'settings'
require_relative 'deploy/main'
require_relative 'compose/main'

module Chagall
  class Cli < Thor
    class_option :server, type: :string, aliases: '-s', desc: 'Server to deploy to', required: false, banner: 'SERVER'
    class_option :name, type: :string, aliases: '-n', desc: 'Project name', default: Pathname.new(Dir.pwd).basename.to_s
    class_option :release, type: :string, desc: 'Release tag', default: `git rev-parse --short HEAD`.strip
    class_option :dry_run, type: :boolean, aliases: '-d', desc: 'Dry run', default: false
    class_option :remote, type: :boolean, aliases: '-r', desc: 'Deploy remotely (build on remote server)',
                          default: false
    class_option :compose_files, type: :array, aliases: '-c', desc: 'Comma separated list of compose files'
    class_option :debug, type: :boolean, desc: 'Debug mode with pry attaching', default: false
    class_option :skip_uncommit_check, type: :boolean, desc: 'Skip uncommitted changes check', default: false

    desc 'deploy', 'Deploy the application to the server'
    def deploy
      # Configure settings from Thor options
      configure_settings(options)

      # Instantiate and run deploy
      Chagall::Deploy::Main.new([])
    end

    desc 'setup', 'Setup the server for deployment'
    def setup
      # Configure settings from Thor options
      configure_settings(options)

      Chagall::Setup::Main.new
    end

    desc 'compose', 'Run Docker Compose commands'
    def compose(cmd_name, *args)
      # Configure settings from Thor options
      configure_settings(options)

      Chagall::Compose::Main.new(cmd_name.to_sym, [service_name, *args])
    end

    private

    def configure_settings(thor_options)
      # Convert Thor options to the format expected by Settings
      config_options = thor_options.transform_keys(&:to_sym)

      # Fill in Settings options from Thor options
      Chagall::Settings.configure(transform_options_to_args(config_options))
    end

    def transform_options_to_args(options)
      args = []

      options.each do |key, value|
        next if value.nil?

        option_def = Chagall::Settings::OPTIONS.find { |opt| opt[:key] == key }
        next unless option_def

        flag = option_def[:flags].first

        case option_def[:type]
        when :boolean
          args << flag if value
        when :array
          args << flag << value.join(',')
        else
          args << flag << value.to_s
        end
      end

      args
    end
  end
end
