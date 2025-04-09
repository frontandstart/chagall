# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gemspec

group :rubocop do
  gem "rubocop-rails-omakase", require: false
end

group :development, :test do
  gem "byebug", "~> 11.1"
  gem "pry", "~> 0.14"
  gem "rake", "~> 13.0"
  gem "rspec-core", "~> 3.12"
  gem "rspec-expectations", "~> 3.12"
  gem "webmock", "~> 3.18"
end
