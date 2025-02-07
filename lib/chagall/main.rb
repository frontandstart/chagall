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

      pry_console = argv.include?('--pry-console')

      case command
      when :deploy
        @chagall = Deploy::Main.new(argv, dry_run: dry_run)
      when :rollback
        @chagall = Rollback::Main.new(argv, dry_run: dry_run)
      when :setup
        @chagall = Setup::Main.new(argv, dry_run: dry_run)
      end

      run_pry_console if pry_console
    end

    def run_pry_console
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
      end
      puts "- #{command.capitalize}::Settings.options  # View all settings"
      puts "\nType 'exit' to quit the console"
      binding.pry
    end
  end
end
