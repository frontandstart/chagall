#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'pry'
require_relative 'deploy/main'
require_relative 'compose/main'
require_relative 'settings'

module Chagall
  class Error < StandardError; end

  class Main
    AVAILABLE_COMMANDS = %i[
      deploy setup install run exec down logs ls pause port ps pull push restart
      rm scale start stats stop top unpause up wait watch
    ].freeze

    attr_accessor :command

    def initialize
      global_args, command_name, command_args = split_args(ARGV)

      Chagall::Settings.configure(global_args)

      # Route command
      case command_name
      when :deploy
        Deploy::Main.new(command_args)
      when :install
        # Install::Main.new(command_args)
      when :setup
        Setup::Main.new
      else
        Compose::Main.new(command_name, command_args)
      end
    end

    private

    def split_args(argv)
      global_args = []
      command_name = nil
      command_args = []

      argv.each_with_index do |arg, i|
        if AVAILABLE_COMMANDS.include?(arg.to_sym)
          command_name = arg.to_sym
          command_args = argv[(i + 1)..]
          break
        else
          global_args << arg
        end
      end

      unless command_name
        puts "Usage: chagall <command> [options]\nCommands: #{AVAILABLE_COMMANDS.join(', ')}"
        raise Chagall::Error, 'Missing or invalid command'
      end

      [global_args, command_name, command_args]
    end
  end
end
