#!/usr/bin/env ruby

require 'minitest/autorun'
require 'fileutils'
require 'yaml'
require_relative '../lib/install'

class TestInstaller < Minitest::Test
  TEST_SRC_DIR = File.expand_path('src', __dir__)
  
  def setup
    @test_dir = File.expand_path("../tmp/test_#{Time.now.to_i}", __dir__)
    
    # Ensure clean test directory
    FileUtils.rm_rf(@test_dir) if Dir.exist?(@test_dir)
    FileUtils.mkdir_p(@test_dir)
    
    # Copy test source files
    FileUtils.cp_r(Dir["#{TEST_SRC_DIR}/*"], @test_dir)
    FileUtils.cp_r(Dir["#{TEST_SRC_DIR}/.*"], @test_dir) # Copy hidden files too

    Dir.chdir(@test_dir)
    puts "Test directory: #{@test_dir}"
    puts "Contents: #{Dir.entries(@test_dir).join(', ')}"
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
    # Create existing files
    File.write('compose.yaml', 'original compose')
    File.write('Dockerfile', 'original dockerfile')

    installer = Installer.new(
      non_interactive: true,
      auto_yes: true,
      app_name: 'test-app'
    )
    
    installer.install
    
    assert_path_exists('compose.yaml.old')
    assert_path_exists('Dockerfile.old')
    assert_equal 'original compose', File.read('compose.yaml.old')
    assert_equal 'original dockerfile', File.read('Dockerfile.old')
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
end
