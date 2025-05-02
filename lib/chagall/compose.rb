require_relative "base"

module Chagall
  # Build and execute command usign docker compose on server
  class Compose < Base
    attr_reader :command, :arguments

    def parse(arguments)
      if arguments.empty?
        puts "ERROR: Missing required arguments"
        puts "Usage: chagall compose COMMAND [OPTIONS]"
        exit(1)
      end

      @command = arguments.shift

      @raw_args = arguments

      if @command.nil? || @command.empty?
        puts "ERROR: Command is required"
        puts "Usage: chagall compose COMMAND [OPTIONS]"
        exit(1)
      end
    end

    def execute
      cmd = "cd #{Settings.instance.project_folder_path} && #{build_docker_compose_command} #{@command}"
      cmd << " #{@raw_args.join(" ")}" unless @raw_args.empty?

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
