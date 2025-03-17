require 'English'
require_relative '../ssh'
require_relative '../settings'

module Chagall
  module Exec
    class Main
      def initialize(command, argv, container_run: false)
        @service_name = argv.shift
        @command = command
        @arguments = argv.join(' ')

        raise Chagall::Error, 'Service name is required' if @service_name.nil? || @service_name.empty?
        raise Chagall::Error, 'Command is required' if @command.nil? || @command.empty?

        Chagall::Settings.configure(argv)
        @ssh = SSH.new(server: Chagall::Settings[:server], ssh_args: Chagall::Settings[:ssh_args])

        run_command
      end

      def run_command
        cmd = "cd #{Chagall::Settings.instance.project_folder_path} && #{build_docker_compose_command} #{@command}"
        cmd << " #{@service_name} #{@arguments}"

        @ssh.execute(cmd, tty: true)
      end

      private

      def build_docker_compose_command
        compose_files = Chagall::Settings[:compose_files]
        compose_cmd = ['docker compose']

        compose_files.each do |file|
          compose_cmd << "-f #{File.basename(file)}"
        end

        compose_cmd.join(' ')
      end
    end
  end
end
