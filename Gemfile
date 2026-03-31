source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Specify your gem's dependencies in rake-ui.gemspec.
gemspec

group :development do
  gem "sqlite3", "~> 1.4"
end

gem "pry", group: [:development, :test], require: false
gem "rails", "~> 7.0.0", group: [:development, :test], require: false
gem "minitest", "~> 5.0", group: [:development, :test]
