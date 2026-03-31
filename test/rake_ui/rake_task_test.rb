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

  test "has_arguments? returns true for tasks with arguments" do
    task = get_double_nested_task

    assert task.has_arguments?
  end

  test "has_arguments? returns false for tasks without arguments" do
    task = get_regular_task

    assert_not task.has_arguments?
  end

  test "argument_names returns array of argument names" do
    task = get_double_nested_task

    assert_equal ["user_id"], task.argument_names
  end

  test "argument_names returns correct names for multiple arguments" do
    task = get_task_with_multiple_args

    assert_equal ["user_id", "foo_id"], task.argument_names
  end

  test "argument_count returns correct count" do
    task = get_double_nested_task

    assert_equal 1, task.argument_count
  end

  test "argument_count returns 0 for tasks without arguments" do
    task = get_regular_task

    assert_equal 0, task.argument_count
  end

  def get_double_nested_task
    id = RakeUi::RakeTask.to_safe_identifier("double_nested:inside_double_nested:double_nested_task")

    RakeUi::RakeTask.find_by_id(id)
  end

  def get_regular_task
    id = RakeUi::RakeTask.to_safe_identifier("regular")

    RakeUi::RakeTask.find_by_id(id)
  end

  def get_task_with_multiple_args
    id = RakeUi::RakeTask.to_safe_identifier("double_nested:inside_double_nested:something_esle:double_nested_taskdouble_nested_taskdouble_nested_task")

    RakeUi::RakeTask.find_by_id(id)
  end
end
