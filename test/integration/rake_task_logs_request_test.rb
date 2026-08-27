# frozen_string_literal: true

require "test_helper"

class RakeTaskLogsRequestTest < ActionDispatch::IntegrationTest
  test "index html responds successfully" do
    get "/rake-ui/rake_task_logs"

    assert_equal 200, status
  end

  test "index json responds successfully" do
    get "/rake-ui/rake_task_logs.json"

    assert_equal 200, status
    assert_instance_of Array, json_response[:rake_task_logs]
  end

  test "show html responds with the content" do
    log = RakeUi::RakeTaskLog.all.first
    get "/rake-ui/rake_task_logs/#{log.id}"

    assert_equal 200, status
    assert_includes response.body, "INVOKED RAKE TASK OUTPUT BELOW"
  end

  test "show json responds with the content and task log meta" do
    log = RakeUi::RakeTaskLog.all.first
    get "/rake-ui/rake_task_logs/#{log.id}.json"

    assert_equal 200, status
    assert_equal log.id, json_response[:rake_task_log][:id]
    assert_equal log.log_file_name, json_response[:rake_task_log][:log_file_name]

    assert_includes json_response[:rake_task_log_content], log.id
  end

  test "show html escapes malicious content instead of rendering it as raw HTML" do
    log = RakeUi::RakeTaskLog.build_new_for_command(
      name: "regular",
      rake_definition_file: "regular.rake",
      rake_command: "rake regular",
      raker_id: "regular",
      args: "<script>alert(1)</script>"
    )

    get "/rake-ui/rake_task_logs/#{log.id}"

    assert_equal 200, status
    refute_includes response.body, "<script>alert(1)</script>"
    assert_includes response.body, "&lt;script&gt;alert(1)&lt;/script&gt;"
  ensure
    File.delete(log.log_file_full_path) if log && File.exist?(log.log_file_full_path)
  end
end
