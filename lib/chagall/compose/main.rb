require_relative '../settings'
require_relative '../base'

module Chagall
  module Compose
    # Build and execute command usign docker compose on server
    class Main < Base
      def initialize(command, argv)
        super()
        @command = command
        @service_name = argv.shift
        # Join arguments with spaces to preserve them exactly as passed
        @arguments = argv.join(' ')

        raise Chagall::Error, 'Service name is required' if @service_name.nil? || @service_name.empty?
        raise Chagall::Error, 'Command is required' if @command.nil? || @command.empty?

        binding.pry
        run_command
      end

      def run_command
        cmd = "cd #{Chagall::Settings.instance.project_folder_path} && #{build_docker_compose_command} #{@command}"
        cmd << " #{@service_name}"
        cmd << " #{@arguments}" unless @arguments.empty?

        logger.debug "Executing: #{cmd}"
        ssh.execute(cmd, tty: true)
      end

      private

      def build_docker_compose_command
        compose_files = Chagall::Settings[:compose_files]
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
