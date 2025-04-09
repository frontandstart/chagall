# frozen_string_literal: true

require 'rack'

# Simple test Rack application
app = lambda do |_env|
  [ 200,
   { Rack::CONTENT_TYPE => 'text/plain; charset=utf-8' },
   [ "Hello World from Chagall Test App\n" ] ]
end

# Basic Rack configuration
use Rack::CommonLogger
use Rack::ContentLength

run app

# Print startup message for verification in tests
puts "Test Rack application started on port #{ENV['PORT'] || 9292}"
