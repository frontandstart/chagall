require 'spec_helper'
require 'fileutils'
require 'open3'
require 'yaml'

RSpec.describe 'Chagall Integration' do
  let(:test_dir) { Dir.mktmpdir('chagall_test') }

  before do
    # Copy compose fixtures to test directory
    FileUtils.cp_r('spec/fixtures/compose/.', test_dir)

    # Create directory structure first
    FileUtils.mkdir_p(File.join(test_dir, 'app'))

    # Then write files
    File.write(File.join(test_dir, 'app', 'Dockerfile'), <<~DOCKERFILE
      FROM ruby:3.2
      WORKDIR /app
      COPY . .
      CMD ["echo", "Hello from Chagall"]
    DOCKERFILE
    )

    # Initialize proper Git repo with initial commit
    Dir.chdir(test_dir) do
      `git init -b main`
      `git config user.email "test@chagall"`
      `git config user.name "Test User"`
      File.write('README.md', '# Test Project')
      `git add .`
      `git commit -m "Initial commit"`
    end

    # Create valid chagall.yml configuration
    File.write(File.join(test_dir, 'chagall.yml'), <<~YAML
      project: test-app
      environment: production
      compose_files:
        - docker-compose.yml
        - docker-compose.prod.yml
      keep_releases: 3
    YAML
    )

    # Add required directories
    FileUtils.mkdir_p(File.join(test_dir, 'config'))
    # Create minimal database configuration
    File.write(File.join(test_dir, 'config', 'database.yml'), 'test: adapter: sqlite3')
  end

  after do
    # Cleanup Docker containers
    Open3.capture3("docker compose -f #{compose_files.join(' -f ')} down", chdir: test_dir)
    FileUtils.remove_entry(test_dir)
  end

  let(:config) do
    YAML.load_file(File.join(test_dir, 'chagall.yml'))
  end

  let(:compose_files) do
    config['compose_files']
  end

  it 'successfully sets up and deploys application' do
    # Run chagall setup with debug output
    cmd = "#{Chagall::BIN_PATH} install"
    setup_output, status = Open3.capture2e(cmd, chdir: test_dir)

    # Debug output
    puts "\n[DEBUG] Command: #{cmd}"
    puts "[DEBUG] Exit status: #{status.exitstatus}"
    puts "[DEBUG] Output:\n#{setup_output}"

    puts "[DEBUG] Checking setup output #{setup_output}"
    expect(status.success?).to be true

    # Verify file creation
    compose_files.each do |file|
      path = File.join(test_dir, file)
      puts "[DEBUG] Checking file: #{path}"
      puts "[DEBUG] File path #{path}"
      expect(File.exist?(path)).to be true
      puts "[DEBUG] File content:\n#{File.read(path)}" if File.exist?(path)
    end

    # Run chagall deploy
    deploy_command = "#{Chagall::BIN_PATH} deploy"

    puts "\n[DEBUG] Running deploy command: #{deploy_command}"

    deploy_output, status = Open3.capture2e(
      deploy_command,
      chdir: test_dir
    )

    puts "\n[DEBUG] Deploy output #{deploy_output}"
    expect(status.success?).to be true
    expect(deploy_output).to include('Deployment completed successfully')

    # Verify Docker containers are running
    services_output, = Open3.capture3(
      "docker compose -f #{compose_files.join(' -f ')} ps --services --filter status=running",
      chdir: test_dir
    )

    expect(services_output.split).to include('web', 'db')
  end

  it 'generates all specified compose files' do
    # Run with production environment
    setup_output, = Open3.capture2e(
      "#{Chagall::BIN_PATH} setup --env=production",
      chdir: test_dir
    )

    # Debug file system state
    puts `tree #{test_dir}`

    compose_files.each do |file|
      path = File.join(test_dir, file)
      expect(File.exist?(path)).to be(true),
                                   "Expected #{file} to exist. Found files: #{Dir.glob(File.join(test_dir, '*'))}"
      expect(File.read(path)).to include('version: "3.8"'),
                                 "#{file} appears to be empty or malformed"
    end
  end

  it 'deploys' do
    deploy_command = "#{Chagall::BIN_PATH} deploy"

    puts "\n[DEBUG] Running deploy command: #{deploy_command}"

    begin
      deploy_output, status = Open3.capture2e(
        deploy_command,
        chdir: test_dir
      )

      puts "\n[DEBUG] Deploy output:\n#{deploy_output}"
      expect(status.success?).to be true
    rescue StandardError => e
      puts "\n[ERROR] Deployment failed: #{e.message}"
      puts "Backtrace:\n#{e.backtrace.join("\n")}"
      raise # Re-raise the error to fail the test
    ensure
      # Add post-mortem debugging
      puts "\n[POST-MORTEM] Docker containers:"
      system('docker ps -a | grep test-app')

      puts "\n[POST-MORTEM] Docker compose config:"
      system("docker compose -f #{compose_files.join(' -f ')} config")
    end
  end

  it 'uses compose files from config' do
    # Verify config loading
    expect(config['project']).to eq('test-app')
    expect(expected_compose_files).to match_array(compose_files)

    # Verify actual files match config
    Dir.chdir(test_dir) do
      existing_files = Dir.glob('docker-compose*.yml')
      expect(existing_files).to match_array(expected_compose_files)
    end
  end
end
