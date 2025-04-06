# frozen_string_literal: true

require_relative 'lib/chagall/version'

Gem::Specification.new do |spec|
  spec.name        = 'chagall'
  spec.version     = Chagall::VERSION
  spec.authors     = ['Roman Klevtsov @r3cha']
  spec.email       = '@r3cha'
  spec.homepage    = 'https://github.com/frontandstart/chagall'
  spec.summary     = 'Chagall is a deployment tool for Rails applications, optimized for development and production single-server docker/podman compose setups.'
  spec.license     = 'MIT'
  spec.files = Dir['lib/**/*', 'MIT-LICENSE', 'README.md']

  spec.executables = %w[chagall]

  # spec.add_dependency "activesupport", ">= 7.0"
  # spec.add_dependency "sshkit", ">= 1.23.0", "< 2.0"
  # spec.add_dependency "net-ssh", "~> 7.0"
  # spec.add_dependency "thor", "~> 1.3"
  # spec.add_dependency "dotenv", "~> 3.1"
  spec.add_dependency 'gli'
  spec.add_dependency 'pry'
  spec.add_dependency 'zeitwerk', '~> 2.5'
  # spec.add_dependency "ed25519", "~> 1.2"
  # spec.add_dependency "bcrypt_pbkdf", "~> 1.0"
  # spec.add_dependency "concurrent-ruby", "~> 1.2"
  # spec.add_dependency "base64", "~> 0.2"

  # spec.add_development_dependency 'debug'
  # spec.add_development_dependency 'mocha'
  # spec.add_development_dependency 'railties'
  spec.add_development_dependency 'rspec', '~> 3.12'
end
