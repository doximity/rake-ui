# frozen_string_literal: true

require "test_helper"

class RakeTaskTest < ActiveSupport::TestCase
  test "it encodes the name as the id" do
    task = RakeUi::RakeTask.internal.first
    assert_equal task.id, CGI.escape(task.name)
  end

  test "is able to build valid rake commands" do
    task = RakeUi::RakeTask.internal.first

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
    task = RakeUi::RakeTask.internal.first

    assert_includes task.rake_definition_file, "/test/dummy/lib/tasks/double_nested_tasks.rake:6"
  end

  test "finds a task by id" do
    task = RakeUi::RakeTask.internal.first

    assert_equal task.name, RakeUi::RakeTask.find_by_id(task.id).name
  end

  test "full_comment description is present" do
    task = RakeUi::RakeTask.internal.first

    assert_not_nil task.full_comment
  end
end
