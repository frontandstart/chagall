require 'optparse'
require 'yaml'
require 'singleton'

module Chagall
  module Deploy
    class Settings
      include Singleton

      CHAGALL_PROJECTS_FOLDER = '~/chagall'.freeze

      OPTIONS = [
        {
          key: :server,
          type: :string,
          required: true,
          flags: ['-s', '--server'],
          env_name: 'CHAGALL_SERVER',
          desc: 'Server to deploy to (e.g. someserver, user@someserver, user@someserver:port)'
        },
        {
          key: :name,
          type: :string,
          required: true,
          flags: ['-n', '--name'],
          env_name: 'CHAGALL_NAME',
          default: Dir.pwd.split('/').last,
          desc: 'Project name'
        },
        {
          key: :compose_files,
          type: :array,
          required: true,
          default: ['compose.prod.yaml'],
          flags: ['-f', '--compose-files'],
          env_name: 'CHAGALL_COMPOSE_FILES',
          desc: 'Compose files (comma-separated)'
        },
        {
          key: :cache_path,
          type: :string,
          default: 'tmp',
          flags: ['-c', '--cache-path'],
          env_name: 'CHAGALL_CACHE_PATH',
          desc: 'Cache path'
        },
        {
          key: :tag,
          type: :string,
          required: true,
          default: `git rev-parse --short HEAD 2>/dev/null`.strip,
          flags: ['-t', '--tag'],
          env_name: 'CHAGALL_TAG',
          desc: 'Tag (commit SHA)'
        },
        {
          key: :remote,
          type: :boolean,
          flags: ['-r', '--remote'],
          env_name: 'CHAGALL_REMOTE',
          desc: 'Build remotely instead of locally'
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
        load_defaults
        load_config_file
        load_environment_variables
        load_options
        validate_options
      end

      private

      def load_defaults
        OPTIONS.each do |option|
          @options[option[:key]] = option[:default] if option[:default]
        end
      end

      def load_config_file
        config_file = File.join(Dir.pwd, 'chagall.yml')
        return unless File.exist?(config_file)

        begin
          config = YAML.load_file(config_file)
          @options.merge!(config.transform_keys(&:to_sym))
        rescue StandardError => e
          puts "Warning: Error loading chagall.yml: #{e.message}"
        end
      end

      def load_environment_variables
        OPTIONS.each do |option|
          env_name = option[:env_name]
          next if env_name.nil? || ENV[env_name].nil?

          value = case option[:type]
                  when :array
                    ENV[env_name].split(',')
                  when :boolean
                    true?(ENV[env_name])
                  else
                    ENV[env_name]
                  end

          @options[option[:key]] = value
        end
      end

      def load_options
        OptionParser.new do |opts|
          opts.banner = 'Usage: chagall deploy [options]'

          OPTIONS.each do |option|
            opts.on(option[:flags][0],
                    option[:flags][1],
                    option[:env_name],
                    option[:desc]) do |v|
              @options[option[:key]] = case option[:type]
                                       when :boolean
                                         true?(v || 'true')
                                       when :array
                                         v.split(',')
                                       else
                                         v
                                       end
            end
          end

          opts.on('-h', '--help', 'Show this help message') do
            puts opts

            exit unless defined?(IRB) && IRB.CurrentContext
          end
        end.parse!(@argv)
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

      def true?(value)
        %w[true y yes 1 si da sure yup].include?(value.downcase)
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
    end
  end
end
