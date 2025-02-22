require 'bundler/setup'
Bundler.setup

require 'rspec/core'
require 'rspec/expectations'
require 'rspec/mocks'

require 'rspec'
require 'fileutils'
require 'open3'
require 'tmpdir'
require 'logger'
require_relative '../lib/chagall'

# Define modules BEFORE the RSpec configuration block
module FileHelpers
  def create_tempfile(content, extension: '')
    Tempfile.new(['chagall', extension]).tap do |f|
      f.write(content)
      f.close
    end
  end
end

module CommandHelpers
  def run_command(cmd, chdir: nil)
    Open3.capture3(*cmd, chdir: chdir)
  end

  def silent_run(cmd, chdir: nil)
    system(*cmd, chdir: chdir, out: File::NULL, err: File::NULL)
  end
end

RSpec.configure do |config|
  # Core configuration
  config.disable_monkey_patching!
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Docker test requirements
  config.before(:suite) do
    warn 'Docker not available - integration tests will be skipped' unless docker_available?
  end

  # Clean environment for tests
  config.before(:each) do
    @original_env = ENV.to_h
    ENV.delete('CHAGALL_ENV')
    ENV['TEST_ENV'] = 'true'
  end

  config.after(:each) do
    ENV.replace(@original_env)
  end

  # Include helpers
  config.include FileHelpers
  config.include CommandHelpers
end

# Check Docker availability
def docker_available?
  system('docker info > /dev/null 2>&1')
end

# Custom matchers
RSpec::Matchers.define :execute_successfully do
  match do |actual|
    @output, @status = Open3.capture3(actual)
    @status.success?
  end

  failure_message do
    "Expected command to execute successfully but it failed\nOutput:\n#{@output}"
  end
end

# Initialize test coverage if requested
if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    add_filter '/spec/'
    track_files 'lib/**/*.rb'
  end
end
