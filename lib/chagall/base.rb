module Chagall
  class Base
    attr_accessor :logger, :ssh

    def initialize
      @logger = Logger.new($stdout)
      @logger.formatter = proc do |severity, _, _, msg|
        "#{msg}\n"
      end

      @ssh = SSH.new
    end
  end
end
