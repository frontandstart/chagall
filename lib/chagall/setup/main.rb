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
        create_project_folder unless project_folder_exists?
        touch_env_files

        logger.info 'Setting up Docker environment...'
      end

      private

      def touch_env_files
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

      def docker_installed?
        logger.debug 'Checking Docker installation...'

        begin
          # Check docker binary with full command output
          docker_cmd = 'docker --version'
          docker_result = ssh.command(docker_cmd)
          docker_output = `#{docker_result} 2>&1`.strip
          logger.debug "Docker command: #{docker_cmd}"
          logger.debug "Docker version output: '#{docker_output}'"

          # Check docker compose
          compose_cmd = 'docker compose version'
          compose_result = ssh.command(compose_cmd)
          compose_output = `#{compose_result} 2>&1`.strip
          logger.debug "Docker Compose command: #{compose_cmd}"
          logger.debug "Docker Compose output: '#{compose_output}'"

          if docker_output.include?('Docker version') && compose_output.include?('Docker Compose version')
            logger.debug 'Docker and docker compose installed'
            return true
          end

          logger.warn 'Docker check failed:'
          logger.warn "Docker output: #{docker_output}"
          logger.warn "Docker Compose output: #{compose_output}"
          false
        rescue StandardError => e
          logger.error "Error checking Docker installation: #{e.message}"
          logger.debug e.backtrace.join("\n")
          false
        end
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

        command = 'curl -fsSL https://get.docker.com || wget -O - https://get.docker.com | sh'
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
