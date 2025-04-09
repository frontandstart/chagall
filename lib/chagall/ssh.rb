
require 'English'
module Chagall
  class SSH
    attr_reader :server, :ssh_args

    DEFAULT_SSH_ARGS = '-o StrictHostKeyChecking=no -o ServerAliveInterval=60'.freeze

    def initialize(server: Settings.instance.options[:server], ssh_args: DEFAULT_SSH_ARGS)
      @server = server
      @ssh_args = ssh_args
    end

    def execute(command, directory: nil, tty: false)
      cmd = build_command(command, directory, tty)
      logger.debug "SSH: #{cmd}"
      system(cmd)
      $CHILD_STATUS.success?
    end

    def command(command, directory: nil, tty: false)
      build_command(command, directory, tty)
    end

    private

    def build_command(command, directory, tty)
      ssh_cmd = ['ssh']
      ssh_cmd << '-t' if tty
      ssh_cmd << ssh_args
      ssh_cmd << server

      cmd = if directory
              "cd #{directory} && #{command}"
            else
              command
            end

      "#{ssh_cmd.join(' ')} '#{cmd}'"
    end

    def logger
      @logger ||= Logger.new($stdout).tap do |l|
        l.formatter = proc do |severity, _, _, msg|
          if severity == 'DEBUG'
            "[#{severity}] #{msg}\n"
          else
            "#{msg}\n"
          end
        end
        l.level = ENV.fetch('LOG_LEVEL') { 'debug' }.downcase == 'debug' ? Logger::DEBUG : Logger::INFO
      end
    end
  end
end
