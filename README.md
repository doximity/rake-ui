# RakeUi
Rake UI is a Rails engine that enables the discovery and execution rake tasks in a UI.

## Installation
Add this line to your application's Gemfile:

```ruby
gem 'rake-ui'
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install rake-ui
```

once it is installed, mount the engine
```rb
Rails.application.routes.draw do
  mount RakeUi::Engine => "/rake-ui"
end
```

## Testing

`bundle exec rake test`

To iterate on this fast i normally install nodemon, you can also use guard minitest.

```
# Example with nodemon, you don't have to use this
npm install -g nodemon

# Running a single test whenever models change
nodemon -w ./app/models/*  -e "rb" --exec "rake test TEST=test/rake_ui/rake_task_log_test.rb"
```

## Contributing
Contributing information available in [CONTRIBUTING](./CONTRIBUTING.md)

## License
The gem is available as open source under the terms of the [Apache 2.0 License](./LICENSE).
