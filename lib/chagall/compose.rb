require_relative "base"

module Chagall
  # Build and execute command usign docker compose on server
  class Compose < Base
    attr_reader :command, :arguments

    # def initialize(command, args)
    #   @command = command
    #   @arguments = args.join(" ") if args.is_a?(Array)
    #   @arguments ||= args.to_s

    #   raise Chagall::Error, "Command is required" if @command.nil? || @command.empty?

    #   run_command
    # end

    # Override parse method to handle all arguments after the subcommand
    def parse(arguments)
      if arguments.empty?
        puts "ERROR: Missing required arguments"
        puts "Usage: chagall compose COMMAND [OPTIONS]"
        exit(1)
      end

      # Extract the first argument as command
      @command = arguments.shift

      # Store the rest as raw args
      @raw_args = arguments

      # Validate required arguments
      if @command.nil? || @command.empty?
        puts "ERROR: Command is required"
        puts "Usage: chagall compose COMMAND [OPTIONS]"
        exit(1)
      end
    end

    def execute
      cmd = "cd #{Settings.instance.project_folder_path} && #{build_docker_compose_command} #{@command}"
      cmd << " #{arguments}" unless arguments.empty?

      logger.debug "Executing: #{cmd}"
      ssh.execute(cmd, tty: true)
    end

    private

    def build_docker_compose_command
      compose_files = Settings[:compose_files]
      compose_cmd = [ "docker compose" ]

      if compose_files && !compose_files.empty?
        compose_files.each do |file|
          compose_cmd << "-f #{File.basename(file)}"
        end
      end

      compose_cmd.join(" ")
    end
  end
end
