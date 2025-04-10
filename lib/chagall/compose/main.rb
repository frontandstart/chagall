require_relative "../base"

module Chagall
  module Compose
    class Main < Base
      attr_reader :command, :service, :args

      def initialize(command, *args)
        @command = command
        @service = args.first if args.first && !args.first.start_with?("-")
        @args = @service ? args[1..-1] : args

        raise Chagall::Error, "Command is required" if @command.nil? || @command.empty?

        run_command
      end

      private

      def run_command
        cmd = build_command
        logger.debug "Executing: #{cmd}"

        result = ssh.execute(cmd, tty: true)
        raise Chagall::Error, "Command failed: #{cmd}" unless result
      end

      def build_command
        cmd = [ "cd #{Settings.instance.project_folder_path}" ]
        cmd << build_docker_compose_command
        cmd << @command
        cmd << @service if @service
        cmd << @args.join(" ") if @args && @args.any?

        cmd.join(" && ")
      end

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
end
