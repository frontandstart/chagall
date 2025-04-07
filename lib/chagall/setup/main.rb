# frozen_string_literal: true

require 'yaml'
require 'io/console'

module Chagall
  module Setup
    # Handles server provisioning and Docker environment setup for deployment
    class Main < Base
      class DockerSetupError < StandardError; end

      def initialize
        super
        setup
      end

      def setup
        install_docker unless docker_installed?
        setup_non_root_docker_deamon_access if unable_to_access_docker_deamon?
        create_project_folder unless project_folder_exists?
        create_env_files

        logger.info 'Docker environment setup complete'
      end

      private

      def create_env_files
        logger.debug 'Create env files described at services...'

        Settings[:compose_files].each do |file|
          yaml = YAML.load_file(file, aliases: true)
          yaml['services'].each do |service|
            service[1]['env_file']&.each do |env_file|
              ssh.execute("touch #{env_file}", directory: Settings.instance.project_folder_path)
            end
          end
        end
      end

      def unable_to_access_docker_deamon?
        return true
        docker_result = ssh.command('docker ps')
        docker_output = `#{docker_result} 2>&1`.strip
        logger.debug "Docker output: #{docker_output}"
        docker_output.downcase.include?('permission denied') ||
          docker_output.downcase.include?('connect: permission denied')
      end

      def setup_non_root_docker_deamon_access
        logger.info 'Add user to docker group...'

        username = `#{ssh.command('whoami')} 2>&1`.strip
        return true if username == 'root'

        groups = `#{ssh.command('groups')} 2>&1`.strip
        return if groups.include?('docker')

        logger.debug "Adding #{username} user to docker group"
        ssh.execute("sudo usermod -aG docker #{username}", tty: true)
        ssh.execute("groups #{username} | grep -q docker")

        logger.debug 'Successfully added user to docker group'
        true
      rescue StandardError => e
        logger.error "Error setting up Docker daemon access: #{e.message}"
        logger.debug e.backtrace.join("\n")
        false
      end

      def docker_installed?
        logger.debug 'Checking Docker installation...'

        docker_output = `#{ssh.command('docker --version')} 2>&1`.strip
        logger.debug "Docker version output: '#{docker_output}'"

        compose_output = `#{ssh.command('docker compose version')} 2>&1`.strip
        logger.debug "Docker Compose output: '#{compose_output}'"

        return true if docker_output.include?('Docker version') &&
                       compose_output.include?('Docker Compose version')

        logger.warn 'Docker check failed:'
        logger.warn "Docker output: #{docker_output}"
        logger.warn "Docker Compose output: #{compose_output}"
        false
      rescue StandardError => e
        logger.error "Error checking Docker installation: #{e.message}"
        logger.debug e.backtrace.join("\n")
        false
      end

      def project_folder_exists?
        ssh.execute("test -d #{Settings.instance.project_folder_path}")
      rescue StandardError => e
        logger.error "Error checking project folder: #{e.message}"
        false
      end

      def create_project_folder
        logger.debug "Creating project folder #{Settings.instance.project_folder_path}"
        ssh.execute("mkdir -p #{Settings.instance.project_folder_path}")
      end

      def install_docker
        logger.debug 'Installing Docker...'

        command = '(curl -fsSL https://get.docker.com || wget -O - https://get.docker.com || echo "exit 1") | sh'
        # Clear any existing sudo session
        ssh.execute('sudo -k')

        logger.debug "Executing: #{command}"
        result = ssh.execute(command, tty: true)
        raise DockerSetupError, "Failed to execute: #{command}" unless result
      rescue StandardError => e
        logger.error "Docker installation failed: #{e.message}"
        raise DockerSetupError, "Failed to install Docker: #{e.message}"
      end
    end
  end
end
