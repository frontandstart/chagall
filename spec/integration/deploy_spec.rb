require 'spec_helper'
require 'fileutils'
require 'open3'
require 'securerandom'

RSpec.describe 'Chagall Deployment' do
  let(:run_id) { SecureRandom.hex(4) }
  let(:container_name) { "ssh-container-#{run_id}" }
  let(:test_dir) { Dir.mktmpdir("chagall_deploy_test_#{run_id}") }

  before do
    # Setup complete application structure
    FileUtils.mkdir_p(File.join(test_dir, 'app'))

    FileUtils.cp_r(File.join('spec/fixtures/sample-app/'), test_dir)

    # Initialize Git repo
    Dir.chdir(test_dir) do
      `git init -b main`
      `git config user.email "test@chagall"`
      `git config user.name "Test User"`
      `git add .`
      `git commit -m "Initial commit"`
    end

    unless system('docker image inspect ssh-server:latest > /dev/null 2>&1')
      system('docker compose -f spec/fixtures/server/compose.yml build') || raise('Failed to build SSH server image')
    end

    system("docker run -d --name #{container_name} -p 2222:22 ssh-server") || raise('Failed to start SSH container')
  end

  after do
    # Stop and remove SSH container
    system("docker stop #{container_name} > /dev/null 2>&1")
    system("docker rm #{container_name} > /dev/null 2>&1")

    # Cleanup Docker containers
    Open3.capture3('docker compose down', chdir: test_dir)
    FileUtils.remove_entry(test_dir)
  end

  context 'using chagall config file' do
    it 'deploys the application stack' do
      deploy_output, status = Open3.capture2e(
        "#{Chagall::BIN_PATH} deploy",
        chdir: test_dir
      )

      puts "\n[Deploy Output]\n#{deploy_output}"
      expect(status.success?).to be true

      # Verify services are running
      services_output, = Open3.capture3(
        'docker compose ps --services --filter status=running',
        chdir: test_dir
      )
      expect(services_output.strip).to eq('web')
    end
  end
end
