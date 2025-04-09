# frozen_string_literal: true

require_relative 'lib/chagall/version'

Gem::Specification.new do |spec|
  spec.name        = 'chagall'
  spec.version     = Chagall::VERSION
  spec.authors     = [ 'Roman Klevtsov' ]
  spec.email       = 'frontandstart@gmail.com'
  spec.homepage    = 'https://github.com/frontandstart/chagall'
  spec.summary     = 'Chagall is a deployment tool for Rails applications, optimized for development and production single-server docker/podman compose setups.'
  spec.license     = 'MIT'
  spec.files = Dir['lib/**/*', 'MIT-LICENSE', 'README.md']

  spec.executables = %w[chagall]

  spec.add_dependency 'clamp'
  spec.add_dependency 'pry'
  spec.add_dependency 'zeitwerk', '~> 2.5'
  spec.add_development_dependency 'debug'
  spec.add_development_dependency 'rspec', '~> 3.12'
end
