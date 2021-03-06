# frozen_string_literal: true

require "test_helper"

class RakeTaskLogTest < ActiveSupport::TestCase
  test "loads a log file correctly into an instance of RakeTaskLog" do
    id = "2021-02-07-09-34-04-0600____nested%3Athe_nested_task"
    log = RakeUi::RakeTaskLog.find_by_id(id)

    assert_equal log.id, id
    assert_equal log.name, "nested:the_nested_task"
    assert_equal log.args, "1"
    assert_equal log.environment, "FOO=bar BAZ=biz"
    assert_equal log.rake_command, "FOO=bar BAZ=biz rake nested:the_nested_task[1]"
    assert_equal log.rake_definition_file, "#<Proc:0x00005558b6239128 /test/dummy/lib/tasks/nested_tasks.rake:3>"
    assert_equal log.log_file_name, "2021-02-07-09-34-04-0600____nested%3Athe_nested_task.txt"
    assert_includes log.log_file_full_path, "/test/dummy/tmp/rake_ui/2021-02-07-09-34-04-0600____nested%3Athe_nested_task.txt"
  end

  test "is able to decode some date, id and name so that we don't have to read the full contents of file" do
    id = "2021-02-07-09-34-04-0600____nested%3Athe_nested_task"
    log = RakeUi::RakeTaskLog.find_by_id(id)

    log.stub(:parsed_file_contents, {}) do
      assert_equal log.id, id
      assert_equal log.name, "nested:the_nested_task"
      assert_equal log.date, "2021-02-07-09-34-04-0600"
    end
  end
end
