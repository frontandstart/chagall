#!/usr/bin/env ruby

require 'minitest/autorun'
require 'fileutils'
require 'yaml'
require 'erb'
require_relative '../lib/install'

class TestInstaller < Minitest::Test
  RAILS_TEMPLATE = 'rails_postgres_redis_sidekiq'
  TEST_SRC_DIR = File.expand_path("src/#{RAILS_TEMPLATE}", __dir__)

  def setup
    setup_test_source unless Dir.exist?(TEST_SRC_DIR)
    @test_dir = File.expand_path("../tmp/test_#{Time.now.to_i}", __dir__)
    
    # Ensure clean test directory
    FileUtils.rm_rf(@test_dir) if Dir.exist?(@test_dir)
    FileUtils.mkdir_p(@test_dir)
    
    # Copy test source files from submodule
    FileUtils.cp_r(Dir["#{TEST_SRC_DIR}/*"], @test_dir)
    FileUtils.cp_r(Dir["#{TEST_SRC_DIR}/.*"], @test_dir) rescue nil # Copy hidden files too
    
    Dir.chdir(@test_dir)
  end

  def teardown
    Dir.chdir(File.expand_path('..', @test_dir))
    # FileUtils.rm_rf(@test_dir)
  rescue => e
    puts "Warning: Cleanup failed: #{e.message}"
  end

  def test_auto_yes_scenario
    installer = Installer.new(
      non_interactive: true,
      auto_yes: true,
      app_name: 'test-app'
    )

    installer.install

    assert_path_exists('compose.yaml')
    assert_path_exists('Dockerfile')
    
    compose = load_yaml('compose.yaml')
    assert_includes compose.dig('services').keys, 'dev'
    assert_includes compose.dig('services').keys, 'postgres'
    assert_includes compose.dig('services').keys, 'redis'
  end

  def test_auto_no_scenario
    installer = Installer.new(
      non_interactive: true,
      auto_yes: false,
      app_name: 'test-app'
    )
    
    installer.install
    
    assert_path_exists('compose.yaml')
    assert_path_exists('Dockerfile')
    
    compose = load_yaml('compose.yaml')
    assert_includes compose.dig('services').keys, 'dev'
    refute_includes compose.dig('services').keys, 'postgres'
    refute_includes compose.dig('services').keys, 'redis'
  end

  def test_backup_existing_files
    # Create initial compose and dockerfile from templates
    installer = Installer.new(
      non_interactive: true,
      auto_yes: true,
      app_name: 'original-app'
    )
    
    installer.install
    
    # Store original content
    original_compose = File.read('compose.yaml')
    original_dockerfile = File.read('Dockerfile')
    
    # Run installer again with different app name
    installer = Installer.new(
      non_interactive: true,
      auto_yes: true,
      app_name: 'new-app'
    )
    
    installer.install
    
    # Verify backups
    assert_path_exists('compose.yaml.old')
    assert_path_exists('Dockerfile.old')
    assert_equal original_compose, File.read('compose.yaml.old')
    assert_equal original_dockerfile, File.read('Dockerfile.old')
    
    # Verify new files are different
    refute_equal original_compose, File.read('compose.yaml')
    refute_equal original_dockerfile, File.read('Dockerfile')
  end

  private

  def assert_path_exists(path)
    assert File.exist?(path), "Expected #{path} to exist"
  end

  def load_yaml(path)
    YAML.load_file(path, aliases: true)
  rescue => e
    flunk "Failed to load YAML from #{path}: #{e.message}"
  end

  def setup_test_source
    FileUtils.mkdir_p(File.dirname(TEST_SRC_DIR))
    
    unless system("git submodule add https://github.com/frontandstart/initapp-rails.git #{TEST_SRC_DIR}")
      raise "Failed to add git submodule"
    end
    
    unless system("git submodule update --init --recursive")
      raise "Failed to update git submodule"
    end
  end
end
