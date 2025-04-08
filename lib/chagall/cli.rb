# frozen_string_literal: true

require 'thor'
require_relative 'settings'
require_relative 'deploy/main'
require_relative 'compose/main'
require_relative 'base'
module Chagall
  class Cli < Thor
    class_option :server, type: :string, aliases: '-s', desc: 'Server to deploy to', required: false, banner: 'SERVER'
    class_option :name, type: :string, aliases: '-n', desc: 'Project name', default: Pathname.new(Dir.pwd).basename.to_s
    class_option :release, type: :string, desc: 'Release tag', default: `git rev-parse --short HEAD`.strip
    class_option :dry_run, type: :boolean, aliases: '-d', desc: 'Dry run', default: false
    class_option :remote, type: :boolean, aliases: '-r', desc: 'Deploy remotely (build on remote server)',
                          default: false
    class_option :compose_files, type: :array, aliases: '-c', desc: 'Comma separated list of compose files'
    class_option :debug, type: :boolean, desc: 'Debug mode with pry attaching', default: false
    class_option :skip_uncommit_check, type: :boolean, desc: 'Skip uncommitted changes check', default: false

    desc 'deploy', 'Deploy the application to the server'
    def deploy
      Chagall::Deploy::Main.new
    end

    desc 'setup', 'Setup the server for deployment'
    def setup
      Chagall::Setup::Main.new
    end

    desc 'compose COMMAND SERVICE [ARGS...]', 'Run Docker Compose commands with arguments passed through'
    def compose(cmd_name, service_name, *args)
      binding.irb
      Chagall::Compose::Main.new(cmd_name.to_sym, [service_name, *args])
    end
  end
end
