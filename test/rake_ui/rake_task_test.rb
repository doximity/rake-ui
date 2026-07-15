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

  test "escapes special shell characters in environment variables" do
    task = get_double_nested_task

    # Test command injection via semicolon
    malicious_env = "FOO=bar; curl https://example.com"
    command = task.build_rake_command(environment: malicious_env)
    assert_match /^'FOO=bar;\ curl\ https:\/\/example\.com'/, command, "Should escape shell metacharacters in environment"

    # Verify the escaped command won't execute the injected command
    assert_not_includes command, "curl https://example.com ;", "Semicolon should not separate commands"
  end

  test "escapes special shell characters in args" do
    task = get_double_nested_task

    # Test command injection via pipe
    malicious_args = "1,2,3; rm -rf /"
    command = task.build_rake_command(args: malicious_args)
    assert_includes command, "\\;", "Should escape semicolon in args"
    assert_not_includes command, "rm -rf", "Should escape away injected commands in args"
  end

  test "escapes command substitution attempts" do
    task = get_double_nested_task

    # Test $(command) injection
    malicious_env = "FOO=$(curl https://example.com)"
    command = task.build_rake_command(environment: malicious_env)
    assert_includes command, "\\$", "Should escape dollar sign for command substitution"

    # Test backtick injection
    malicious_args = "1,`whoami`"
    command = task.build_rake_command(args: malicious_args)
    assert_includes command, "\\`", "Should escape backticks"
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
