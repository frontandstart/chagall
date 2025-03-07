require 'English'
require_relative '../ssh'
require_relative '../settings'

module Chagall
  module Exec
    class Main
      INTERACTIVE_COMMANDS = ['bash', 'sh', 'irb', 'bin/rails c', 'rails console', 'pry'].freeze

      def initialize(argv)
        @service_name = argv.shift
        @command = argv.join(' ')

        raise Chagall::Error, 'Service name is required' if @service_name.nil? || @service_name.empty?
        raise Chagall::Error, 'Command is required' if @command.nil? || @command.empty?

        Chagall::Settings.configure(argv)
        @ssh = SSH.new(server: Chagall::Settings[:server], ssh_args: Chagall::Settings[:ssh_args])

        # binding.pry
        run
      end

      def run
        project_path = Chagall::Settings.instance.project_folder_path
        docker_compose_cmd = build_docker_compose_command

        cmd = "cd #{project_path} && #{docker_compose_cmd} exec"
        cmd << " #{@service_name} #{@command}"

        @ssh.execute(cmd, force: true, tty: true)
      end

      private

      def interactive?
        INTERACTIVE_COMMANDS.any? { |cmd| @command.start_with?(cmd) }
      end

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
