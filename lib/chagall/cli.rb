# frozen_string_literal: true

require 'clamp'
require_relative 'settings'
require_relative 'deploy/main'
require_relative 'compose/main'

Clamp.allow_options_after_parameters = true

module Chagall
  class Cli < Clamp::Command
    banner 'Chagall - Docker deployment tool'

    option ['-s', '--server'], 'CHAGALL_SERVER', 'Server to deploy to'
    option ['-n', '--name'], 'CHAGALL_NAME', 'Project name', default: Pathname.new(Dir.pwd).basename.to_s
    option ['--release'], 'CHAGALL_RELEASE', 'Release tag', default: `git rev-parse --short HEAD`.strip
    option ['-r', '--remote'], :flag, 'Build on server directrly', default: false
    option ['-c', '--compose-files'], 'CHAGALL_COMPOSE_FILES', 'Comma separated list of compose files' do |s|
      s.split(',')
    end
    option ['--debug'], :flag, 'CHAGALL_DEBUG', 'Debug mode with pry attaching', default: false
    option ['--skip-uncommit'], :flag, 'CHAGALL_SKIP_UNCOMMIT', 'Skip uncommitted changes check', default: false

    subcommand 'deploy', 'Deploy the application to the server' do
      def execute
        binding.irb
        Chagall::Deploy::Main.new
      end
    end

    subcommand 'setup', 'Setup the server for deployment' do
      def execute
        Chagall::Setup::Main.new
      end
    end

    subcommand 'compose', 'Run Docker Compose commands with arguments passed through' do
      parameter 'COMMAND', 'The docker-compose command to run'
      parameter 'SERVICE', 'The service name'
      parameter '[ARGS] ...', 'Additional arguments', attribute_name: :args

      def execute
        Chagall::Compose::Main.new(command, service, *args)
      end
    end

    subcommand 'rollback', 'Rollback to previous deployment' do
      option ['--steps'], 'STEPS', 'Number of steps to rollback', default: '1' do |s|
        Integer(s)
      end

      def execute
        puts 'Rollback functionality not implemented yet'
      end
    end
  end
end
