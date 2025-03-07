require 'spec_helper'
require 'chagall/ssh'

RSpec.describe Chagall::SSH do
  let(:server) { 'test-server' }
  let(:ssh_args) { '-o StrictHostKeyChecking=no' }
  let(:ssh) { described_class.new(server: server, ssh_args: ssh_args) }

  describe '#command' do
    it 'builds basic SSH command' do
      expect(ssh.command('ls')).to eq("ssh #{ssh_args} #{server} 'ls'")
    end

    it 'builds SSH command with directory' do
      expect(ssh.command('ls', directory: '/app')).to eq("ssh #{ssh_args} #{server} 'cd /app && ls'")
    end
  end

  describe '#execute' do
    context 'when force is false' do
      it 'returns the command string' do
        expect(ssh.execute('ls')).to eq("ssh #{ssh_args} #{server} 'ls'")
      end
    end

    context 'when force is true' do
      it 'executes the command and returns true on success' do
        expect(ssh).to receive(:system).with("ssh #{ssh_args} #{server} 'ls'").and_return(true)
        expect(ssh.execute('ls', force: true)).to be true
      end

      it 'raises error on command failure' do
        allow(ssh).to receive(:system).and_return(false)
        allow($CHILD_STATUS).to receive(:exitstatus).and_return(1)

        expect do
          ssh.execute('invalid_command', force: true)
        end.to raise_error(RuntimeError, /Command failed with exit code 1/)
      end
    end
  end
end
