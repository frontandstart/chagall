#!/usr/bin/env ruby

require 'erb'
require 'yaml'
require 'fileutils'
require 'optparse'
require 'logger'

class Installer
  TEMPLATES_DIR = File.expand_path('../lib', __dir__)

  attr_reader :app_name, :services, :versions, :logger

  def initialize(options = {})
    @app_name = options[:app_name] || 'app'
    @non_interactive = options[:non_interactive]
    @auto_yes = options[:auto_yes]
    @services = []
    @logger = Logger.new($stdout)
    @logger.formatter = proc { |_, _, _, msg| "#{msg}\n" }

    @versions = {
      'ruby' => detect_ruby_version,
      'node' => detect_node_version,
      'postgres' => '16.4-bullseye',
      'redis' => '7.4.0'
    }
  end

  def install
    detect_services
    generate_compose
    generate_dockerfile
    logger.info "Installation completed successfully!"
  end

  private

  def backup_file(file)
    return unless File.exist?(file)
    backup = "#{file}.old"
    FileUtils.cp(file, backup)
    logger.info "Backed up existing #{file} to #{backup}"
  end

  def detect_ruby_version
    if File.exist?('.ruby-version')
      File.read('.ruby-version').strip
    else
      File.read('Gemfile').match(/ruby ['"](.+?)['"]/)[1]
    end
  rescue
    '3.3.0'
  end

  def detect_node_version
    if File.exist?('package.json')
      JSON.parse(File.read('package.json')).dig('engines', 'node')&.delete('^') || '20.11.0'
    else
      '20.11.0'
    end
  rescue
    '20.11.0'
  end

  def detect_services
    service_gems = {
      'pg' => 'postgres',
      'redis' => 'redis',
      'sidekiq' => 'sidekiq',
      'mysql2' => 'mysql',
      'mongoid' => 'mongodb',
      'elasticsearch' => 'elasticsearch'
    }

    return unless File.exist?('Gemfile')
    
    gemfile = File.read('Gemfile')
    service_gems.each do |gem, service|
      if gemfile.match?(/gem ['"]#{gem}['"]/)
        if @non_interactive
          @services << service if @auto_yes
        else
          print "#{service} detected. Include it? (y/n): "
          @services << service if gets.chomp.downcase == 'y'
        end
      end
    end
  end

  def generate_compose
    backup_file('compose.yaml')
    
    template_path = File.join(TEMPLATES_DIR, 'template.compose.yaml')
    raise "Compose template not found at #{template_path}" unless File.exist?(template_path)
    
    template = File.read(template_path)
    result = ERB.new(template, trim_mode: '-').result(binding)
    
    File.write('compose.yaml', result)
    logger.info "Generated compose.yaml"
  end

  def generate_dockerfile
    backup_file('Dockerfile')
    
    template_path = File.join(TEMPLATES_DIR, 'template.Dockerfile')
    raise "Dockerfile template not found at #{template_path}" unless File.exist?(template_path)
    
    template = File.read(template_path)
    result = ERB.new(template, trim_mode: '-').result(binding)
    
    File.write('Dockerfile', result)
    logger.info "Generated Dockerfile"
  end
end

if __FILE__ == $0
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: install.rb [options]"

    opts.on("-n", "--non-interactive", "Run in non-interactive mode") do
      options[:non_interactive] = true
    end

    opts.on("-y", "--yes", "Auto-yes to all prompts") do
      options[:auto_yes] = true
    end

    opts.on("-a", "--app-name NAME", "Set application name") do |name|
      options[:app_name] = name
    end
  end.parse!

  Installer.new(options).install
end 
# CLI handling
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: install.rb [options]"

  opts.on("-n", "--non-interactive", "Run in non-interactive mode") do
    options[:non_interactive] = true
  end

  opts.on("-y", "--yes", "Auto-yes to all prompts") do
    options[:auto_yes] = true
  end

  opts.on("-a", "--app-name NAME", "Set application name") do |name|
    options[:app_name] = name
  end
end.parse!

# Run installer
Installer.new(options).install 
Installer.new(options).install 