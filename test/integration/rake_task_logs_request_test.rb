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

  test "show json returns 404 for an unknown log" do
    get "/rake-ui/rake_task_logs/does-not-exist.json"

    assert_equal 404, status
    assert_equal "Rake task log not found", json_response[:error]
  end

  test "show html returns 404 for an unknown log" do
    get "/rake-ui/rake_task_logs/does-not-exist"

    assert_equal 404, status
  end

  test "show json returns 404 when the log file disappears before it is read" do
    log = ghost_log

    RakeUi::RakeTaskLog.stub(:all, [log]) do
      get "/rake-ui/rake_task_logs/#{log.id}.json"
    end

    assert_equal 404, status
    assert_equal "Rake task log not found", json_response[:error]
  end

  test "show html returns 404 when the log file disappears before it is read" do
    log = ghost_log

    RakeUi::RakeTaskLog.stub(:all, [log]) do
      get "/rake-ui/rake_task_logs/#{log.id}"
    end

    assert_equal 404, status
  end

  test "index json includes remote logs that exist only via log_list" do
    remote_id = "2021-02-07-09-34-04-0600____remote-task"
    RakeUi.log_list = -> { [remote_id] }

    get "/rake-ui/rake_task_logs.json"

    assert_equal 200, status
    logs = json_response[:rake_task_logs]
    remote = logs.find { |log| log[:id] == remote_id }

    assert remote, "expected the remote log in the index"
    assert_equal "#{remote_id}.txt", remote[:log_file_name]
    assert_nil remote[:log_file_full_path]
    assert_nil remote[:args]
  ensure
    RakeUi.log_list = nil
  end

  test "index json tolerates a remote id without the delimiter" do
    RakeUi.log_list = -> { ["plain-remote-id"] }

    get "/rake-ui/rake_task_logs.json"

    assert_equal 200, status
    assert json_response[:rake_task_logs].any? { |log| log[:id] == "plain-remote-id" }
  ensure
    RakeUi.log_list = nil
  end

  test "show json reads content from log_reader for a log not present on this pod" do
    requested_id = "2021-02-07-09-34-04-0600____external-log-id"
    refute RakeUi::RakeTaskLog.all.any? { |log| log.id == requested_id },
      "the requested log must not exist locally to prove the reader path"

    seen_ids = []
    RakeUi.log_reader = ->(log) {
      seen_ids << log.id
      {content: "hello from the reader", finished: true}
    }

    get "/rake-ui/rake_task_logs/#{requested_id}.json"

    assert_equal 200, status
    assert_includes json_response[:rake_task_log_content], "hello from the reader"
    assert_equal true, json_response[:is_rake_task_log_finished]
    assert_equal [requested_id], seen_ids
  ensure
    RakeUi.log_reader = nil
  end

  test "show returns 404 when log_reader reports a missing log" do
    RakeUi.log_reader = ->(_log) {}

    get "/rake-ui/rake_task_logs/2021-02-07-09-34-04-0600____external-log-id.json"

    assert_equal 404, status
    assert_equal "Rake task log not found", json_response[:error]
  ensure
    RakeUi.log_reader = nil
  end

  test "show html escapes malicious content instead of rendering it as raw HTML" do
    RakeUi::RakeTaskLog.create_tmp_file_dir
    log_id = "xss_regression_test"
    log_file_path = RakeUi::RakeTaskLog::REPOSITORY_DIR.join("#{log_id}.txt")
    File.write(log_file_path, "<script>alert(1)</script>")

    get "/rake-ui/rake_task_logs/#{log_id}"

    assert_equal 200, status
    refute_includes response.body, "<script>alert(1)</script>"
    assert_includes response.body, "&lt;script&gt;alert(1)&lt;/script&gt;"
  ensure
    File.delete(log_file_path) if log_file_path && File.exist?(log_file_path)
  end

  private

  # A log the listing reports but whose file is already gone, simulating a file
  # removed between RakeTaskLog.all and RakeTaskLog#file_contents.
  def ghost_log
    RakeUi::RakeTaskLog.create_tmp_file_dir
    log_file_name = "ghost-#{SecureRandom.hex(4)}.txt"
    log_file_full_path = RakeUi::RakeTaskLog::REPOSITORY_DIR.join(log_file_name).to_s
    FileUtils.rm_f(log_file_full_path)

    RakeUi::RakeTaskLog.new(
      id: log_file_name.delete_suffix(".txt"),
      log_file_name: log_file_name,
      log_file_full_path: log_file_full_path
    )
  end
end
