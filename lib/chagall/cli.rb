# frozen_string_literal: true

require 'clamp'
require_relative 'settings'
require_relative 'deploy/main'
require_relative 'compose/main'

Clamp.allow_options_after_parameters = true

module Chagall
  class Cli < Clamp::Command
    banner 'Chagall - Docker deployment tool'

    Settings::OPTIONS.each do |opt|
      if opt[:type] == :boolean
        option opt[:flags], :flag, opt[:description],
               default: opt[:default],
               environment_variable: opt[:environment_variable]
      elsif opt[:proc].is_a?(Proc)
        option opt[:flags],
               opt[:environment_variable].gsub('CHAGALL_'),
               opt[:description],
               default: opt[:default],
               environment_variable: opt[:environment_variable] do |value|
          opt[:proc].call(value)
        end
      else
        option opt[:flags],
               opt[:environment_variable].gsub('CHAGALL_'),
               opt[:description],
               default: opt[:default],
               environment_variable: opt[:environment_variable]
      end
    end

    subcommand 'deploy', 'Deploy the application to the server' do
      def execute
        Chagall::Settings.configure(collect_options_hash)
        binding.irb
        Chagall::Deploy::Main.new
      end
    end

    subcommand 'setup', 'Setup the server for deployment' do
      def execute
        Chagall::Settings.configure(collect_options_hash)
        Chagall::Setup::Main.new
      end
    end

    subcommand 'compose', 'Run Docker Compose commands with arguments passed through' do
      parameter 'COMMAND', 'The docker-compose command to run'
      parameter 'SERVICE', 'The service name'
      parameter '[ARGS] ...', 'Additional arguments', attribute_name: :args

      def execute
        Chagall::Settings.configure(collect_options_hash)
        Chagall::Compose::Main.new(command, service, *args)
      end
    end

    subcommand 'rollback', 'Rollback to previous deployment' do
      option ['--steps'], 'STEPS', 'Number of steps to rollback', default: '1' do |s|
        Integer(s)
      end

      def execute
        Chagall::Settings.configure(collect_options_hash)
        puts 'Rollback functionality not implemented yet'
      end
    end

    private

    def collect_options_hash
      result = {}

      self.class.recognised_options.each do |option|
        name = option.attribute_name.to_sym

        next if !respond_to?(name) && !respond_to?("#{name}?")

        binding.irb if option.attribute_name == 'context'

        value = if option.type == :flag
                  send("#{name}?")
                else
                  send(name)
                end

        result[name] = value unless value.nil?
      end

      result
    end
  end
end
