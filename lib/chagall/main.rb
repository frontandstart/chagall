#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'pry'
require 'gli'
require_relative 'deploy/main'
require_relative 'compose/main'

module Chagall
  class Main
    AVAILABLE_COMMANDS = %i[deploy
                            install
                            run
                            exec
                            down
                            logs
                            ls
                            pause
                            port
                            ps
                            pull
                            push
                            restart
                            rm
                            scale
                            start
                            stats
                            stop
                            top
                            unpause
                            up
                            wait
                            watch].freeze

    attr_accessor :chagall, :command

    def initialize(argv)
      @command = argv.shift.downcase.to_sym

      unless AVAILABLE_COMMANDS.include?(command)
        puts "Usage: chagall <command> [options]\nCommands: #{AVAILABLE_COMMANDS.join(', ')}"
        raise Chagall::Error, 'Invalid command'
      end

      Chagall::Settings.configure(argv)

      case command
      when :deploy
        Deploy::Main.new(argv)
      # TODO: Finish install command
      # when :install
      #   Install::Main.new(argv)
      when :setup
        Setup::Main.new
      else
        Compose::Main.new(@command, argv)
      end
    end
  end
end
