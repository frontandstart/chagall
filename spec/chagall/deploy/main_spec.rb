require 'spec_helper'
require_relative '../../../chagall/lib/chagall/deploy/main'
require 'stringio'

RSpec.describe Chagall::Deploy::Main do
  let(:dummy_argv) { ['--dry-run', '--server', 'example.com'] }
  subject { described_class.new(dummy_argv) }
  let(:main_instance) { subject }

  before do
    # Stub Settings values for testing
    allow(Settings).to receive(:[]).and_call_original
    allow(Settings).to receive(:[]).with(:projects_folder).and_return('/tmp/projects')
    allow(Settings).to receive(:[]).with(:tag).and_return('v1')
    allow(Settings).to receive(:[]).with(:server).and_return('test-server')
    allow(main_instance).to receive(:run) # Prevent actual run execution
  end

  describe '#sync_build_context' do
    it 'creates remote build directory and syncs code' do
      expected_folder = '/tmp/projects/build/v1'
      expect(main_instance).to receive(:ssh_cmd).with("mkdir -p #{expected_folder}").and_return(true)
      expect(main_instance).to receive(:system).with(a_string_including('rsync -avz')).and_return(true)
      folder = main_instance.sync_build_context
      expect(folder).to eq(expected_folder)
    end
  end

  def capture_stdout
    original_stdout = $stdout
    $stdout = fake = StringIO.new
    yield
    fake.string
  ensure
    $stdout = original_stdout
  end

  describe '#execute' do
    let(:command) { 'echo hello' }

    context 'when dry_run is true and not forced' do
      before do
        # Simulate Settings[:dry_run] being true
        allow(Chagall::Deploy::Settings).to receive(:[]).with(:dry_run).and_return(true)
        # Stub system and ssh_cmd to verify they are not called
        allow(main_instance).to receive(:system)
        allow(main_instance).to receive(:ssh_cmd)
      end

      it 'prints DRY RUN message and returns true for non-remote command' do
        output = capture_stdout do
          res = main_instance.send(:execute, command, remote: false, force: false)
          expect(res).to eq(true)
        end
        expect(output).to include('DRY RUN:')
        expect(output).to include(command)
      end

      it 'prints DRY RUN message and returns true for remote command' do
        output = capture_stdout do
          res = main_instance.send(:execute, command, remote: true, force: false)
          expect(res).to eq(true)
        end
        expect(output).to include('DRY RUN:')
        expect(output).to include(command)
      end
    end

    context 'when force is true even in dry_run mode' do
      before do
        allow(Chagall::Deploy::Settings).to receive(:[]).with(:dry_run).and_return(true)
        allow(main_instance).to receive(:system).and_return(true)
        allow(main_instance).to receive(:ssh_cmd).and_return(true)
      end

      it 'executes non-remote command' do
        res = main_instance.send(:execute, command, remote: false, force: true)
        expect(res).to eq(true)
        expect(main_instance).to have_received(:system).with(command)
      end

      it 'executes remote command' do
        res = main_instance.send(:execute, command, remote: true, force: true)
        expect(res).to eq(true)
        expect(main_instance).to have_received(:ssh_cmd).with(command)
      end
    end
  end
end
