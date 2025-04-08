require 'logger'

module Chagall
  class Base
    attr_reader :logger, :ssh

    LOG_LEVELS = {
      'debug' => Logger::DEBUG,
      'info' => Logger::INFO,
      'warn' => Logger::WARN,
      'error' => Logger::ERROR
    }.freeze

    def initialize
      @logger = Logger.new($stdout)
      @logger.formatter = proc do |severity, _, _, msg|
        if severity == 'DEBUG'
          "[#{severity}] #{msg}\n"
        else
          "#{msg}\n"
        end
      end

      @logger.level = LOG_LEVELS[ENV.fetch('LOG_LEVEL', 'debug').downcase]

      @ssh = SSH.new
    end
  end
end
