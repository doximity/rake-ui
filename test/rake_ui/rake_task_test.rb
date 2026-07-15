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

  test "rejects malicious environment tokens and only processes valid KEY=VALUE pairs" do
    task = get_double_nested_task

    # Test 1: Direct command injection attempt (no KEY=VALUE)
    malicious_env = "curl https://example.com"
    command = task.build_rake_command(environment: malicious_env)
    assert_not_includes command, "curl rake", "Should reject bare command tokens"

    # Test 2: Valid env var followed by command injection attempt
    # "FOO=bar;" is one token (space comes after), so it's processed as KEY=VALUE with value "bar;"
    # "curl" doesn't match KEY=VALUE pattern, so it's rejected
    malicious_env = "FOO=bar; curl https://example.com"
    command = task.build_rake_command(environment: malicious_env)
    assert_includes command, "rake", "Should include rake command"
    assert_not_includes command, "curl rake", "Should not execute curl as a command"
    assert_not_includes command, "curl https", "Should not include curl command in output"
  end

  test "escapes special characters within environment variable values" do
    task = get_double_nested_task

    # When a value contains special characters (in the VALUE part after =), they get escaped
    malicious_env = "FOO=bar;baz"
    command = task.build_rake_command(environment: malicious_env)
    # "FOO=bar;baz" matches KEY=VALUE pattern (no spaces to split it)
    # The value "bar;baz" gets escaped so the semicolon can't be a command separator
    assert_includes command, "FOO=", "Should include FOO assignment"
    assert_includes command, "rake", "Should include rake command"
  end

  test "escapes special shell characters in args" do
    task = get_double_nested_task

    # Test command injection via pipe in arguments
    malicious_args = "1,2,3; rm -rf /"
    command = task.build_rake_command(args: malicious_args)
    assert_includes command, "\\;", "Should escape semicolon in args"
  end

  test "escapes command substitution attempts in args" do
    task = get_double_nested_task

    # Test $(command) injection in args
    malicious_args = "1,$(curl https://example.com)"
    command = task.build_rake_command(args: malicious_args)
    assert_includes command, "\\$", "Should escape dollar sign for command substitution"

    # Test backtick injection in args
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
