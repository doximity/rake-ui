# RakeUi
Rake UI is a Rails engine that enables the discovery and execution rake tasks in a UI.

![Example](./README_example.gif)

## Routes

NOTE: Relative to mountpoint in application

 - GET /rake_tasks(.html/.json) - list all available rake tasks
 - GET /rake_tasks/:id(.html/.json) - list info a single tasks
 - POST /rake_tasks/:id/execute - execute a rake task
 - GET /rake_task_logs(.html/.json) - list rake task history
 - GET /rake_task_logs/:id(.html/.json) - list a single rake task history

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
  # only mounting when defined will allow us only include in development/test
  if defined? RakeUi::Engine
    mount RakeUi::Engine => "/rake-ui"
  end
end
```

### Securing RakeUi

This tool is built to enable developer productivity in development.  It exposes rake tasks through a UI.

This tool will currently not work in production because we add a guard in the root controller to respond not found if the environment is development or test. You may override this guard clause with the following configuration.

```rb
RakeUi.configuration do |config|
  config.allow_production = true
end
```

We recommend adding guards in your route to ensure that the proper authentication is in place to ensure that users are authenticated so that if this were ever to be rendered in production, you would be covered.  The best way for that is [router constraints](https://guides.rubyonrails.org/routing.html#specifying-constraints)

## Debugging

RakeUi emits public-safe structured Rails debug logs for rake task execution lifecycle events. Enable them with the host Rails app's normal debug log configuration, for example:

```bash
RAILS_LOG_LEVEL=debug
```

Every RakeUi debug event uses the same set of keys:

| Field | Meaning |
| --- | --- |
| `component` | Always `rake-ui`. |
| `event` | Stable lifecycle event name. |
| `rails_app` | Host Rails application's module name. |
| `task_name` | Rake task name. |
| `task_log_id` | RakeUi task execution log id, or `nil` before one exists. |

RakeUi intentionally does not log command strings, argument values, environment values, authentication data, or application-specific metadata.

| Event | Emitted when | Meaning |
| --- | --- | --- |
| `rake_ui.task_execution.requested` | `RakeUi::RakeTask#call` begins. | The host app accepted a request to execute a rake task. `task_log_id` is not available yet. |
| `rake_ui.task_log.created` | `RakeUi::RakeTaskLog.build_new_for_command` creates the log file. | A durable local execution log file now exists. |
| `rake_ui.task_execution.forked` | The execution process is forked. | Async task execution has been handed to a child process. |
| `rake_ui.task_execution.finished_marker_written` | The child process writes the finished marker after command execution. | The rake-ui local log should now indicate completion. |
| `rake_ui.task_execution.failed` | An observable exception occurs during setup/forking. | Execution setup failed before normal async handoff completed. |

Example:

```json
{
  "component": "rake-ui",
  "event": "rake_ui.task_execution.forked",
  "rails_app": "MyApp",
  "task_name": "db:migrate",
  "task_log_id": "2026-05-11-10-22-33-0400____db%3Amigrate"
}
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
See [CONTRIBUTING](./CONTRIBUTING.md)

## License
The gem is available as open source under the terms of the [Apache 2.0 License](./LICENSE).
