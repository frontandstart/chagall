#!/usr/bin/env ruby
require 'optparse'
require_relative 'deploy/main'

module Chagall
  class Main
    def self.start(argv)
      if argv.empty?
        puts "Usage: chagall <command> [options]\nCommands: deploy, rollback, setup"
        exit 1
      end

      command = argv.shift
      case command
      when 'deploy'
        Deploy::Main.run(argv)
      when 'rollback'
        Rollback::Main.run(argv)
      when 'setup'
        Setup::Main.run(argv)
      else
        puts "Unknown command: #{command}"
        exit 1
      end
    end
  end
end 