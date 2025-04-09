require_relative '../settings'
require_relative '../base'

module Chagall
  module Compose
    # Build and execute command usign docker compose on server
    class Main < Base
      attr_reader :command, :arguments

      def initialize(command, args)
        super()
        @command = command
        @arguments = args.join(' ') if args.is_a?(Array)
        @arguments ||= args.to_s

        raise Chagall::Error, 'Command is required' if @command.nil? || @command.empty?

        run_command
      end

      def run_command
        cmd = "cd #{Settings.instance.project_folder_path} && #{build_docker_compose_command} #{@command}"
        cmd << " #{arguments}" unless arguments.empty?

        logger.debug "Executing: #{cmd}"
        ssh.execute(cmd, tty: true)
      end

      private

      def build_docker_compose_command
        compose_files = Settings[:compose_files]
        compose_cmd = ['docker compose']

        if compose_files && !compose_files.empty?
          compose_files.each do |file|
            compose_cmd << "-f #{File.basename(file)}"
          end
        end

        compose_cmd.join(' ')
      end
    end
  end
end
