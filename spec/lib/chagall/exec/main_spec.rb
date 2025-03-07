require 'spec_helper'
require 'chagall/exec/main'

RSpec.describe Chagall::Exec::Main do
  let(:service_name) { 'app' }
  let(:command) { 'bundle exec rails c' }
  let(:server) { 'test-server' }
  let(:project_name) { 'test-project' }
  let(:compose_files) { ['compose.yaml', 'compose.prod.yaml'] }
  let(:projects_folder) { '~/projects' }
  let(:argv) do
    [service_name, command, '--server', server, '--name', project_name, '--compose-files', compose_files.join(',')]
  end

  describe '#initialize' do
    it 'raises error when service name is missing' do
      expect do
        described_class.new([])
      end.to raise_error(Chagall::Error, 'Service name is required')
    end

    it 'raises error when command is missing' do
      expect do
        described_class.new([service_name])
      end.to raise_error(Chagall::Error, 'Command is required')
    end

    it 'initializes with valid arguments' do
      expect do
        described_class.new(argv)
      end.not_to raise_error
    end
  end

  describe '#run' do
    let(:exec) { described_class.new(argv) }
    let(:ssh) { instance_double(Chagall::SSH) }
    let(:expected_path) { "#{projects_folder}/#{project_name}" }
    let(:expected_compose_cmd) { 'docker compose -f compose.yaml -f compose.prod.yaml' }
    let(:expected_cmd) { "cd #{expected_path} && #{expected_compose_cmd} exec #{service_name} #{command}" }

    before do
      allow(Chagall::SSH).to receive(:new).and_return(ssh)
    end

    it 'executes the command on the remote server' do
      expect(ssh).to receive(:execute)
        .with(expected_cmd, force: true)
        .and_return(true)

      exec.run
    end

    it 'raises error when command execution fails' do
      allow(ssh).to receive(:execute)
        .with(expected_cmd, force: true)
        .and_return(false)

      expect do
        exec.run
      end.to raise_error(RuntimeError)
    end
  end
end
