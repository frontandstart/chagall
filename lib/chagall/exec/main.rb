require 'English'
require_relative '../ssh'
require_relative '../settings'

module Chagall
  module Exec
    class Main
      def initialize(argv)
        @service_name = argv.shift
        @command = argv.join(' ')

        raise Chagall::Error, 'Service name is required' if @service_name.nil? || @service_name.empty?
        raise Chagall::Error, 'Command is required' if @command.nil? || @command.empty?

        # binding.pry

        Chagall::Settings.configure(argv)
        @ssh = SSH.new(server: Chagall::Settings[:server], ssh_args: Chagall::Settings[:ssh_args])

        run
      end

      def run
        project_path = "#{Chagall::Settings[:projects_folder]}/#{Chagall::Settings[:name]}"
        docker_compose_cmd = build_docker_compose_command

        cmd = "cd #{project_path} && #{docker_compose_cmd} exec #{@service_name} #{@command}"
        @ssh.execute(cmd, force: true)
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
