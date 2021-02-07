require "test_helper"

require 'pry'
class RakeTaskLogTest < ActiveSupport::TestCase
  test "can find task by id" do
    id = "2021-02-07-07-27-53-0600____double_nested%3Ainside_double_nested%3Adouble_nested_task"
    log = RakeUi::RakeTaskLog.find_by_id(id)

    assert_equal log.id, id
    assert_equal log.name, "double_nested:inside_double_nested:double_nested_task"
  end

  test "loads a log file correctly into an instance of RakeTaskLog" do
    id = "2021-02-07-09-34-04-0600____nested%3Athe_nested_task"
    log = RakeUi::RakeTaskLog.find_by_id(id)

    assert_equal log.id, id
    assert_equal log.name, "nested:the_nested_task"


    # name: nested:the_nested_task
    # args: 1
    # environment: FOO=bar BAZ=biz
    # rake_command: FOO=bar BAZ=biz rake nested:the_nested_task[1]
    # rake_definition_file #<Proc:0x00005558b6239128 /home/talos/projects/dox/rake-ui/test/dummy/lib/tasks/nested_tasks.rake:3>
    # log_file_name: 2021-02-07-09-34-04-0600____nested%3Athe_nested_task.txt
    # log_file_full_path: /home/talos/projects/dox/rake-ui/test/dummy/tmp/rake_ui/2021-02-07-09-34-04-0600____nested%3Athe_nested_task.txt
  end
end
