require 'spec_helper'
require 'fileutils'
require 'open3'

RSpec.describe 'Chagall Deployment' do
  let(:test_dir) { Dir.mktmpdir('chagall_deploy_test') }

  before do
    # Setup complete application structure
    FileUtils.mkdir_p(File.join(test_dir, 'app'))

    # Create valid Dockerfile
    File.write(File.join(test_dir, 'app', 'Dockerfile'), <<~DOCKERFILE
      FROM ruby:3.2
      WORKDIR /app
      COPY . .
      CMD ["echo", "Hello from Chagall"]
    DOCKERFILE
    )

    # Create valid compose files
    # Create valid compose files
    File.write(File.join(test_dir, 'compose.yml'), <<~YML
      version: '3.8'
      services:
        web:
          build: ./app
          ports:
            - "3000:3000"
    YML
    )

    File.write(File.join(test_dir, 'compose.prod.yml'), <<~YML
      version: '3.8'
      services:
        web:
          build: ./app
          environment:
            - RAILS_ENV=production
    YML
    )

    # Create valid chagall.yml configuration
    File.write(File.join(test_dir, 'chagall.yml'), <<~YAML
      project: test-app
      environment: production
      server: localhost
      compose_files:
        - docker-compose.yml
        - docker-compose.prod.yml
      keep_releases: 3
    YAML
    )

    # Create a dummy gemfile
    File.write(File.join(test_dir, 'Gemfile'), <<~GEMFILE
      source "https://rubygems.org"
      git_source(:github) { |repo| "https://github.com/#{repo}.git" }

      ruby "3.3.7"

      gem 'chagall'

    GEMFILE
    )

    # Initialize Git repo
    Dir.chdir(test_dir) do
      `git init -b main`
      `git config user.email "test@chagall"`
      `git config user.name "Test User"`
      `git add .`
      `git commit -m "Initial commit"`
    end
  end

  after do
    # Cleanup Docker containers
    Open3.capture3("docker compose -f #{compose_files.join(' -f ')} down", chdir: test_dir)
    FileUtils.remove_entry(test_dir)
  end

  context 'using schagall config file' do
    it 'deploys the application stack' do
      deploy_output, status = Open3.capture2e(
        "#{Chagall::BIN_PATH} deploy",
        chdir: test_dir
      )

      puts "\n[Deploy Output]\n#{deploy_output}"
      expect(status.success?).to be true

      # Verify services are running
      services_output, = Open3.capture3(
        "docker compose -f #{compose_files.join(' -f ')} ps --services --filter status=running",
        chdir: test_dir
      )
      expect(services_output.strip).to eq('web')
    end
  end
end
