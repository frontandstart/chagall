require "logger"
require_relative "ssh"

module Chagall
  class Base < Clamp::Command
    attr_reader :logger, :ssh

    LOG_LEVELS = {
      "info" => Logger::INFO,
      "debug" => Logger::DEBUG,
      "warn" => Logger::WARN,
      "error" => Logger::ERROR,
    }
 
    def logger
      @logger ||= Logger.new($stdout).tap do |l|
        l.formatter = proc do |severity, _, _, msg|
          if severity == "DEBUG"
            "[#{severity}] #{msg}\n"
          else
            "#{msg}\n"
          end
        end

        l.level = LOG_LEVELS[ENV.fetch("LOG_LEVEL", "info")]
      end
    end

    def ssh
      @ssh ||= SSH.new(logger: logger)
    end
  end
end
