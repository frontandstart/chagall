#!/usr/bin/env ruby
# frozen_string_literal: true

require 'erb'
require 'yaml'
require 'fileutils'
require 'optparse'
require 'logger'
require 'tmpdir'
require 'securerandom'
require 'net/http'
require 'json'
require 'uri'

# The Installer class is responsible for setting up the environment for a Ruby on Rails application.
# It detects the required services and versions, generates necessary Docker and Compose files, and logs the process.
#
# Constants:
# - TEMPLATES_DIR: Directory where template files are stored.
# - DEFAULT_NODE_VERSION: Default Node.js version to use if not specified.
# - DEFAULT_RUBY_VERSION: Default Ruby version to use if not specified.
#
# Attributes:
# - app_name: Name of the application.
# - services: List of services to be included in the setup.
# - versions: Hash containing versions of Ruby, Node.js, PostgreSQL, and Redis.
# - logger: Logger instance for logging messages.
# - database_type: Type of database to use (e.g., 'postgres', 'mysql', 'sqlite').
#
# Methods:
# - initialize(options = {}): Initializes the installer with given options.
# - install: Main method to perform the installation process.
#
# Private Methods:
# - backup_file(file): Creates a backup of the specified file if it exists.
# - detect_ruby_version: Detects the Ruby version from various files or defaults to a predefined version.
# - detect_node_version: Detects the Node.js version from various files or defaults to a predefined version.
# - node_version_from_package_json: Extracts the Node.js version from package.json if available.
# - node_version_from_file: Extracts the Node.js version from .node-version, .tool-versions, or .nvmrc files if available.
# - detect_services: Detects required services based on the gems listed in the Gemfile.
# - generate_compose: Generates the Docker Compose file from a template.
# - generate_dockerfile: Generates the Dockerfile from a template.
class Installer # rubocop:disable Metrics/ClassLength
  TEMPLATES_DIR = File.expand_path('./templates', __dir__)
  TEMP_DIR = File.join(Dir.tmpdir, "chagall-#{SecureRandom.hex(4)}").freeze
  DEFAULT_RUBY_VERSION = '3.3.0'
  DEFAULT_NODE_VERSION = '20.11.0'

  GITHUB_REPO = 'frontandstart/chagall'
  TEMPLATE_FILES = %w[template.compose.yaml
                      template.Dockerfile].freeze

  DEPENDENCIES = [
    {
      adapter: :postgresql,
      gem_name: 'pg',
      service: :postgres,
      image: 'postgres:16.4-bullseye',
      docker_env: 'DATABASE_URL: postgres://postgres:postgres@postgres:5432'
    },
    {
      adapter: :mysql2,
      gem_name: 'mysql2',
      service: :mariadb,
      image: 'mariadb:8.0-bullseye',
      docker_env: 'DATABASE_URL: mysql://mysql:mysql@mariadb:3306'
    },
    {
      adapter: :mongoid,
      gem_name: 'mongoid',
      service: :mongodb,
      image: 'mongo:8.0-noble',
      docker_env: 'DATABASE_URL: mongodb://mongodb:27017'
    },
    {
      gem_name: 'redis',
      service: :redis,
      image: 'redis:7.4-bookworm',
      docker_env: 'REDIS_URL: redis://redis:6379'
    },
    {
      gem_name: 'sidekiq',
      service: :sidekiq,
      image: -> { app_name }
    },
    {
      gem_name: 'elasticsearch',
      service: :elasticsearch,
      image: 'elasticsearch:8.15.3',
      docker_env: 'ELASTICSEARCH_URL: elasticsearch://elasticsearch:9200'
    },
    {
      gem_name: 'solid_queue',
      service: :solid_queue,
      image: -> { app_name }
    }
  ].freeze

  attr_reader :app_name,
              :versions,
              :logger,
              :database_type,
              :database_config,
              :gemfile,
              :gemfile_lock

  attr_accessor :project_services,
                :environments

  def initialize(options = {})
    raise 'Gemfile not found' unless File.exist?('Gemfile')

    Chagall::Settings.configure(argv)

    @app_name = options[:app_name] || File.basename(Dir.pwd)
    @services = []
    @logger = Logger.new($stdout)
    @logger.formatter = proc { |_, _, _, msg| "#{msg}\n" }
    @environments = {}
    @gemfile = File.read('Gemfile')
    @gemfile_lock = File.read('Gemfile.lock')
    @database_adapters = YAML.load_file('config/database.yml')
                             .map { |_, config| config['adapter'] }.uniq
    @database_type = @database_adapters
  end

  def install
    setup_temp_directory
    detect_services
    generate_environment_variables
    generate_compose_file
    generate_dockerfile
    logger.info 'Installation completed successfully!'
  ensure
    cleanup_temp_directory
  end

  private

  def setup_temp_directory
    FileUtils.mkdir_p(TEMP_DIR)
    download_template_files
  rescue StandardError => e
    logger.error "Failed to set up temporary directory: #{e.message}"
    cleanup_temp_directory
    raise
  end

  def detect_services
    DEPENDENCIES.each do |dependency|
      @services << dependency if gemfile_has_dependency?(dependency[:gem_name])
    end

    logger.info "Detected services: #{services.map { |s| s[:service] }.join(', ')}"
  end

  def gemfile_has_dependency?(gem_name)
    gemfile_match = gemfile.match?(/^\s*[^#].*gem ['"]#{gem_name}['"]/)
    gemfile_lock_match = gemfile_lock.match?(/^\s+#{gem_name}\s+\(/) || false

    gemfile_match && gemfile_lock_match
  end

  def generate_environment_variables
    services.each do |service|
      url = generate_service_url_for(service[:adapter])
      environments[service[:url_name]] = url if url
    end
  end

  def cleanup_temp_directory
    FileUtils.remove_entry_secure(TEMP_DIR) if Dir.exist?(TEMP_DIR)
  end

  def download_template_files
    release_info = fetch_latest_release
    TEMPLATE_FILES.each do |filename|
      download_template(filename, release_info)
    end
  rescue StandardError => e
    logger.error "Failed to download template files: #{e.message}"
    raise
  end

  def fetch_latest_release
    uri = URI("https://api.github.com/repos/#{GITHUB_REPO}/releases/latest")
    response = Net::HTTP.get_response(uri)

    raise "Failed to fetch latest release info: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def download_template(filename, release_info)
    asset = release_info['assets'].find { |a| a['name'] == filename }
    raise "Template file #{filename} not found in release" unless asset

    download_url = asset['browser_download_url']
    target_path = File.join(TEMP_DIR, filename)

    uri = URI(download_url)
    response = Net::HTTP.get_response(uri)

    raise "Failed to download #{filename}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    File.write(target_path, response.body)
    logger.info "Downloaded #{filename}"
  end

  def backup_file(file)
    return unless File.exist?(file)

    backup = "#{file}.chagall.bak"
    FileUtils.cp(file, backup)
    logger.info "Backed up existing #{file} to #{backup}"
  end

  def generate_database_url(adapter)
    case adapter
    when 'postgresql'
      'postgres://postgres:postgres@postgres:5432/db'
    when 'mysql2'
      'mysql2://mysql:mysql@mysql:3306/db'
    when 'sqlite3'
      'sqlite3:///data/db.sqlite3'
    when 'redis'
      'redis://redis:5432/0'
    else
      raise "Unsupported adapter: #{adapter}"
    end
  end

  def generate_compose_file
    backup_file('compose.yaml')

    template_path = File.join(TEMP_DIR, 'template.compose.yaml')
    raise "Compose template not found at #{template_path}" unless File.exist?(template_path)

    template = File.read(template_path)
    result = ERB.new(
      template,
      trim_mode: '-',
      services: services,
      environments: environments
    ).result(binding)

    File.write('compose.yaml', result)
    logger.info 'Generated compose.yaml'
  end

  def generate_dockerfile
    backup_file('Dockerfile')

    template_path = File.join(TEMP_DIR, 'template.Dockerfile')
    raise "Dockerfile template not found at #{template_path}" unless File.exist?(template_path)

    template = File.read(template_path)
    result = ERB.new(template, trim_mode: '-').result(binding)

    File.write('Dockerfile', result)
    logger.info 'Generated Dockerfile'
  end

  def detect_ruby_version
    from_gemfile = gemfile.match(/ruby ['"](.+?)['"]/)[1]
    return from_gemfile if from_gemfile

    if File.exist?('.ruby-version')
      File.read('.ruby-version').strip
    elsif File.exist?('.tool-versions')
      File.read('.tool-versions').match(/ruby (.+?)\n/)[1]
    else
      DEFAULT_RUBY_VERSION
    end
  end

  def detect_node_version
    node_version_from_package_json || node_version_from_file || DEFAULT_NODE_VERSION
  end

  def node_version_from_package_json
    return unless File.exist?('package.json')

    begin
      JSON.parse(File.read('package.json')).dig('engines', 'node')&.delete('^')
    rescue JSON::ParserError
      nil
    end
  end

  def node_version_from_file
    if File.exist?('.node-version')
      File.read('.node-version').strip
    elsif File.exist?('.tool-versions')
      File.read('.tool-versions').match(/node (.+?)\n/)[1]
    elsif File.exist?('.nvmrc')
      File.read('.nvmrc').strip
    end
  end

  def find_dependecy_by(name, value)
    DEPENDENCIES.find { |d| d[name.to_sym] == value.to_sym }
  end
end

if __FILE__ == $PROGRAM_NAME
  options = {}
  OptionParser.new do |opts|
    opts.banner = 'Usage: install.rb [options]'

    opts.on('-n', '--non-interactive', 'Run in non-interactive mode') do
      options[:non_interactive] = true
    end

    opts.on('-a', '--app-name NAME', 'Set application name') do |name|
      options[:app_name] = name
    end
  end.parse!

  Installer.new(options).install
end
