require 'spec_helper'
require_relative '../../../chagall/lib/chagall/deploy/main'

RSpec.describe Chagall::Deploy::Main do
  let(:argv) { [] }
  subject(:main_instance) { described_class.new(argv, dry_run: true) }

  before do
    # Stub Settings values for testing
    allow(Settings).to receive(:[]).and_call_original
    allow(Settings).to receive(:[]).with(:projects_folder).and_return('/tmp/projects')
    allow(Settings).to receive(:[]).with(:tag).and_return('v1')
    allow(Settings).to receive(:[]).with(:server).and_return('test-server')
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
end
