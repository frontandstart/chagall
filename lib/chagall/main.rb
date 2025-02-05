#!/usr/bin/env ruby
require 'optparse'
require 'pry'
require_relative 'deploy/main'
# require_relative 'rollback/main'
# require_relative 'setup/main'

module Chagall
  class Main
    AVAILABLE_COMMANDS = %i[deploy rollback install].freeze

    attr_accessor :chagall, :command

    def initialize(argv)
      @command = argv.shift.downcase.to_sym

      unless AVAILABLE_COMMANDS.include?(command)
        puts "Usage: chagall <command> [options]\nCommands: #{AVAILABLE_COMMANDS.join(', ')}"
        raise Chagall::Error, 'Invalid command'
      end

      dry_run = argv.include?('--dry-run')

      case command
      when :deploy
        @chagall = Deploy::Main.new(argv, dry_run: dry_run)
      when :rollback
        @chagall = Rollback::Main.new(argv, dry_run: dry_run)
      when :setup
        @chagall = Setup::Main.new(argv, dry_run: dry_run)
      end

      run_pry_console if dry_run
    end

    def run_pry_console
      puts "Dry run mode enabled have chagall object available #{chagall}"
      puts "\nEntering Pry console in dry run mode for #{command}. Available objects:"
      puts "- chagall: The #{command.capitalize}::Main instance"
      puts "- settings: The current settings (access via #{command.capitalize}::Settings.options)"
      puts "\nExample commands:"
      case command
      when 'deploy'
        puts '- chagall.run  # Run the full deployment'
        puts '- chagall.setup_server  # Run just the server setup'
        puts '- chagall.local_build_and_load  # Build and load image'
      when 'rollback'
        puts '- chagall.run  # Run the full rollback'
        puts '- chagall.fetch_previous_tag  # Get the previous deployment tag'
      when 'setup'
        puts '- chagall.run  # Run the full setup'
        puts '- chagall.detect_services  # Detect required services'
        puts '- chagall.generate_dockerfile  # Generate Dockerfile'
      end
      puts "- #{command.capitalize}::Settings.options  # View all settings"
      puts "\nType 'exit' to quit the console"
      binding.pry
    end
  end
end
