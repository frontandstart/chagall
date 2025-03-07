module Chagall
  class SSH
    attr_reader :server, :ssh_args

    def initialize(server:, ssh_args: '-o StrictHostKeyChecking=no')
      @server = server
      @ssh_args = ssh_args
    end

    def execute(command, directory: nil, force: false)
      cmd = build_command(command, directory)
      logger.debug "SSH: #{cmd}"

      if force
        result = system(cmd)
        raise "Command failed with exit code #{$CHILD_STATUS.exitstatus}: #{cmd}" unless result

        result
      else
        cmd
      end
    end

    def command(command, directory: nil)
      build_command(command, directory)
    end

    private

    def build_command(command, directory)
      if directory
        "ssh #{ssh_args} #{server} 'cd #{directory} && #{command}'"
      else
        "ssh #{ssh_args} #{server} '#{command}'"
      end
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
        l.level = Logger::INFO
      end
    end
  end
end
