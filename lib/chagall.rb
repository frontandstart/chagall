# frozen_string_literal: true

module Chagall
  BIN_PATH = File.expand_path('../bin/chagall', __dir__)

  class SettingsError < StandardError; end
  class Error < StandardError; end
end

require 'zeitwerk'
require 'yaml'
require 'pathname'
require 'thor'

loader = Zeitwerk::Loader.for_gem
loader.setup
# Eager load necessary namespaces
loader.eager_load_namespace(Chagall::Deploy)
loader.eager_load_namespace(Chagall::Compose)

require_relative 'chagall/cli'
