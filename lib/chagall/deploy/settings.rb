require 'optparse'
require 'yaml'
require 'singleton'

module Chagall
  module Deploy
    class Settings
      include Singleton

      CHAGALL_PROJECTS_FOLDER = '~/chagall'.freeze
      TMP_CACHE_FOLDER = 'tmp'.freeze

      OPTIONS = [
        {
          key: :server,
          flags: ['-s', '--server'],
          description: 'Server to deploy to',
          type: :string,
          required: true,
          env_name: 'CHAGALL_SERVER'
        },
        {
          key: :name,
          flags: ['-n', '--name'],
          description: 'Project name',
          type: :string,
          default: Pathname.new(Dir.pwd).basename.to_s,
          env_name: 'CHAGALL_NAME'
        },
        {
          key: :release,
          flags: ['--release'],
          description: 'Release tag',
          required: true,
          default: `git rev-parse --abbrev-ref HEAD`.strip,
          type: :string,
          env_name: 'CHAGALL_RELEASE'
        },
        {
          key: :dry_run,
          type: :boolean,
          default: false,
          flags: ['-d', '--dry-run'],
          env_name: 'CHAGALL_DRY_RUN',
          desc: 'Dry run'
        },
        {
          key: :remote,
          flags: ['-r', '--remote'],
          description: 'Deploy remotely (build on remote server)',
          type: :boolean,
          default: false,
          env_name: 'CHAGALL_REMOTE'
        },
        {
          key: :compose_files,
          flags: ['-c', '--compose-files'],
          description: 'Comma separated list of compose files',
          type: :array,
          required: true,
          env_name: 'CHAGALL_COMPOSE_FILES'
        },
        {
          key: :target,
          type: :string,
          default: 'production',
          flags: ['--target'],
          env_name: 'CHAGALL_TARGET',
          desc: 'Target'
        },
        {
          key: :dockerfile,
          type: :string,
          flags: ['-f', '--file'],
          default: 'Dockerfile',
          env_name: 'CHAGALL_DOCKERFILE',
          desc: 'Dockerfile'
        },
        {
          key: :projects_folder,
          type: :string,
          default: CHAGALL_PROJECTS_FOLDER,
          flags: ['-p', '--projects-folder'],
          env_name: 'CHAGALL_PROJECTS_FOLDER',
          desc: 'Projects folder'
        },
        {
          key: :cache_from,
          type: :string,
          default: "type=local,src=#{TMP_CACHE_FOLDER}/.buildx-cache",
          flags: ['--cache-from'],
          env_name: 'CHAGALL_CACHE_FROM',
          desc: 'Cache from'
        },
        {
          key: :cache_to,
          type: :string,
          default: "type=local,dest=#{TMP_CACHE_FOLDER}/.buildx-cache-new,mode=max",
          flags: ['--cache-to'],
          env_name: 'CHAGALL_CACHE_TO',
          desc: 'Cache to'
        },
        {
          key: :keep_releases,
          type: :integer,
          default: 3,
          flags: ['-k', '--keep-releases'],
          env_name: 'CHAGALL_KEEP_RELEASES',
          desc: 'Keep releases'
        }
      ].freeze

      attr_accessor :options, :missing_options, :missing_compose_files, :argv

      class << self
        def configure(argv)
          instance.configure(argv)
        end

        def options
          instance.options
        end

        def [](key)
          instance.options[key]
        end
      end

      def configure(argv)
        @argv = argv
        @options = {}
        @missing_options = []
        @missing_compose_files = []
        @argv = argv
        setup
        self
      end

      def setup
        load_defaults_config_and_environment_variables
        parse_arguments
        validate_options
      end

      def load_defaults_config_and_environment_variables
        OPTIONS.each do |option|
          @options[option[:key]] = option[:default] if option.key?(:default)

          if (config = config_file) && config[option[:key]]
            @options[option[:key]] = config[option[:key]]
          end

          override_option_from_environment_variable(option)
        end
      end

      def parse_arguments
        parser = OptionParser.new do |opts|
          opts.banner = 'Usage: chagall deploy [options] [-- <docker build extra args>]'
          OPTIONS.each do |option|
            flags     = option[:flags]
            desc      = option[:description]
            case option[:type]
            when :boolean
              opts.on(*flags, desc) do |value|
                @options[option[:key]] = value
              end
            when :array
              opts.on(*flags, Array, desc) do |value|
                @options[option[:key]] = value
              end
            else
              opts.on(*flags, option[:type], desc) do |value|
                @options[option[:key]] = value
              end
            end
          end
        end

        # This removes 'known' flags from @argv and leaves the remaining arguments
        remaining_args = parser.order!(@argv)
        @options[:docker_build_args] = remaining_args
      rescue OptionParser::InvalidOption => e
        # Handle unknown options (or forward them as docker args)
        @options[:docker_build_args] ||= []
        @options[:docker_build_args] << e.args.join(' ')
        retry
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
            o[:env_name]
          end.join(', ')})\n"
          error_message_string += "      - chagall.yml file\n"
        end

        @options[:compose_files].each do |file|
          unless File.exist?(file)
            @missing_compose_files << file
            error_message_string += "  Missing compose file: #{file}\n"
          end
        end

        return unless @missing_options.any? || @missing_compose_files.any?

        raise Chagall::SettingsError, error_message_string unless @options[:dry_run]
      end

      def override_option_from_environment_variable(option)
        env_name = option[:env_name]
        return if env_name.nil? || ENV[env_name].nil?

        value = case option[:type]
                when :array then ENV[env_name].split(',')
                when :boolean then true?(ENV[env_name])
                else ENV[env_name]
                end
        @options[option[:key]] = value
      end

      def config_file
        @config_file ||= begin
          config_path = File.join(Dir.pwd, 'chagall.yml')
          return unless File.exist?(config_path)

          require 'yaml'
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
        @image_tag ||= "#{options[:name]}:#{options[:tag]}"
      end

      def project_folder_path
        @project_folder_path ||= "#{options[:projects_folder]}/#{options[:name]}"
      end

      def docker_image_label
        @docker_image_label ||= "#{options[:name]}:#{options[:tag]}"
      end

      def cache_from
        @cache_from ||= "type=local,src=#{options[:cache_path]}/.buildx-cache"
      end

      def cache_to
        @cache_to ||= "type=local,dest=#{options[:cache_path]}/.buildx-cache-new,mode=max"
      end

      def tag
        "#{options[:name]}:#{options[:release]}"
      end
    end
  end
end
