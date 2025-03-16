# frozen_string_literal: true

require 'spec_helper'
# require_relative '../../../chagall/lib/chagall/deploy/main'
require 'stringio'

RSpec.describe Chagall::Deploy::Main do
  let(:dummy_argv) { ['--dry-run', '--server', 'localhost', '-', ''] }
  subject { described_class.new(dummy_argv) }
  let(:main_instance) { subject }
  let(:tag) { SecureRandom.hex(4) }
  let(:run_id) { "#{Time.now.strftime('%Y%m%d%H%M%S')}-#{tag}" }

  before do
    allow(Chagall::Settings).to receive(:[]).and_call_original
    allow(Chagall::Settings).to receive(:[]).with(:projects_folder).and_return("/tmp/projects/#{run_id}")
    allow(Chagall::Settings).to receive(:[]).with(:tag).and_return('v1')
    allow(Chagall::Settings).to receive(:[]).with(:server).and_return('localserver')
    allow(main_instance).to receive(:run)
  end

  let(:generate_project_folder) do
    "/tmp/test_#{run_id}"
  end

  describe '#sync_build_context' do
    it 'creates remote build directory and syncs code' do
      expected_folder = generate_project_folder
      expect(main_instance).to receive(:ssh_execute).with("mkdir -p #{expected_folder}").and_return(true)
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
        allow(Chagall::Settings).to receive(:[]).with(:dry_run).and_return(true)
        # Stub system and ssh_execute to verify they are not called
        allow(main_instance).to receive(:system)
        allow(main_instance).to receive(:ssh_execute)
      end

      it 'prints DRY RUN message and returns true for non-remote command' do
        output = capture_stdout do
          res = main_instance.send(:execute, command, remote: false)
          expect(res).to eq(true)
        end
        expect(output).to include('DRY RUN:')
        expect(output).to include(command)
      end

      it 'prints DRY RUN message and returns true for remote command' do
        output = capture_stdout do
          res = main_instance.send(:execute, command, remote: true)
          expect(res).to eq(true)
        end
        expect(output).to include('DRY RUN:')
        expect(output).to include(command)
      end
    end

    context 'when force is true even in dry_run mode' do
      before do
        allow(Chagall::Settings).to receive(:[]).with(:dry_run).and_return(true)
        allow(main_instance).to receive(:system).and_return(true)
        allow(main_instance).to receive(:ssh_execute).and_return(true)
      end

      it 'executes non-remote command' do
        res = main_instance.send(:execute, command, remote: false)
        expect(res).to eq(true)
        expect(main_instance).to have_received(:system).with(command)
      end

      it 'executes remote command' do
        res = main_instance.send(:execute, command, remote: true)
        expect(res).to eq(true)
        expect(main_instance).to have_received(:ssh_execute).with(command)
      end
    end
  end
end
