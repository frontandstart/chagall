require 'optparse'
require 'yaml'
require 'singleton'

module Chagall
  module Deploy
    class Settings
      include Singleton

      attr_reader :options

      OPTIONS = [
        {
          key: :server,
          type: :string,
          required: true
        },
        {
          key: :name,
          type: :string,
          required: true,
          default: -> { Dir.pwd.split('/').last }
        },
        {
          key: :compose_files,
          type: :array,
          required: true,
          default: ['compose.prod.yaml']
        },
        {
          key: :platform,
          type: :string,
        },
        {
          key: :tag,
          type: :string,
          required: true,
          default: -> { `git rev-parse --short HEAD 2>/dev/null`.strip }
        },
        {
          key: :remote,
          type: :boolean,
        },
        {
          key: :build_args,
          type: :string,
        }
      ]

      def initialize
        @options = {}
        load_defaults
      end

      class << self
        def configure(argv, dry_run: false)
          instance.configure(argv, dry_run: dry_run)
        end

        def options
          instance.options
        end

        def [](key)
          instance.options[key]
        end
      end


      def configure(argv, dry_run: false)
        @argv = argv
        parse unless dry_run
        self
      end

      def parse
        load_config_file
        load_environment_variables
        load_options
        validate_options
        @options
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
          @options.merge!(symbolize_keys(config))
        rescue => e
          puts "Warning: Error loading chagall.yml: #{e.message}"
        end
      end

      def load_environment_variables
        OPTIONS.each do |option|
          env_name = "CHAGALL_#{option[:key].upcase}"
          next if ENV[env_name].to_s.empty?

          value = ENV[env_name]
          value = case option[:key]
                  when :compose_files
                    value.split(',')
                  else
                    value
                  end
          
          @options[option[:key]] = value
        end
      end

      def load_options
        OptionParser.new do |opts|
          opts.banner = "Usage: chagall deploy [options]"

          opts.on("-s", "--server SERVER", "Server to deploy to (e.g. someserver, user@someserver, user@someserver:port)") do |v|
            @options[:server] = v
          end

          opts.on("-n", "--name NAME", "Project name") do |v|
            @options[:name] = v
          end

          opts.on("-p", "--platform PLATFORM", "Platform (e.g. linux/amd64)") do |v|
            @options[:platform] = v
          end

          opts.on("-t", "--tag TAG", "Tag (commit SHA)") do |v|
            @options[:tag] = v
          end

          opts.on("-r", "--remote", "Build remotely instead of locally") do |v|
            @options[:remote] = true
          end

          opts.on("-b", "--build-args ARGS", "Build arguments") do |v|
            @options[:build_args] = v
          end

          opts.on("-f", "--compose-files FILES", "Compose files (comma-separated)") do |v|
            @options[:compose_files] = v.split(',')
          end

          opts.on("-h", "--help", "Show this help message") do
            puts opts
            exit
          end
        end.parse!(@argv)
      end

      def validate_options
        error_message_string = ""

        missing_options = []
        OPTIONS.each do |option|
          if option[:required] && @options[option[:key]].to_s.empty?
            missing_options << option
          end
        end

        if missing_options.any?
          error_message_string += "  Missing required options: #{missing_options.map { |o| o[:key] }.join(', ')}\n"
          error_message_string += "    These can be set via:\n"
          error_message_string += "      - CLI arguments (#{missing_options.map { |o| "--#{o[:key]}" }.join(', ')})\n"
          error_message_string += "      - Environment variables (#{missing_options.map { |o| "CHAGALL_#{o[:key].upcase}" }.join(', ')})\n"
          error_message_string += "      - chagall.yml file\n"
        end

        missing_compose_files = []
        @options[:compose_files].each do |file|
          unless File.exist?(file)
            missing_compose_files << file
            error_message_string += "  Missing compose file: #{file}\n"
          end
        end

        if missing_options.any? || missing_compose_files.any?
          puts "Error:\n"
          puts error_message_string
          exit 1
        end
      end

      def symbolize_keys(hash)
        hash.transform_keys(&:to_sym)
      end
    end
  end
end 