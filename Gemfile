# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gemspec

group :rubocop do
  gem "rubocop-rails-omakase", require: false
end

group :development, :test do
  gem "byebug"
  gem "climate_control"
  gem "pry"
  gem "rake"
  gem "rspec-core"
  gem "rspec-expectations"
  gem "webmock"
end
