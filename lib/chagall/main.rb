#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'pry'
require_relative 'deploy/main'
require_relative 'exec/main'

module Chagall
  class Main
    AVAILABLE_COMMANDS = %i[deploy rollback install exec run].freeze

    attr_accessor :chagall, :command

    def initialize(argv)
      parse_arguments(argv)

      @command = argv.shift.downcase.to_sym
      console = argv.include?('--console')

      unless AVAILABLE_COMMANDS.include?(command)
        puts "Usage: chagall <command> [options]\nCommands: #{AVAILABLE_COMMANDS.join(', ')}"
        raise Chagall::Error, 'Invalid command'
      end

      case command
      when :deploy
        @chagall = Deploy::Main.new(argv)
      when :rollback
        @chagall = Rollback::Main.new(argv)
      when :setup
        @chagall = Setup::Main.new(argv)
      when :exec
        @chagall = Exec::Main.new(argv)
      when :run
        @chagall = Exec::Main.new(argv, container_run: true)
      end

      run_console if console
    end

    def parse_arguments(_argv)
      OptionParser.new do |opts|
        opts.banner = "Usage: chagall #{command} [options]"

        opts.on('--console', 'Enter Pry console after parsing options') do
          @console = true
        end
      end
    end

    def run_console
      puts "Dry run mode enabled have chagall object available #{chagall}"
      puts "\nEntering Pry console in dry run mode for #{command}. Available objects:"
      puts "- chagall: The #{command.capitalize}::Main instance"
      puts "- settings: The current settings (access via #{command.capitalize}::Settings.options)"
      puts "\nExample commands:"
      case command
      when :deploy
        puts '- chagall.run  # Run the full deployment'
        puts '- chagall.build  # Build the Docker image'
        puts '- chagall.verify_image  # Verify the Docker image'
        puts '- chagall.update_compose_files  # Update the compose files'
        puts '- chagall.deploy_compose_files  # Deploy the compose files'
      when :exec
        puts '- chagall.run  # Execute the command in the service'
      end
      puts "- #{command.capitalize}::Settings.options  # View all settings"
      puts "\nNote: In dry-run mode, all commands are printed. To execute a command for real, pass force: true, e.g. chagall.build(force: true)."
      puts "\nType 'exit' to quit the console"
    end
  end
end
