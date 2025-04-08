# frozen_string_literal: true

require 'yaml'
require 'singleton'

module Chagall
  class Settings
    include Singleton

    CHAGALL_PROJECTS_FOLDER = '~/projects'
    TMP_CACHE_FOLDER = 'tmp'

    OPTIONS = [
      {
        key: :debug,
        flags: ['--debug'],
        description: 'Debug mode with pry attaching',
        type: :boolean,
        default: false,
        environment_variable: 'CHAGALL_DEBUG'
      },
      {
        key: :skip_uncommit,
        flags: ['--skip-uncommit'],
        description: 'Skip uncommitted changes check',
        type: :boolean,
        default: false,
        environment_variable: 'CHAGALL_SKIP_UNCOMMIT'
      },
      {
        key: :server,
        flags: ['-s', '--server'],
        description: 'Server to deploy to',
        type: :string,
        required: true,
        environment_variable: 'CHAGALL_SERVER'
      },
      {
        key: :name,
        flags: ['-n', '--name'],
        description: 'Project name',
        type: :string,
        default: Pathname.new(Dir.pwd).basename.to_s,
        environment_variable: 'CHAGALL_NAME'
      },
      {
        key: :release,
        flags: ['--release'],
        description: 'Release tag',
        required: true,
        default: `git rev-parse --short HEAD`.strip,
        type: :string,
        environment_variable: 'CHAGALL_RELEASE'
      },
      {
        key: :dry_run,
        type: :boolean,
        default: false,
        flags: ['-d', '--dry-run'],
        environment_variable: 'CHAGALL_DRY_RUN',
        description: 'Dry run'
      },
      {
        key: :remote,
        flags: ['-r', '--remote'],
        description: 'Deploy remotely (build on remote server)',
        type: :boolean,
        default: false,
        environment_variable: 'CHAGALL_REMOTE'
      },
      {
        key: :compose_files,
        flags: ['-c', '--compose-files'],
        description: 'Comma separated list of compose files',
        type: :array,
        required: true,
        environment_variable: 'CHAGALL_COMPOSE_FILES',
        proc: ->(value) { value.split(',') }
      },
      {
        key: :target,
        type: :string,
        default: 'production',
        flags: ['--target'],
        environment_variable: 'CHAGALL_TARGET',
        description: 'Target'
      },
      {
        key: :dockerfile,
        type: :string,
        flags: ['-f', '--file'],
        default: 'Dockerfile',
        environment_variable: 'CHAGALL_DOCKERFILE',
        description: 'Dockerfile'
      },
      {
        key: :projects_folder,
        type: :string,
        default: CHAGALL_PROJECTS_FOLDER,
        flags: ['-p', '--projects-folder'],
        environment_variable: 'CHAGALL_PROJECTS_FOLDER',
        description: 'Projects folder'
      },
      {
        key: :cache_from,
        type: :string,
        default: "#{TMP_CACHE_FOLDER}/.buildx-cache",
        flags: ['--cache-from'],
        environment_variable: 'CHAGALL_CACHE_FROM',
        description: 'Cache from'
      },
      {
        key: :cache_to,
        type: :string,
        default: "#{TMP_CACHE_FOLDER}/.buildx-cache-new",
        flags: ['--cache-to'],
        environment_variable: 'CHAGALL_CACHE_TO',
        description: 'Cache to'
      },
      {
        key: :keep_releases,
        type: :integer,
        default: 3,
        flags: ['-k', '--keep-releases'],
        environment_variable: 'CHAGALL_KEEP_RELEASES',
        description: 'Keep releases',
        proc: ->(value) { Integer(value) }
      },
      {
        key: :ssh_args,
        type: :string,
        default: '-o StrictHostKeyChecking=no',
        environment_variable: 'CHAGALL_SSH_ARGS',
        flags: ['--ssh-args'],
        description: 'SSH arguments'
      },
      {
        key: :docker_context,
        type: :string,
        flags: ['--docker-context'],
        environment_variable: 'CHAGALL_DOCKER_CONTEXT',
        default: '.',
        description: 'Docker context'
      },
      {
        key: :platform,
        type: :string,
        flags: ['--platform'],
        environment_variable: 'CHAGALL_PLATFORM',
        default: 'linux/x86_64',
        description: 'Platform'
      }
    ].freeze

    attr_accessor :options, :missing_options, :missing_compose_files

    class << self
      def configure(argv)
        instance.configure(argv)
      end

      def [](key)
        instance.options[key]
      end
    end

    def configure(parsed_options)
      @options = {}
      @missing_options = []
      @missing_compose_files = []

      @options.merge!(options_from_config_file)
      @options.merge!(parsed_options)

      validate_options
      self
    end

    def validate_options
      error_message_string = "\n"

      OPTIONS.each do |option|
        @missing_options << option if option[:required] && @options[option[:key]].to_s.empty?
      end

      if @missing_options.any?
        error_message_string += "  Missing required options: #{@missing_options.map { |o| o[:key] }.join(', ')}\n"
        error_message_string += "    These can be set via:\n"
        error_message_string += "      - CLI arguments (#{@missing_options.map { |o| o[:flags] }.join(', ')})\n"
        error_message_string += "      - Environment variables (#{@missing_options.map do |o|
          o[:environment_variable] || o[:env_name]
        end.join(', ')})\n"
        error_message_string += "      - chagall.yml file\n"
      end

      if @options[:compose_files]
        @options[:compose_files].each do |file|
          unless File.exist?(file)
            @missing_compose_files << file
            error_message_string += "  Missing compose file: #{file}\n"
          end
        end
      end

      return unless @missing_options.any? || @missing_compose_files.any?

      raise Chagall::SettingsError, error_message_string unless @options[:dry_run]
    end

    def options_from_config_file
      @options_from_config_file ||= begin
        config_path = File.join(Dir.pwd, 'chagall.yml') || File.join(Dir.pwd, 'chagall.yaml')
        return {} unless File.exist?(config_path)

        config = YAML.load_file(config_path)
        config.transform_keys(&:to_sym)
      rescue StandardError => e
        puts "Warning: Error loading chagall.yml: #{e.message}"
        {}
      end
    end

    def true?(value)
      value.to_s.strip.downcase == 'true'
    end

    def image_tag
      @image_tag ||= "#{options[:name]}:#{options[:release]}"
    end

    def project_folder_path
      @project_folder_path ||= "#{options[:projects_folder]}/#{options[:name]}"
    end
  end
end
