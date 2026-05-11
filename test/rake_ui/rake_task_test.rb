# frozen_string_literal: true

require "test_helper"

class RakeTaskTest < ActiveSupport::TestCase
  test "is able to build valid rake commands" do
    task = get_double_nested_task

    plain_rake = "rake #{task.name}"
    assert_equal plain_rake, task.build_rake_command

    full_rake_command = "FOO=bar rake #{task.name}[1,2,3]"
    assert_equal full_rake_command, task.build_rake_command(args: "1,2,3", environment: "FOO=bar")

    no_arguments = "FOO=bar rake #{task.name}"
    assert_equal no_arguments, task.build_rake_command(environment: "FOO=bar")

    no_environment = "rake #{task.name}[1,2,3]"
    assert_equal no_environment, task.build_rake_command(args: "1,2,3")
  end

  test "scrubs rake_definition_file to be html safe" do
    task = get_double_nested_task

    assert_includes task.rake_definition_file, "/test/dummy/lib/tasks/double_nested_tasks.rake:6"
  end

  test "returns the desc as full_comments" do
    task = get_double_nested_task

    assert_equal task.full_comment, "Doubley Nested Task"
  end

  test "to_safe_identifier escapes" do
    id = RakeUi::RakeTask.to_safe_identifier("foo bar:baz")

    assert_equal id, "foo+bar%3Abaz"
  end

  test "from_safe_identifier unescapes" do
    id = RakeUi::RakeTask.from_safe_identifier("foo+bar%3Abaz")

    assert_equal id, "foo bar:baz"
  end

  test "it encodes the task name as the id" do
    task = get_double_nested_task

    assert_equal task.id, RakeUi::RakeTask.to_safe_identifier(task.name)
  end

  def get_double_nested_task
    id = RakeUi::RakeTask.to_safe_identifier("double_nested:inside_double_nested:double_nested_task")

    RakeUi::RakeTask.find_by_id(id)
  end
end

class RakeTaskDebugLoggingTest < ActiveSupport::TestCase
  test "call emits public safe lifecycle debug events" do
    task = RakeUi::RakeTask.find_by_id(RakeUi::RakeTask.to_safe_identifier("regular"))
    events = []
    debug = lambda do |event, task_name:, task_log_id: nil|
      events << {event: event, task_name: task_name, task_log_id: task_log_id}
    end

    RakeUi::DebugLogger.stub(:debug, debug) do
      task.stub(:fork_task_execution, 1234) do
        task.call
      end
    end

    assert_equal [
      "rake_ui.task_execution.requested",
      "rake_ui.task_log.created",
      "rake_ui.task_execution.forked"
    ], events.map { |event| event[:event] }
    assert events.all? { |event| event[:task_name] == "regular" }
    assert_nil events.first[:task_log_id]
    assert events[1..].all? { |event| event[:task_log_id].present? }
  end
end
