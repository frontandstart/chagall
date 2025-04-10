# frozen_string_literal: true

require "clamp"
require_relative "settings"
require_relative "deploy"
require_relative "compose"
require_relative "rollback"

Clamp.allow_options_after_parameters = true

module Chagall
  class Cli < Clamp::Command

    def run(arguments)
      parse(arguments)
      Chagall::Settings.configure(collect_options_hash)
      execute
    end
 
    def self.options_from_config_file
      @options_from_config_file ||= begin
        config_path = File.join(Dir.pwd, "chagall.yml") || File.join(Dir.pwd, "chagall.yaml")
        return {} unless File.exist?(config_path)

        config = YAML.load_file(config_path)
        config.transform_keys(&:to_sym)
      rescue StandardError => e
        puts "Warning: Error loading chagall.yml: #{e.message}"
        {}
      end
    end

    Settings::OPTIONS.each do |opt|
      if opt[:type] == :boolean
        option opt[:flags], :flag, opt[:description],
               default: options_from_config_file[opt[:key]] || opt[:default],
               environment_variable: opt[:environment_variable]
      elsif opt[:proc].is_a?(Proc)
        option opt[:flags],
               opt[:environment_variable].gsub("CHAGALL_", ""),
               opt[:description],
               default: options_from_config_file[opt[:key]] || opt[:default],
               environment_variable: opt[:environment_variable] do |value|
          opt[:proc].call(value)
        end
      else
        option opt[:flags],
               opt[:environment_variable].gsub("CHAGALL_", ""),
               opt[:description],
               default: options_from_config_file[opt[:key]] || opt[:default],
               environment_variable: opt[:environment_variable]
      end
    end

    option "--version", :flag, "Show version" do
      puts Chagall::VERSION
      exit(0)
    end

    subcommand "deploy", "Deploy the application to the server", Chagall::Deploy
    subcommand "setup", "Setup the server for deployment", Chagall::Setup
    subcommand "compose", "Run Docker Compose commands with arguments passed through", Chagall::Compose
    subcommand "rollback", "Rollback to previous deployment", Chagall::Rollback

    private

    def collect_options_hash
      result = {}

      self.class.recognised_options.each do |option|
        name = option.attribute_name.to_sym

        next if !respond_to?(name) && !respond_to?("#{name}?")

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
