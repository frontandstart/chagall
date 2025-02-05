module Chagall
  class SettingsError < StandardError; end
  class Error < StandardError; end
end

require 'zeitwerk'
require 'yaml'
require 'pathname'

loader = Zeitwerk::Loader.for_gem
loader.setup
loader.eager_load_namespace(Chagall::Deploy) # We need all commands loaded.
